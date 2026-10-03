# keyboard.S

The keyboard: QEMU's virtio-keyboard-device, a virtio-input device told from
the tablet, the other one, by carrying the letter keys in its EV_KEY bits.
Its event queue holds VIRTQ_SIZE eight-byte events the device fills; the
kernel drains them into its own ring of KEYBOARD_RING key events, refilling
the queue, when the program asks for a key or awaits one. Only EV_KEY events
are kept: the code and the value, 0 released, 1 pressed, 2 held, as Linux
defines them.

## keyboard_open

Every descriptor is an event buffer the device may write, all offered at
once. A failed open leaves the state at 0, so the next call tries again.

## keyboard_find

Asks each virtio-input transport for its EV_KEY bitmap and looks for the
letter.

## keyboard_drain

For each used element: its descriptor id, that descriptor's event; a key
event goes into the ring unless it is full; the buffer goes back to the
device, which is notified once at the end if any went back.
