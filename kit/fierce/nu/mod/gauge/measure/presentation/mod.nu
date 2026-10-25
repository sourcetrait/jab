# The cadence that awaits after its flip
export const CADENCE_AFTER_FLIP = 0

# The cadence that waits only while early, its waits the wakes eps is read from
export const CADENCE_IF_EARLY = 1

# The cap a frame's period comes from when the identity names none
export const CAP = 60

# A flip's status when presented
export const FLIP_PRESENTED = 0

# A flip's status when refused before the tick
export const FLIP_EARLY = 1

# The flip statuses a valid measurement holds, presented and early
export const FLIP_VALID = [0 1]

# The presentation contract's on-time tolerance at most, in ticks: 1 ms
export const EPS_CAP = 10000

# A flip's status preset at a frame's start, kept when it reaches no flip
export const FLIP_NONE = 255

# The cadences: 0 awaits after the flip, 1 waits only if early, 2 on the tick
export const CADENCES = [0 1 2]

# The cadences a run may ask, the program's own: 1 alone
export const LAUNCHABLE = [1]
