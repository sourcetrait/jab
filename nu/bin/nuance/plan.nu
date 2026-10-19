#!/usr/bin/env nu
# The SDK's program module's path, bound at parse time
const PROGRAM = path self ../../mod/program
use $PROGRAM

# A program's headless machine prepared and printed as JSON for a harness
def main [dir: path, --out: string = "", --disk: string = "", --serial: string = "disk0", --set: string = "", --api, --gamepad, --pad-port, --no-kbm, --sound, --spec (-s): string = "", --harts: int = 0, --bootargs: string = ""] {
    program plan $dir --out $out --disk $disk --serial $serial --set $set --api=$api --gamepad=$gamepad --pad-port=$pad_port --no-kbm=$no_kbm --sound=$sound --spec $spec --harts $harts --bootargs $bootargs
}
