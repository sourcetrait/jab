# random's integration test: the kernel finds the machine's rng device
# and jab.sys.random fills a program's buffer from it. Two draws of 64
# bytes each come back whole, differ from each other, and spread over
# many values, which is what entropy from the host looks like and what
# a stuck or zeroed device would not.
use ../../../sdk/nu/jab.nu
use std/assert

# 128 bytes drawn uniformly take about 101 distinct values; a floor of
# 40 is far below any run of a working device and above any broken one
const DISTINCT_FLOOR = 40

def main [--kernel: path, --image: path, --out: path, --set: string = ""] {
    let run = (jab launch --kernel $kernel --image $image --out $out --set $set --seconds 8)
    assert equal $run.status 0 $"exit status, with the UART: ($run.serial)"
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest"
    assert ($run.debug | str contains "jab: rng at ") $"the kernel found the rng device: ($run.debug)"
    let lines = ($run.serial | lines)
    assert equal ($lines | length) 4 $"two draws, each a count and a line of bytes: ($run.serial)"
    assert equal $lines.0 "bytes 64" "the first draw came whole"
    assert equal $lines.2 "bytes 64" "and the second"
    let first = ($lines.1 | split row " " | where {|s| $s != "" } | each {|s| $s | into int })
    let second = ($lines.3 | split row " " | where {|s| $s != "" } | each {|s| $s | into int })
    assert equal ($first | length) 64 "sixty-four bytes printed for the first"
    assert equal ($second | length) 64 "and the second"
    assert ($first != $second) "the two draws differ"
    let distinct = (($first ++ $second) | uniq | length)
    assert ($distinct >= $DISTINCT_FLOOR) $"128 random bytes spread over at least ($DISTINCT_FLOOR) values: ($distinct)"
    print $"random: two draws of 64 bytes from the rng device, ($distinct) distinct values across them"
    print "random: ok"
}
