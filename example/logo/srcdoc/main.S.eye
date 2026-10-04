j _start [13:51] :reads the PNG off the romfs, decodes it, draws it centred, and idles until the window closes
j local no_file [53:55] :says so on the UART and exits with 1
j local bad_png [56:58] :says so on the UART and exits with 1
j local no_display [59:61] :says so on the UART and exits with 1
