#!/usr/bin/env nu
# The script form of the SDK's launch's path, bound at parse time
const LAUNCH = path self ../../mod/nuance/launch
use $LAUNCH

# A program run headless under QEMU by launch, its record printed as NUON
def main [
    --kernel: path
    --image: path
    --out: path
    --seconds: int = 10
    --capture: duration = 0sec
    --screen: duration = 0sec
    --keys: string = "[]"
    --api
    --send: string = "[]"
    --disk: string = ""
    --serial: string = "disk0"
    --set: string = ""
    --pad: string = ""
    --pad-port
    --kbm
    --no-kbm
    --sound
    --window
    --live-sound
    --host-pad
    --spec (-s): string = ""
    --harts: int = 0
    --bootargs: string = ""
    --dtb: string = ""
    --threads: duration = 0sec
    --threads-at: string = "[]"
    --qemu: string = "[]"
    --sdl-probe: string = ""
    --capture-nonce: int = 0
    --profile: string = ""
] {
    launch --kernel $kernel --image $image --out $out --seconds $seconds --capture $capture --screen $screen --keys $keys --api=$api --send $send --disk $disk --serial $serial --set $set --pad $pad --pad-port=$pad_port --kbm=$kbm --no-kbm=$no_kbm --sound=$sound --window=$window --live-sound=$live_sound --host-pad=$host_pad --spec $spec --harts $harts --bootargs $bootargs --dtb $dtb --threads $threads --threads-at $threads_at --qemu $qemu --sdl-probe $sdl_probe --capture-nonce $capture_nonce --profile $profile
}
