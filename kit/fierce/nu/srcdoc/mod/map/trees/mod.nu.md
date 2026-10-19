# map/trees

Every map source of the game's content compiled into the target's asset
shard, the trees the program's disk and its tests read, alike for every
phase: the manifest's `prepare`, `bin/nuance/prepare.nu`, runs it before
the SDK builds, tests, or runs the game, and nuance.nu's `compile` runs it
alone. Each source compiles through `bin/nuance/map.nu compile` in a nu of
its own, the compiler loading its modules alone, since beside the SDK's
build module, which this module imports for the shard's path, its closures
ran half again slower (render_0's build 0.42 s to 0.64 s).

## GAME

The game's directory, `kit/fierce`, resolved from this module's own path.

## COMPILER

The map compiler's bin, `bin/nuance/map.nu`, resolved from this module's
own path.
