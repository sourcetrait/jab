use crate::*;

/// How a screen is encoded for the agent: JPEG for a glance, PNG exact.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Format {
    Jpeg,
    Png,
}

impl Format {
    pub(crate) fn parse(text: &str) -> Option<Format> {
        match text {
            "jpeg" | "jpg" => Some(Format::Jpeg),
            "png" => Some(Format::Png),
            _ => None,
        }
    }

    pub(crate) fn mime(self) -> &'static str {
        match self {
            Format::Jpeg => "image/jpeg",
            Format::Png => "image/png",
        }
    }

    pub(crate) fn extension(self) -> &'static str {
        match self {
            Format::Jpeg => "jpg",
            Format::Png => "png",
        }
    }
}

/// The screen reduced and encoded.
pub(crate) struct Shot {
    pub(crate) width: u32,
    pub(crate) height: u32,
    pub(crate) format: Format,
    pub(crate) bytes: Vec<u8>,
}

/// A screendump's PPM reduced by a divisor, each pixel the mean of its
/// block, encoded as asked; JPEG quality 1 to 100.
pub(crate) fn capture(ppm: &Path, divisor: u32, quality: u8, format: Format) -> RoboResult<Shot> {
    let bytes = fs::read(ppm).map_err(RoboError::io(ppm.display().to_string()))?;
    let (width, height, pixels) = parse_ppm(&bytes)?;
    let divisor = divisor.max(1);
    let out_w = width / divisor;
    let out_h = height / divisor;
    if out_w == 0 || out_h == 0 {
        return Err(RoboError::Image(format!("a divisor of {divisor} leaves nothing of {width} by {height}")));
    }
    let mut out = vec![0u8; (out_w * out_h * 3) as usize];
    let count = divisor * divisor;
    for oy in 0..out_h {
        for ox in 0..out_w {
            let mut sum = [0u32; 3];
            for dy in 0..divisor {
                let row = ((oy * divisor + dy) * width) as usize;
                for dx in 0..divisor {
                    let at = (row + (ox * divisor + dx) as usize) * 3;
                    sum[0] += pixels[at] as u32;
                    sum[1] += pixels[at + 1] as u32;
                    sum[2] += pixels[at + 2] as u32;
                }
            }
            let at = ((oy * out_w + ox) * 3) as usize;
            out[at] = (sum[0] / count) as u8;
            out[at + 1] = (sum[1] / count) as u8;
            out[at + 2] = (sum[2] / count) as u8;
        }
    }
    let mut encoded = Vec::new();
    match format {
        Format::Jpeg => r::img::JpegEncoder::new_with_quality(&mut encoded, quality.clamp(1, 100)).write_image(&out, out_w, out_h, r::img::ExtendedColorType::Rgb8),
        Format::Png => r::img::PngEncoder::new(&mut encoded).write_image(&out, out_w, out_h, r::img::ExtendedColorType::Rgb8),
    }
    .map_err(|error| RoboError::Image(error.to_string()))?;
    Ok(Shot { width: out_w, height: out_h, format, bytes: encoded })
}

/// A binary PPM's size and pixels, three bytes each.
fn parse_ppm(bytes: &[u8]) -> RoboResult<(u32, u32, &[u8])> {
    let mut fields = Vec::new();
    let mut at = 0;
    while fields.len() < 4 && at < bytes.len() {
        while at < bytes.len() && bytes[at].is_ascii_whitespace() {
            at += 1;
        }
        let start = at;
        while at < bytes.len() && !bytes[at].is_ascii_whitespace() {
            at += 1;
        }
        fields.push(std::str::from_utf8(&bytes[start..at]).unwrap_or("").to_owned());
    }
    if fields.len() < 4 || fields[0] != "P6" {
        return Err(RoboError::Image("not a binary PPM".to_owned()));
    }
    let width: u32 = fields[1].parse().map_err(|_| RoboError::Image("a PPM width".to_owned()))?;
    let height: u32 = fields[2].parse().map_err(|_| RoboError::Image("a PPM height".to_owned()))?;
    at += 1;
    let needed = (width * height * 3) as usize;
    if bytes.len() < at + needed {
        return Err(RoboError::Image(format!("a PPM of {width} by {height} cut short")));
    }
    Ok((width, height, &bytes[at..at + needed]))
}

/// The peak and the mean of the first channel's magnitudes between two
/// seconds of a wav being recorded, every stride-th frame: QEMU's format
/// chunk at the start and the data from byte 44, 16-bit samples.
pub(crate) fn sound_level(wav: &Path, from: f32, to: f32, stride: usize) -> RoboResult<serde_json::Value> {
    let bytes = fs::read(wav).map_err(RoboError::io(wav.display().to_string()))?;
    if bytes.len() < 44 || &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"WAVE" {
        return Err(RoboError::Command("not a wav yet".to_owned()));
    }
    let channels = u16::from_le_bytes([bytes[22], bytes[23]]) as usize;
    let rate = u32::from_le_bytes([bytes[24], bytes[25], bytes[26], bytes[27]]) as usize;
    let bits = u16::from_le_bytes([bytes[34], bytes[35]]) as usize;
    if bits != 16 || channels == 0 || rate == 0 {
        return Err(RoboError::Command(format!("a wav of {bits} bits and {channels} channels at {rate}")));
    }
    let frame = channels * 2;
    let data = &bytes[44..];
    let frames = data.len() / frame;
    let first = ((from.max(0.0) * rate as f32) as usize).min(frames);
    let last = ((to.max(0.0) * rate as f32) as usize).min(frames);
    let mut peak = 0i32;
    let mut sum = 0i64;
    let mut n = 0i64;
    let mut i = first;
    while i < last {
        let at = i * frame;
        let sample = i16::from_le_bytes([data[at], data[at + 1]]) as i32;
        let magnitude = sample.abs();
        peak = peak.max(magnitude);
        sum += magnitude as i64;
        n += 1;
        i += stride.max(1);
    }
    Ok(serde_json::json!({
        "rate": rate,
        "channels": channels,
        "recorded_seconds": frames as f32 / rate as f32,
        "from": from,
        "to": to,
        "picks": n,
        "peak": peak,
        "mean": if n == 0 { 0.0 } else { sum as f64 / n as f64 },
    }))
}
