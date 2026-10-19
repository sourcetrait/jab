#!/usr/bin/env nu
# The asset trees' path, bound at parse time
const TREES = path self ../../mod/map/trees
use $TREES

# The manifest's prepare: every map source compiled into the asset shard
def main [phase: string] {
    trees
}
