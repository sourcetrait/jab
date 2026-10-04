# main.S

displayprint: the print calls by device. jab.sys.print goes to the UART
until the display is open and to the screen console after; the named
calls go where they say. The program then idles so the screen can be
read.

## uart_first

`12 u8`: jab.sys.print's line before the display is open.

## on_screen

`11 u8`: jab.sys.print's line once the display is open.

## uart_again

`12 u8`: jab.sys.uart.print's line.

## line_two

`10 u8`: jab.sys.display.print's line.

## msg_no_display

`26 u8`: the line for a machine with no display.
