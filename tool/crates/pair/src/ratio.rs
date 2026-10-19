use crate::*;

/// The product, its overflow refused at the named step.
pub(crate) fn mul(a: i128, b: i128, step: &'static str) -> PairResult<i128> {
    a.checked_mul(b).ok_or_else(|| PairError::overflow(step))
}

/// The sum, its overflow refused at the named step.
pub(crate) fn add(a: i128, b: i128, step: &'static str) -> PairResult<i128> {
    a.checked_add(b).ok_or_else(|| PairError::overflow(step))
}

/// The difference, its overflow refused at the named step.
pub(crate) fn sub(a: i128, b: i128, step: &'static str) -> PairResult<i128> {
    a.checked_sub(b).ok_or_else(|| PairError::overflow(step))
}

/// An exact rational, its denominator positive, its parts never reduced.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Ratio {
    pub(crate) num: i128,
    pub(crate) den: i128,
}

impl Ratio {
    /// num over den, the sign carried by the numerator.
    pub(crate) fn new(num: i128, den: i128, step: &'static str) -> PairResult<Ratio> {
        match den.cmp(&0) {
            Ordering::Greater => Ok(Ratio { num, den }),
            Ordering::Less => Ok(Ratio {
                num: sub(0, num, step)?,
                den: sub(0, den, step)?,
            }),
            Ordering::Equal => Err(PairError::Internal(format!("a zero denominator at {step}"))),
        }
    }

    /// A whole number.
    pub(crate) fn whole(value: i128) -> Ratio {
        Ratio { num: value, den: 1 }
    }

    /// The order of two rationals, by cross-multiplication.
    pub(crate) fn order(self, other: Ratio, step: &'static str) -> PairResult<Ordering> {
        Ok(mul(self.num, other.den, step)?.cmp(&mul(other.num, self.den, step)?))
    }

    /// The rational less a whole number.
    pub(crate) fn less(self, value: i128, step: &'static str) -> PairResult<Ratio> {
        Ok(Ratio {
            num: sub(self.num, mul(value, self.den, step)?, step)?,
            den: self.den,
        })
    }

    /// The nearest double, for reading.
    pub(crate) fn approx(self) -> f64 {
        self.num as f64 / self.den as f64
    }

    /// Parts per million past one, for reading.
    pub(crate) fn ppm(self) -> f64 {
        (self.num as f64 - self.den as f64) / self.den as f64 * 1e6
    }

    /// Lowest terms, written p/q.
    pub(crate) fn text(self) -> String {
        let divisor = gcd(self.num.unsigned_abs(), self.den.unsigned_abs()) as i128;
        format!("{}/{}", self.num / divisor, self.den / divisor)
    }
}

/// The greatest common divisor, one where both are zero.
fn gcd(mut a: u128, mut b: u128) -> u128 {
    while b != 0 {
        (a, b) = (b, a % b);
    }
    if a == 0 { 1 } else { a }
}
