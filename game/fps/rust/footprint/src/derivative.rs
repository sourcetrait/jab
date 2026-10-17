use crate::*;

/// The bits of 1/z's fraction, DEPTH_BITS in render.inc: 6.26.
pub(crate) const DEPTH_BITS: u32 = 26;

/// A row derivative exactly, as row_derivative takes it: None where it saturates.
pub(crate) fn row_derivative(coord: i64, izb: i64, uzb: i64, z: i64) -> Option<i64> {
    let product = i64::try_from((coord as i128 * izb as i128) >> DEPTH_BITS).ok()?;
    let difference = uzb.checked_sub(product)?;
    let scaled = i64::try_from((difference as i128 * z as i128) >> 16).ok()?;
    scaled.checked_abs()
}

/// The derivative's answer as the tool prints it.
pub(crate) fn derivative_nuon(coord: i64, izb: i64, uzb: i64, z: i64) -> Nuon {
    let value = row_derivative(coord, izb, uzb, z);
    Nuon::Record(vec![
        ("saturated".to_string(), Nuon::Bool(value.is_none())),
        ("value".to_string(), value.map(Nuon::Int).unwrap_or(Nuon::Null)),
    ])
}
