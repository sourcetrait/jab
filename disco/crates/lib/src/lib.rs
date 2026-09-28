//! What the expected devices are for LowKick's tools and launchers,
//! answered blind: the gamepad and the audio output, one record, as
//! pretty NUON. gilrs enumerates every device it can attach a mapping
//! to, which takes in more than gamepads, so the expected one is the
//! first connected device whose mapping reaches Jab's floor for a pad:
//! two sticks, a dpad, and eight buttons; with none of those there is
//! no gamepad. gilrs is given a moment to settle first, since on macOS
//! it lists pads from a thread of its own after it has started (a list
//! taken at once was empty on the reference host, and complete 210 ms
//! later). On Linux its evdev path is what QEMU's host-input device
//! takes; elsewhere the path is null and the name, vendor, and product
//! tell a launcher what to bridge. The audio output is the one the
//! host's own sound system calls its default, asked through cpal: on
//! Linux the sound server first, over the PulseAudio protocol that
//! PipeWire speaks as well, whose default sink is the user's configured
//! choice, else ALSA's default device; CoreAudio's and WASAPI's default
//! output elsewhere. No output that opens is no audio. `debug()` is the
//! same record with a `debug` item beside them: every gamepad gilrs
//! sees and every audio host and output device cpal sees, for a report
//! when discovery finds nothing or the wrong thing.

use std::fmt::Display;
use std::time::{Duration, Instant};

use cpal::traits::{DeviceTrait, HostTrait};
use gilrs::{Axis, Button, Gilrs};

/// The expected gamepad.
struct Gamepad {
    /// The device's own name, as the OS reports it.
    name: String,
    /// Its evdev path on Linux; none elsewhere.
    path: Option<String>,
    vendor: Option<u16>,
    product: Option<u16>,
}

/// The expected audio output.
struct Audio {
    /// The cpal host that answered: pulseaudio, alsa, coreaudio, wasapi.
    server: String,
    /// The output's name as the sound system describes it.
    name: String,
    /// The sound system's own identifier for it: a sink name on a sound
    /// server, a PCM name on ALSA, the system's id elsewhere.
    id: String,
    channels: u16,
    /// Frames a second.
    rate: u32,
    /// The sample format the output runs at, cpal's name for it.
    format: String,
}

/// Discover, and say what was found as one pretty NUON record:
/// `{ gamepad: { name, path, vendor, product }, audio: { server, name,
/// id, channels, rate, format } }`, either item null when there is none.
pub fn discover() -> String {
    format!("{{\n{},\n{}\n}}", gamepad_item(), audio_item())
}

/// The same record as `discover()` with a `debug` item beside the two:
/// everything gilrs and cpal know, for a report when discovery finds
/// nothing or the wrong thing. See `debug_item`.
pub fn debug() -> String {
    format!(
        "{{\n{},\n{},\n{}\n}}",
        gamepad_item(),
        audio_item(),
        debug_item()
    )
}

/// The record's `gamepad` item, as `discover()` prints it.
fn gamepad_item() -> String {
    match expected_gamepad() {
        Some(pad) => format!(
            "  gamepad: {{\n    name: {},\n    path: {},\n    vendor: {},\n    product: {}\n  }}",
            quoted(&pad.name),
            pad.path.as_deref().map(quoted).unwrap_or_else(|| "null".to_string()),
            number(pad.vendor),
            number(pad.product),
        ),
        None => "  gamepad: null".to_string(),
    }
}

/// The record's `audio` item, as `discover()` prints it.
fn audio_item() -> String {
    match expected_audio() {
        Some(audio) => format!(
            "  audio: {{\n    server: {},\n    name: {},\n    id: {},\n    channels: {},\n    rate: {},\n    format: {}\n  }}",
            quoted(&audio.server),
            quoted(&audio.name),
            quoted(&audio.id),
            audio.channels,
            audio.rate,
            quoted(&audio.format),
        ),
        None => "  audio: null".to_string(),
    }
}

