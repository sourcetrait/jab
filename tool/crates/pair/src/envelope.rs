use crate::*;

const HULL: &str = "an envelope's hull";
const CROSSING: &str = "a crossing of two lines";
const VALUE: &str = "an envelope's value";
const SEARCH: &str = "a break's search";

/// The value c less b times x, a function of the drift b.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Line {
    pub(crate) c: i128,
    pub(crate) x: i128,
}

/// The least or the greatest of a set of lines at each b: a hull and its breaks.
pub(crate) struct Envelope {
    sign: i128,
    lines: Vec<Line>,
    breaks: Vec<Ratio>,
}

impl Envelope {
    /// The least of the lines at every b.
    pub(crate) fn min(lines: &[Line]) -> PairResult<Envelope> {
        Envelope::hull(lines.to_vec(), 1)
    }

    /// The greatest of the lines at every b.
    pub(crate) fn max(lines: &[Line]) -> PairResult<Envelope> {
        let negated = lines
            .iter()
            .map(|line| {
                Ok(Line {
                    c: sub(0, line.c, HULL)?,
                    x: sub(0, line.x, HULL)?,
                })
            })
            .collect::<PairResult<Vec<Line>>>()?;
        Envelope::hull(negated, -1)
    }

    /// The least of lines in order of x, the lines no b needs dropped.
    fn hull(mut lines: Vec<Line>, sign: i128) -> PairResult<Envelope> {
        if lines.is_empty() {
            return Err(PairError::Internal("an envelope of no lines".to_owned()));
        }
        lines.sort_by(|a, b| a.x.cmp(&b.x).then(a.c.cmp(&b.c)));
        lines.dedup_by(|later, kept| later.x == kept.x);
        let mut hull: Vec<Line> = Vec::with_capacity(lines.len());
        for line in lines {
            while hull.len() >= 2 {
                let first = hull[hull.len() - 2];
                let top = hull[hull.len() - 1];
                let reach = mul(
                    sub(line.c, first.c, HULL)?,
                    sub(top.x, first.x, HULL)?,
                    HULL,
                )?;
                let held = mul(
                    sub(top.c, first.c, HULL)?,
                    sub(line.x, first.x, HULL)?,
                    HULL,
                )?;
                if reach <= held {
                    hull.pop();
                } else {
                    break;
                }
            }
            hull.push(line);
        }
        let breaks = hull
            .windows(2)
            .map(|pair| crossing(pair[0], pair[1]))
            .collect::<PairResult<Vec<Ratio>>>()?;
        Ok(Envelope {
            sign,
            lines: hull,
            breaks,
        })
    }

    /// The breaks between the hull's lines, increasing.
    pub(crate) fn breaks(&self) -> &[Ratio] {
        &self.breaks
    }

    /// The envelope's value at b, times b's denominator.
    pub(crate) fn at(&self, b: Ratio) -> PairResult<i128> {
        let line = self.lines[self.index(b, false)?];
        let value = sub(
            mul(line.c, b.den, VALUE)?,
            mul(b.num, line.x, VALUE)?,
            VALUE,
        )?;
        mul(value, self.sign, VALUE)
    }

    /// The line, in its own terms, that holds the envelope just past b.
    pub(crate) fn after(&self, b: Ratio) -> PairResult<Line> {
        let line = self.lines[self.index(b, true)?];
        Ok(Line {
            c: mul(line.c, self.sign, VALUE)?,
            x: mul(line.x, self.sign, VALUE)?,
        })
    }

    /// How many breaks lie below b, or at or below it when `through`.
    fn index(&self, b: Ratio, through: bool) -> PairResult<usize> {
        let (mut low, mut high) = (0, self.breaks.len());
        while low < high {
            let mid = (low + high) / 2;
            let below = match self.breaks[mid].order(b, SEARCH)? {
                Ordering::Less => true,
                Ordering::Equal => through,
                Ordering::Greater => false,
            };
            if below {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        Ok(low)
    }
}

/// The b where two lines of different x meet.
fn crossing(a: Line, b: Line) -> PairResult<Ratio> {
    Ratio::new(sub(b.c, a.c, CROSSING)?, sub(b.x, a.x, CROSSING)?, CROSSING)
}
