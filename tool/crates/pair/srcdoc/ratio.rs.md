# ratio.rs

Every solver step is integer arithmetic in i128, checked. The admitted
inputs bound each quantity (PairBracket's arithmetic, Astra's review 12):
a centered stamp within 2^40 ticks, a drift range's parts under 2^31; a
break's parts, differences of two stamps, under 2^41; an envelope's value
at a break times its denominator under 2^82; an upload's place, a ratio of
such terms, its numerator under 2^83; a comparison of two at different b by
cross-multiplication under 2^124. So i128 holds every step at the limits,
and the checks remain so a limit misjudged is a named refusal.

## fn mul

## fn add

## fn sub

## struct Ratio

Never reduced in the solver: reducing would cost a gcd per value and buys
nothing the bounds need. `text` reduces for reading alone.

### fn new

### fn whole

### fn order

### fn less

### fn approx

### fn ppm

### fn text

## fn gcd
