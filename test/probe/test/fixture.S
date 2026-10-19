    .text
    .p2align 4

    .globl sdl2_gl_update
    .type sdl2_gl_update, @function
sdl2_gl_update:
    .skip 0x80
    .size sdl2_gl_update, . - sdl2_gl_update

    .globl sdl2_gl_switch
    .type sdl2_gl_switch, @function
sdl2_gl_switch:
    .skip 0x40
    .size sdl2_gl_switch, . - sdl2_gl_switch

    .globl sdl2_gl_render_surface
    .hidden sdl2_gl_render_surface
    .type sdl2_gl_render_surface, @function
sdl2_gl_render_surface:
    .skip 0x60
    .size sdl2_gl_render_surface, . - sdl2_gl_render_surface

    .globl qemu_console_update
    .type qemu_console_update, @function
qemu_console_update:
    .skip 0x60
    .size qemu_console_update, . - qemu_console_update

    .skip 0x20                                  # the gap, in no function

    .globl qemu_console_update_full
    .hidden qemu_console_update_full
    .type qemu_console_update_full, @function
qemu_console_update_full:
    .skip 0x40
    .size qemu_console_update_full, . - qemu_console_update_full

    .globl dpy_gfx_update
    .type dpy_gfx_update, @function
dpy_gfx_update:
    .skip 0x40
    .size dpy_gfx_update, . - dpy_gfx_update

    .globl dpy_gfx_update_full
    .hidden dpy_gfx_update_full
    .type dpy_gfx_update_full, @function
dpy_gfx_update_full:
    .skip 0x40
    .size dpy_gfx_update_full, . - dpy_gfx_update_full

    .globl qemu_console_register_listener
    .type qemu_console_register_listener, @function
qemu_console_register_listener:
    .skip 0x40
    .size qemu_console_register_listener, . - qemu_console_register_listener

    .globl displaychangelistener_gfx_switch
    .type displaychangelistener_gfx_switch, @function
displaychangelistener_gfx_switch:
    .skip 0x40
    .size displaychangelistener_gfx_switch, . - displaychangelistener_gfx_switch

    .globl virtio_gpu_simple_process_cmd
    .type virtio_gpu_simple_process_cmd, @function
virtio_gpu_simple_process_cmd:
    .skip 0x80
    .size virtio_gpu_simple_process_cmd, . - virtio_gpu_simple_process_cmd

    .globl virtio_gpu_process_cmdq
    .type virtio_gpu_process_cmdq, @function
virtio_gpu_process_cmdq:
    .skip 0x80
    .size virtio_gpu_process_cmdq, . - virtio_gpu_process_cmdq

    .globl virtio_gpu_reset_bh
    .hidden virtio_gpu_reset_bh
    .type virtio_gpu_reset_bh, @function
virtio_gpu_reset_bh:
    .skip 0x40
    .size virtio_gpu_reset_bh, . - virtio_gpu_reset_bh

    .globl virtio_gpu_ctrl_bh
    .type virtio_gpu_ctrl_bh, @function
    .globl gpu_ctrl_entry
    .type gpu_ctrl_entry, @function
virtio_gpu_ctrl_bh:
gpu_ctrl_entry:
    .skip 0x40
    .size virtio_gpu_ctrl_bh, . - virtio_gpu_ctrl_bh
    .size gpu_ctrl_entry, . - gpu_ctrl_entry

    .type virtio_gpu_process_cmdq.cold, @function
virtio_gpu_process_cmdq.cold:
    .skip 0x20
    .size virtio_gpu_process_cmdq.cold, . - virtio_gpu_process_cmdq.cold

    .globl sdl2_gl_refresh
    .hidden sdl2_gl_refresh
    .type sdl2_gl_refresh, @function
sdl2_gl_refresh:
    .skip 0x40
    .size sdl2_gl_refresh, . - sdl2_gl_refresh

    .globl sdl2_gl_redraw
    .hidden sdl2_gl_redraw
    .type sdl2_gl_redraw, @function
sdl2_gl_redraw:
    .skip 0x40
    .size sdl2_gl_redraw, . - sdl2_gl_redraw

    .globl sdl2_gl_scanout_flush
    .hidden sdl2_gl_scanout_flush
    .type sdl2_gl_scanout_flush, @function
sdl2_gl_scanout_flush:
    .skip 0x40
    .size sdl2_gl_scanout_flush, . - sdl2_gl_scanout_flush

    .globl overlap_outer
    .hidden overlap_outer
    .type overlap_outer, @function
    .globl overlap_inner
    .hidden overlap_inner
    .type overlap_inner, @function
overlap_outer:
    .skip 0x10
overlap_inner:
    .skip 0x10
    .size overlap_inner, . - overlap_inner
    .skip 0x20
    .size overlap_outer, . - overlap_outer
