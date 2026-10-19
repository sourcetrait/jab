# present

## ordinal-violations

A guest's present sequence held to the device's count (ProbeRuns'
receipt stage): `frames` in order, each presented or not with the
present ordinal it carries, `anchor` the ordinal of the last present
before them. A presented frame's ordinal is one past the last, any
other frame's the last; every violation comes back by the frame's
index with the rule it broke, `skip` an advance past one, `repeat` a
present with the last's ordinal, `backward` an ordinal below the last,
`advance` a frame that presented nothing yet moved on, with its ordinal
and the one wanted, each frame judged against the one before as it
reads, so one fault is one violation. None where the sequence holds.

## k-violations

The presentation contract's K over a run's presented acceptances in
order, the receipts' stamps in ticks: every pair i < j stands more than
(j - i) periods less `eps` apart. With q the acceptance less its index
times the period, K holds for every pair exactly when each q exceeds
the largest earlier q less eps, so the running maximum and its index
are kept and the check is linear. Every violation by its flip's index,
its witness the index of that maximum, the two flips' gap, and the
bound it did not pass. Read only on a present sequence that held
(ordinal-violations), so no present is missing from the flips.
