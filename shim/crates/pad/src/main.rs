//! The pad bridge: a gamepad through gilrs into the jab.pad port's pipe.

use std::env;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::process::ExitCode;
use std::time::{Duration, Instant};

use gilrs::{Axis, Button, EventType, Gamepad, GamepadId, Gilrs, GilrsBuilder};

const MAGIC: &[u8; 4] = b"JPAD";
const VERSION: u32 = 1;
const NAME_BYTES: usize = 128;
const AXES: usize = 64;
/// Full scale for a stick and a trigger on the wire.
const FULL: i32 = 32767;

const EV_KEY: u16 = 1;
const EV_ABS: u16 = 3;
const BTN_GAMEPAD: u16 = 304;
const ABS_X: u16 = 0;
const ABS_Y: u16 = 1;
const ABS_RX: u16 = 3;
const ABS_RY: u16 = 4;
const ABS_GAS: u16 = 9;
const ABS_BRAKE: u16 = 10;
const ABS_HAT0X: u16 = 16;
const ABS_HAT0Y: u16 = 17;

/// gilrs's buttons and their evdev codes.
const BUTTONS: [(Button, u16); 15] = [
    (Button::South, 304),
    (Button::East, 305),
    (Button::C, 306),
    (Button::North, 307),
    (Button::West, 308),
    (Button::Z, 309),
    (Button::LeftTrigger, 310),
    (Button::RightTrigger, 311),
    (Button::LeftTrigger2, 312),
    (Button::RightTrigger2, 313),
    (Button::Select, 314),
    (Button::Start, 315),
    (Button::Mode, 316),
    (Button::LeftThumb, 317),
    (Button::RightThumb, 318),
];

/// gilrs's stick axes and their evdev codes.
const STICKS: [(Axis, u16); 4] = [
    (Axis::LeftStickX, ABS_X),
    (Axis::LeftStickY, ABS_Y),
    (Axis::RightStickX, ABS_RX),
    (Axis::RightStickY, ABS_RY),
];

/// Whether QEMU waits for the pipe's client before it starts, as on Windows.
const WAITS_FOR_CLIENT: bool = cfg!(windows);

fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.len() < 2 {
        eprintln!("usage: jabshim_pad <pipe> <name> [vendor] [product]");
        return ExitCode::from(2);
    }
    let pipe = &args[0];
    let name = &args[1];
    let vendor = args.get(2).and_then(|s| s.parse::<u16>().ok());
    let product = args.get(3).and_then(|s| s.parse::<u16>().ok());
    let early = if WAITS_FOR_CLIENT {
        match open_pipe(pipe) {
            Ok(file) => Some(file),
            Err(error) => {
                eprintln!("jabshim_pad: {error}");
                return ExitCode::from(1);
            }
        }
    } else {
        None
    };
    let mut gilrs = match GilrsBuilder::new().with_default_filters(false).build() {
        Ok(gilrs) => gilrs,
        Err(gilrs::Error::NotImplemented(gilrs)) => gilrs,
        Err(error) => {
            eprintln!("jabshim_pad: gilrs: {error}");
            return ExitCode::from(1);
        }
    };
    settle(&mut gilrs);
    let Some(id) = find(&gilrs, name, vendor, product) else {
        eprintln!("jabshim_pad: no connected gamepad named {name}");
        return ExitCode::from(1);
    };
    let mut out = match early {
        Some(file) => file,
        None => match open_pipe(pipe) {
            Ok(file) => file,
            Err(error) => {
                eprintln!("jabshim_pad: {error}");
                return ExitCode::from(1);
            }
        },
    };
    if out.write_all(&header(&gilrs.gamepad(id))).is_err() {
        return ExitCode::SUCCESS;
    }
    loop {
        while let Some(event) = gilrs.next_event_blocking(Some(Duration::from_millis(250))) {
            if event.id != id {
                continue;
            }
            if let EventType::Disconnected = event.event {
                return ExitCode::SUCCESS;
            }
            for frame in translate(&event.event) {
                if out.write_all(&frame).is_err() {
                    return ExitCode::SUCCESS;
                }
            }
        }
        if !gilrs.gamepad(id).is_connected() {
            return ExitCode::SUCCESS;
        }
    }
}

/// How long gilrs's events may go quiet before its list is taken as complete.
const QUIET: Duration = Duration::from_millis(100);
/// The most the settle waits in all.
const LONGEST: Duration = Duration::from_secs(1);

/// Pump gilrs's events until they go quiet for `QUIET`, `LONGEST` at most.
fn settle(gilrs: &mut Gilrs) {
    let started = Instant::now();
    while gilrs.next_event_blocking(Some(QUIET)).is_some() {
        if started.elapsed() > LONGEST {
            break;
        }
    }
}

/// The connected gamepad with that name, and that vendor and product
/// where given.
fn find(gilrs: &Gilrs, name: &str, vendor: Option<u16>, product: Option<u16>) -> Option<GamepadId> {
    gilrs
        .gamepads()
        .find(|(_, pad)| {
            pad.is_connected()
                && pad.os_name() == name
                && vendor.is_none_or(|v| pad.vendor_id() == Some(v))
                && product.is_none_or(|p| pad.product_id() == Some(p))
        })
        .map(|(id, _)| id)
}

