# derivative.rs

## const DEPTH_BITS

## fn row_derivative

render.inc's row_derivative in i128, exactly: the product shifted with an
arithmetic shift, as the guest's 128-bit shift floors, then narrowed; the
subtraction checked; the second product the same; and the most negative
value's absolute an overflow. test/footprint holds the guest's every case
to it.

## fn derivative_nuon