/// The floor's buttons and axes, by the names the report uses.
const BUTTONS: [(&str, Button); 19] = [
    ("south", Button::South),
    ("east", Button::East),
    ("north", Button::North),
    ("west", Button::West),
    ("c", Button::C),
    ("z", Button::Z),
    ("left_trigger", Button::LeftTrigger),
    ("left_trigger2", Button::LeftTrigger2),
    ("right_trigger", Button::RightTrigger),
    ("right_trigger2", Button::RightTrigger2),
    ("select", Button::Select),
    ("start", Button::Start),
    ("mode", Button::Mode),
    ("left_thumb", Button::LeftThumb),
    ("right_thumb", Button::RightThumb),
    ("dpad_up", Button::DPadUp),
    ("dpad_down", Button::DPadDown),
    ("dpad_left", Button::DPadLeft),
    ("dpad_right", Button::DPadRight),
];
const AXES: [(&str, Axis); 8] = [
    ("left_stick_x", Axis::LeftStickX),
    ("left_stick_y", Axis::LeftStickY),
    ("left_z", Axis::LeftZ),
    ("right_stick_x", Axis::RightStickX),
    ("right_stick_y", Axis::RightStickY),
    ("right_z", Axis::RightZ),
    ("dpad_x", Axis::DPadX),
    ("dpad_y", Axis::DPadY),
];

/// The record's `debug` item, everything gilrs and cpal know: the host,
/// how many gamepads gilrs listed straight after it started and how
/// many once settled (on macOS its backend reports devices from a
/// run-loop thread, so the first count is short: 0 then 1 on TheUser's
/// host, in 210 ms), how long that took, per connected gamepad its
/// names, uuid, ids, mapping source and name, which buttons and axes
/// its mapping has, and whether it reaches the floor; then every audio
/// host cpal finds available, in the order discovery asks them, with
/// its default output and every output device, each with its id, name,
/// driver, type, interface, direction, and the configuration it opens
/// at, null when it will not open. Its own gilrs and its own hosts, so
/// the items beside it are exactly what `discover()` sees.
fn debug_item() -> String {
    let mut out = String::new();
    out.push_str("  debug: {\n");
    out.push_str(&format!("    platform: {},\n", quoted(std::env::consts::OS)));
    match Gilrs::new() {
        Ok(gilrs) | Err(gilrs::Error::NotImplemented(gilrs)) => {
            gamepads_debug(&mut out, gilrs);
        }
        Err(error) => {
            out.push_str(&format!("    gamepads_error: {},\n", quoted(&error.to_string())));
        }
    }
    audio_debug(&mut out);
    out.push_str("  }");
    out
}

/// The debug item's gamepad lines.
fn gamepads_debug(out: &mut String, mut gilrs: Gilrs) {
    let before = gilrs.gamepads().count();
    let settled_ms = settle(&mut gilrs).as_millis();
    let after = gilrs.gamepads().count();
    out.push_str(&format!("    before_settle: {before},\n    after_settle: {after},\n    settled_ms: {settled_ms},\n"));
    out.push_str("    gamepads: [\n");
    for (id, pad) in gilrs.gamepads() {
        out.push_str("      {\n");
        out.push_str(&format!("        id: {},\n", quoted(&id.to_string())));
        out.push_str(&format!("        name: {},\n", quoted(pad.name())));
        out.push_str(&format!("        os_name: {},\n", quoted(pad.os_name())));
        out.push_str(&format!("        uuid: {},\n", quoted(&hex(&pad.uuid()))));
        out.push_str(&format!("        vendor: {},\n", number(pad.vendor_id())));
        out.push_str(&format!("        product: {},\n", number(pad.product_id())));
        out.push_str(&format!("        path: {},\n", device_path(&pad).as_deref().map(quoted).unwrap_or_else(|| "null".to_string())));
        out.push_str(&format!("        connected: {},\n", pad.is_connected()));
        out.push_str(&format!("        mapping_source: {},\n", quoted(&format!("{:?}", pad.mapping_source()))));
        out.push_str(&format!("        map_name: {},\n", pad.map_name().map(quoted).unwrap_or_else(|| "null".to_string())));
        out.push_str("        buttons: {\n");
        for (name, button) in BUTTONS {
            out.push_str(&format!("          {name}: {},\n", pad.button_code(button).is_some()));
        }
        out.push_str("        },\n        axes: {\n");
        for (name, axis) in AXES {
            let code = pad.axis_code(axis);
            let deadzone = code.and_then(|code| pad.deadzone(code));
            out.push_str(&format!(
                "          {name}: {{ mapped: {}, deadzone: {} }},\n",
                code.is_some(),
                deadzone.map(|d| format!("{d:.3}")).unwrap_or_else(|| "null".to_string()),
            ));
        }
        out.push_str("        },\n");
        out.push_str(&format!("        floor: {},\n", is_gamepad(&pad)));
        out.push_str("      },\n");
    }
    out.push_str("    ],\n");
}

