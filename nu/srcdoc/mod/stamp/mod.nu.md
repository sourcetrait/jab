# stamp

## id

What a build was made from, for its stamp: the flags, then every
input path, sorted, so a source or asset deleted or renamed changes
the stamp and forces the build, which the newest-input check alone
cannot see, since a file that is gone is newer than nothing.

## stale

Whether `output` needs building: missing, older than an input, or
built from other flags or inputs than `stamp` records.
