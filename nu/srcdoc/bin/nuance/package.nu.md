# package.nu

The package module's command line, each verb one call of the module, a
standalone bin a packaged bench's preflight step runs by its path from
the program's directory, `../../nu/bin/nuance/package.nu`.

## main make

`nu/bin/nuance/package.nu make <spec> <stage> <out>`: a package made from
its spec, staged in a fresh directory, written as one tar.

## main check

`nu/bin/nuance/package.nu check <dir>`: an extracted package held to its
manifest, every problem printed, failing on any.

## main preflight

`nu/bin/nuance/package.nu preflight <dir> --spec <name> --image <rel>
--kernel <rel> --tree <rel> --serial <serial> --bench <rel> --out <dir>`:
the packaged bench's gate, its readings in `<out>/preflight.nuon`,
failing on any refusal.