/// The debug item's audio lines: every available host in discovery's
/// order, its default output's id, and its output devices. A sound
/// server describes its outputs without opening them; ALSA's list is
/// every PCM its configuration defines, plugins included, and opening
/// each to read its configuration has the JACK, OSS, and routing
/// plugins complain on stderr for the ones that cannot open, so ALSA's
/// devices are listed as described and left unopened.
fn audio_debug(out: &mut String) {
    let available = cpal::available_hosts();
    out.push_str(&format!(
        "    audio_hosts_available: [{}],\n",
        available.iter().map(|id| quoted(&id.to_string())).collect::<Vec<_>>().join(", ")
    ));
    out.push_str("    audio_hosts: [\n");
    for id in host_order(&available) {
        out.push_str("      {\n");
        out.push_str(&format!("        host: {},\n", quoted(&id.to_string())));
        let host = match cpal::host_from_id(id) {
            Ok(host) => host,
            Err(error) => {
                out.push_str(&format!("        error: {}\n      }},\n", quoted(&error.to_string())));
                continue;
            }
        };
        let default = host
            .default_output_device()
            .and_then(|device| device.id().ok())
            .map(|id| quoted(id.id()))
            .unwrap_or_else(|| "null".to_string());
        out.push_str(&format!("        default_output: {default},\n"));
        out.push_str("        outputs: [\n");
        let opens = id.to_string() != "alsa";
        match host.output_devices() {
            Ok(devices) => {
                for device in devices {
                    device_debug(out, &device, opens);
                }
            }
            Err(error) => {
                out.push_str(&format!("          {{ error: {} }},\n", quoted(&error.to_string())));
            }
        }
        out.push_str("        ]\n      },\n");
    }
    out.push_str("    ]\n");
}

/// One output device's debug lines, its configuration read only when
/// `opens` allows the device to be opened for it.
fn device_debug(out: &mut String, device: &cpal::Device, opens: bool) {
    out.push_str("          {\n");
    out.push_str(&format!(
        "            id: {},\n",
        device.id().map(|id| quoted(id.id())).unwrap_or_else(|_| "null".to_string())
    ));
    match device.description() {
        Ok(description) => {
            out.push_str(&format!("            name: {},\n", quoted(description.name())));
            out.push_str(&format!("            driver: {},\n", description.driver().map(quoted).unwrap_or_else(|| "null".to_string())));
            out.push_str(&format!("            type: {},\n", quoted(&description.device_type().to_string())));
            out.push_str(&format!("            interface: {},\n", quoted(&description.interface_type().to_string())));
            out.push_str(&format!("            direction: {},\n", quoted(&description.direction().to_string())));
        }
        Err(error) => {
            out.push_str(&format!("            description_error: {},\n", quoted(&error.to_string())));
        }
    }
    if !opens {
        out.push_str("            config: null\n          },\n");
        return;
    }
    match device.default_output_config() {
        Ok(config) => {
            out.push_str(&format!(
                "            channels: {},\n            rate: {},\n            format: {}\n",
                config.channels(),
                config.sample_rate(),
                quoted(&config.sample_format().to_string()),
            ));
        }
        Err(error) => {
            out.push_str(&format!("            config_error: {}\n", quoted(&error.to_string())));
        }
    }
    out.push_str("          },\n");
}

/// Bytes as lowercase hex.
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// A NUON string: double-quoted, with the quote and the backslash
/// escaped.
fn quoted(text: &str) -> String {
    let mut out = String::with_capacity(text.len() + 2);
    out.push('"');
    for c in text.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\t' => out.push_str("\\t"),
            other => out.push(other),
        }
    }
    out.push('"');
    out
}

/// A NUON number, or null.
fn number<T: Display>(value: Option<T>) -> String {
    match value {
        Some(number) => number.to_string(),
        None => "null".to_string(),
    }
}