/// The port's header for this pad: its name, its buttons, and its axes.
fn header(pad: &Gamepad<'_>) -> Vec<u8> {
    let mut out = Vec::with_capacity(152 + AXES * 20);
    out.extend_from_slice(MAGIC);
    out.extend_from_slice(&VERSION.to_le_bytes());
    let mut name = [0u8; NAME_BYTES];
    let text = pad.os_name().as_bytes();
    let n = text.len().min(NAME_BYTES - 1);
    name[..n].copy_from_slice(&text[..n]);
    out.extend_from_slice(&name);
    let mut keys: u32 = 0;
    for (button, code) in BUTTONS {
        if pad.button_code(button).is_some() {
            keys |= 1 << (code - BTN_GAMEPAD);
        }
    }
    out.extend_from_slice(&keys.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes());
    let mut axes: u64 = 0;
    let mut absinfo = [[0i32; 5]; AXES];
    for (axis, code) in STICKS {
        if let Some(ev) = pad.axis_code(axis) {
            let flat = (pad.deadzone(ev).unwrap_or(0.0).clamp(0.0, 1.0) * FULL as f32) as i32;
            axes |= 1 << code;
            absinfo[code as usize] = [-FULL, FULL, 0, flat, 0];
        }
    }
    if pad.button_code(Button::LeftTrigger2).is_some() {
        axes |= 1 << ABS_BRAKE;
        absinfo[ABS_BRAKE as usize] = [0, FULL, 0, 0, 0];
    }
    if pad.button_code(Button::RightTrigger2).is_some() {
        axes |= 1 << ABS_GAS;
        absinfo[ABS_GAS as usize] = [0, FULL, 0, 0, 0];
    }
    if pad.axis_code(Axis::DPadX).is_some() || pad.button_code(Button::DPadLeft).is_some() {
        axes |= 1 << ABS_HAT0X;
        absinfo[ABS_HAT0X as usize] = [-1, 1, 0, 0, 0];
    }
    if pad.axis_code(Axis::DPadY).is_some() || pad.button_code(Button::DPadUp).is_some() {
        axes |= 1 << ABS_HAT0Y;
        absinfo[ABS_HAT0Y as usize] = [-1, 1, 0, 0, 0];
    }
    out.extend_from_slice(&axes.to_le_bytes());
    for info in absinfo {
        for field in info {
            out.extend_from_slice(&field.to_le_bytes());
        }
    }
    out
}

/// The wire's events for one of gilrs's, none for one the wire does not carry.
fn translate(event: &EventType) -> Vec<[u8; 8]> {
    match event {
        EventType::ButtonPressed(button, _) => pressed(*button, true),
        EventType::ButtonReleased(button, _) => pressed(*button, false),
        EventType::ButtonChanged(Button::LeftTrigger2, value, _) => vec![frame(EV_ABS, ABS_BRAKE, scale(*value))],
        EventType::ButtonChanged(Button::RightTrigger2, value, _) => vec![frame(EV_ABS, ABS_GAS, scale(*value))],
        EventType::AxisChanged(axis, value, _) => match axis {
            Axis::LeftStickX => vec![frame(EV_ABS, ABS_X, scale(*value))],
            Axis::LeftStickY => vec![frame(EV_ABS, ABS_Y, scale(-*value))],
            Axis::RightStickX => vec![frame(EV_ABS, ABS_RX, scale(*value))],
            Axis::RightStickY => vec![frame(EV_ABS, ABS_RY, scale(-*value))],
            Axis::DPadX => vec![frame(EV_ABS, ABS_HAT0X, hat(*value))],
            Axis::DPadY => vec![frame(EV_ABS, ABS_HAT0Y, hat(-*value))],
            _ => Vec::new(),
        },
        _ => Vec::new(),
    }
}

/// A button's event, the dpad's as the hat's axes.
fn pressed(button: Button, down: bool) -> Vec<[u8; 8]> {
    let value = if down { 1 } else { 0 };
    match button {
        Button::DPadUp => vec![frame(EV_ABS, ABS_HAT0Y, -value)],
        Button::DPadDown => vec![frame(EV_ABS, ABS_HAT0Y, value)],
        Button::DPadLeft => vec![frame(EV_ABS, ABS_HAT0X, -value)],
        Button::DPadRight => vec![frame(EV_ABS, ABS_HAT0X, value)],
        other => match BUTTONS.iter().find(|(b, _)| *b == other) {
            Some((_, code)) => vec![frame(EV_KEY, *code, value)],
            None => Vec::new(),
        },
    }
}

/// A value from -1 to 1 at the wire's full scale.
fn scale(value: f32) -> i32 {
    (value.clamp(-1.0, 1.0) * FULL as f32).round() as i32
}

/// A hat's value, -1, 0, or 1.
fn hat(value: f32) -> i32 {
    value.clamp(-1.0, 1.0).round() as i32
}

/// One event as the port takes it: type, code, value, little-endian.
fn frame(kind: u16, code: u16, value: i32) -> [u8; 8] {
    let mut out = [0u8; 8];
    out[..2].copy_from_slice(&kind.to_le_bytes());
    out[2..4].copy_from_slice(&code.to_le_bytes());
    out[4..].copy_from_slice(&value.to_le_bytes());
    out
}

/// The port's pipe opened to write, the client QEMU waits for on Windows.
#[cfg(windows)]
fn open_pipe(pipe: &str) -> Result<File, String> {
    jabpipe::connect(pipe, |path| OpenOptions::new().write(true).open(path)).map_err(|error| error.to_string())
}

/// The port's pipe, a fifo QEMU holds open, opened to write.
#[cfg(not(windows))]
fn open_pipe(pipe: &str) -> Result<File, String> {
    OpenOptions::new().write(true).open(pipe).map_err(|error| format!("{pipe}: {error}"))
}
