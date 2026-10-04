# jab_pad.inc

What the pad's calls speak, evdev's own names (input-event-codes.h): the
event types jab.sys.pad.input reports, the gamepad's key codes from
BTN_GAMEPAD on, and the axis codes, each also the index of its entry in a
state record's axes. Included by jab.inc.

## .set JAB_EV_KEY

`u16`: a pad event's type for a key.

## .set JAB_EV_ABS

`u16`: a pad event's type for an axis.

## .set JAB_BTN_GAMEPAD

`u16`: the first gamepad key; a key's bit in a state record's keys is its code less this.

## .set JAB_BTN_SOUTH

`u16`.

## .set JAB_BTN_EAST

`u16`.

## .set JAB_BTN_C

`u16`.

## .set JAB_BTN_NORTH

`u16`.

## .set JAB_BTN_WEST

`u16`.

## .set JAB_BTN_Z

`u16`.

## .set JAB_BTN_TL

`u16`.

## .set JAB_BTN_TR

`u16`.

## .set JAB_BTN_TL2

`u16`.

## .set JAB_BTN_TR2

`u16`.

## .set JAB_BTN_SELECT

`u16`.

## .set JAB_BTN_START

`u16`.

## .set JAB_BTN_MODE

`u16`.

## .set JAB_BTN_THUMBL

`u16`.

## .set JAB_BTN_THUMBR

`u16`.

## .set JAB_ABS_X

`u16`.

## .set JAB_ABS_Y

`u16`.

## .set JAB_ABS_Z

`u16`.

## .set JAB_ABS_RX

`u16`.

## .set JAB_ABS_RY

`u16`.

## .set JAB_ABS_RZ

`u16`.

## .set JAB_ABS_GAS

`u16`.

## .set JAB_ABS_BRAKE

`u16`.

## .set JAB_ABS_HAT0X

`u16`.

## .set JAB_ABS_HAT0Y

`u16`.
