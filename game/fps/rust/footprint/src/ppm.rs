use crate::*;

/// The stamp's cells, the top-left pixels a debug HUD writes the frame's number in.
pub(crate) const STAMP_W: usize = 64;
pub(crate) const STAMP_H: usize = 4;

/// A P6 capture: its size and its pixels, three bytes each, rows from the top.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Image {
    pub(crate) width: usize,
    pub(crate) height: usize,
    pub(crate) pixels: Vec<u8>,
}

impl Image {
    /// The pixel's red, green, and blue.
    pub(crate) fn rgb(&self, x: usize, y: usize) -> [u8; 3] {
        let at = (y * self.width + x) * 3;
        [self.pixels[at], self.pixels[at + 1], self.pixels[at + 2]]
    }

    /// The pixel as the framebuffer's word held it, 0x00RRGGBB.
    pub(crate) fn word(&self, x: usize, y: usize) -> u32 {
        let [r, g, b] = self.rgb(x, y);
        (r as u32) << 16 | (g as u32) << 8 | b as u32
    }
}

/// Whether a pixel lies under the stamp's cells, which every reading skips.
pub(crate) fn in_stamp(x: usize, y: usize) -> bool {
    x < STAMP_W && y < STAMP_H
}

/// A capture read from its file.
pub(crate) fn read_ppm(path: &Path) -> FootprintResult<Image> {
    let bytes = fs::read(path).map_err(FootprintError::io(path))?;
    parse_ppm(&bytes).map_err(|message| FootprintError::refused(path, message))
}

/// A P6 image from its bytes: the magic, the width, the height, a maxval of 255.
pub(crate) fn parse_ppm(bytes: &[u8]) -> Result<Image, String> {
    let mut at = 0;
    let mut fields = Vec::new();
    while fields.len() < 4 {
        while at < bytes.len() && (bytes[at].is_ascii_whitespace() || bytes[at] == b'#') {
            if bytes[at] == b'#' {
                while at < bytes.len() && bytes[at] != b'\n' {
                    at += 1;
                }
            } else {
                at += 1;
            }
        }
        let start = at;
        while at < bytes.len() && !bytes[at].is_ascii_whitespace() {
            at += 1;
        }
        if start == at {
            return Err("the header ends before its four fields".to_string());
        }
        fields.push(String::from_utf8_lossy(&bytes[start..at]).into_owned());
    }
    if fields[0] != "P6" {
        return Err(format!("not a P6 image: its magic is {}", fields[0]));
    }
    let number = |field: &str, what: &str| field.parse::<usize>().map_err(|_| format!("its {what} is not a number: {field}"));
    let width = number(&fields[1], "width")?;
    let height = number(&fields[2], "height")?;
    let maxval = number(&fields[3], "maxval")?;
    if maxval != 255 {
        return Err(format!("a maxval of {maxval}, where 255 is a byte a channel"));
    }
    let data = at + 1;
    let length = width * height * 3;
    if bytes.len() < data + length {
        return Err(format!("{} bytes of pixels where {width} by {height} needs {length}", bytes.len().saturating_sub(data)));
    }
    Ok(Image { width, height, pixels: bytes[data..data + length].to_vec() })
}
