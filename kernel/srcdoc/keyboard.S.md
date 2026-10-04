# keyboard.S

The keyboard: QEMU's virtio-keyboard-device, a virtio-input device told from
the tablet, the other one, by carrying the letter keys in its EV_KEY bits.
Its event queue holds VIRTQ_SIZE eight-byte events the device fills; the
kernel drains them into its own ring of KEYBOARD_RING key events, refilling
the queue, when the program asks for a key or awaits one. Only EV_KEY events
are kept: the code and the value, 0 released, 1 pressed, 2 held, as Linux
defines them.

## .set KEYBOARD_RING

`u64`: the key events the kernel's ring holds.

## .set KEYBOARD_ENTRY_SIZE

`u64`: bytes in a ring entry, the code at 0 and the value at 2.

## keyboard_open

Every descriptor is an event buffer the device may write, all offered at
once. A failed open leaves the state at 0, so the next call tries again.

## msg_keyboard_at

`18 u8`: the debug line naming the keyboard's transport, under DEBUG only.

## msg_no_keyboard

`18 u8`: the debug line for a machine without one, under DEBUG only.

## keyboard_find

Asks each virtio-input transport for its EV_KEY bitmap and looks for the
letter.

## keyboard_drain

For each used element: its descriptor id, that descriptor's event; a key
event goes into the ring unless it is full; the buffer goes back to the
device, which is notified once at the end if any went back.

## keyboard_queue

The keyboard's virtqueue record.

## keyboard_events

The device's event buffers, one per descriptor.

## key_ring

The kernel's ring of key events, KEYBOARD_RING entries.

## key_head

`u64`: the count of key events put in the ring.

## key_tail

`u64`: the count of key events taken from it.

## keyboard_base

`addr`: the keyboard's transport.

## keyboard_state

`u64`: 1 once open.
