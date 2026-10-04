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

## word_disk

`6 u8`: a disk line's first word.

## word_kind

`7 u8`: the word before a disk's kind.

## word_sectors

`10 u8`: the word before a disk's sectors.

## word_serial

`9 u8`: the word before a disk's serial.

## word_count

`7 u8`: the page line's first word.

## word_next

`7 u8`: the word before the next page's id.

## word_write

`7 u8`: the write line's first word.

## disks

`320 u8`: the disk records jab.sys.block.list wrote.

## sector

`512 u8`: the sector written to the first disk, zeroes.

## line

`256 u8`: the line being built.

## lineptr

`addr`: the cursor in line.

## digits

`32 u8`: line_dec's digits, built backward.