/// Whether a device gilrs lists is a gamepad Jab can use, its floor:
/// both sticks, a dpad, and eight buttons, South, East, North, West,
/// the two shoulder buttons, Select, and Start, all in its mapping. A
/// device that merely has some buttons, a fan or power controller with
/// a control interface, does not pass.
fn is_gamepad(pad: &gilrs::Gamepad) -> bool {
    let sticks = [Axis::LeftStickX, Axis::LeftStickY, Axis::RightStickX, Axis::RightStickY];
    let buttons = [
        Button::South,
        Button::East,
        Button::North,
        Button::West,
        Button::LeftTrigger,
        Button::RightTrigger,
        Button::Select,
        Button::Start,
    ];
    sticks.iter().all(|axis| pad.axis_code(*axis).is_some())
        && (pad.button_code(Button::DPadLeft).is_some() || pad.axis_code(Axis::DPadX).is_some())
        && buttons.iter().all(|button| pad.button_code(*button).is_some())
}

/// How long gilrs's events may go quiet before its list is taken as
/// complete, and the most a listing waits in all.
const QUIET: Duration = Duration::from_millis(100);
const LONGEST: Duration = Duration::from_secs(1);

/// Pump gilrs's events until they go quiet for `QUIET`, at most
/// `LONGEST`, so a backend that reports pads from a thread of its own,
/// as macOS's does after `Gilrs::new()` has returned, has listed them.
/// How long that took.
pub fn settle(gilrs: &mut Gilrs) -> Duration {
    let started = Instant::now();
    while gilrs.next_event_blocking(Some(QUIET)).is_some() {
        if started.elapsed() > LONGEST {
            break;
        }
    }
    started.elapsed()
}

/// The first connected gamepad, once gilrs has settled; none when
/// gilrs finds nothing that is one, or cannot start.
fn expected_gamepad() -> Option<Gamepad> {
    let mut gilrs = match Gilrs::new() {
        Ok(gilrs) => gilrs,
        Err(gilrs::Error::NotImplemented(gilrs)) => gilrs,
        Err(_) => return None,
    };
    settle(&mut gilrs);
    let (_, pad) = gilrs.gamepads().find(|(_, pad)| pad.is_connected() && is_gamepad(pad))?;
    Some(Gamepad {
        name: pad.os_name().to_string(),
        path: device_path(&pad),
        vendor: pad.vendor_id(),
        product: pad.product_id(),
    })
}

#[cfg(target_os = "linux")]
fn device_path(pad: &gilrs::Gamepad) -> Option<String> {
    use gilrs::LinuxGamepadExt;
    Some(pad.devpath().to_string_lossy().into_owned())
}

#[cfg(not(target_os = "linux"))]
fn device_path(_pad: &gilrs::Gamepad) -> Option<String> {
    None
}

/// The hosts to ask, in order, out of those cpal finds available: on
/// Linux the sound server over the PulseAudio protocol first, since its
/// default sink is the user's configured output and PipeWire serves the
/// protocol too, then ALSA, whose default device the server takes over
/// when one runs; elsewhere the platform's one host.
#[cfg(target_os = "linux")]
fn host_order(available: &[cpal::HostId]) -> Vec<cpal::HostId> {
    [cpal::HostId::PulseAudio, cpal::HostId::Alsa]
        .into_iter()
        .filter(|id| available.contains(id))
        .collect()
}

#[cfg(not(target_os = "linux"))]
fn host_order(available: &[cpal::HostId]) -> Vec<cpal::HostId> {
    available.to_vec()
}

/// The default output of the first host that has one that opens: its
/// server, name, id, and the configuration it opens at. None when no
/// host has an output that opens, which is a machine with no audio.
fn expected_audio() -> Option<Audio> {
    let available = cpal::available_hosts();
    for id in host_order(&available) {
        let Ok(host) = cpal::host_from_id(id) else {
            continue;
        };
        let Some(device) = host.default_output_device() else {
            continue;
        };
        let (Ok(description), Ok(device_id), Ok(config)) =
            (device.description(), device.id(), device.default_output_config())
        else {
            continue;
        };
        return Some(Audio {
            server: id.to_string(),
            name: description.name().to_string(),
            id: device_id.id().to_string(),
            channels: config.channels(),
            rate: config.sample_rate(),
            format: config.sample_format().to_string(),
        });
    }
    None
}
