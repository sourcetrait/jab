# main.S

purity: the program behind the release-purity test, which reads the
kernel images rather than running one. It exits 0 and reports which
build it is, so a debug build of it can be told from a release one.

## msg_debug

`21 u8`: the line a debug build adds, defined only with DEBUG.

## msg_done

`14 u8`: the line every build prints.
