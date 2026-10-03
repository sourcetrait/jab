# main.S

blocklist: what disks the machine carries. Lists them and reports each
on the UART as `disk <id> kind <k> sectors <n> serial <s>`, then the
page's own answer as `count <n> next <n>`, then tries to write a
sector of the first disk, an asset image the tool attached read-only,
and reports the code as `write <c>`, and exits 0.

## _start

The sector written is sector 0 of disk 1, the first disk, which is
read-only.

## line_reset

The line being built: reset it, add to it, then print it.

## line_nl

The line is terminated where it ends, so a short line never shows the tail
of a longer one before it.
