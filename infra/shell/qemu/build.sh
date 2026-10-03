#!/usr/bin/sh
../../../configure --prefix="$HOME/.sys/adhoc/opt/qemu" --enable-system --enable-linux-user --enable-kvm --enable-tcg --enable-plugins --enable-gcrypt --enable-sdl --enable-sdl-image --enable-opengl --enable-virglrenderer --enable-slirp --enable-passt --enable-libusb --enable-usb-redir --enable-tpm --enable-vhost-net --enable-vhost-user --enable-virtfs --enable-tools --enable-guest-agent --enable-install-blobs --enable-lto --disable-debug-info --disable-debug-tcg --disable-debug-mutex --disable-debug-graph-lock --disable-debug-remap --disable-docs -Doptimization=2
make -j"$(nproc)"
make install
