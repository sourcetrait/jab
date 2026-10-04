# The content

Jab FPS's own content, by kind: `map/` the map sources, `texture/`
and `sprite/` the images, `ambient/` the pieces played by sector, and
`sound/` the effects. Every asset is authored as a text file beside
the file the engine reads: an image as an SVG rendered to a PNG by
`rust/svg2png`, an ambient piece as a note list rendered to a MIDI
file by `nu/ambient.nu`, a sound as a synthesis recipe rendered to PCM
by `nu/sound.nu`; `just adv render` makes each from the other. A map
source compiles through `nu/map.nu` into the tree a run carries.

## The look

The game is set in FPS Tech's factory, a fictional maker of androids:
a working plant, contemporary and industrial, clean but used. The
factory floor is poured concrete under a corrugated metal roof deck,
its walls painted concrete block with a safety-yellow band at the
base. The offices on the mezzanine have carpet tiles in blue-grey,
a suspended tile ceiling, and plaster walls in warm off-white. The
garage below is asphalt with white parking stripes under a low deck.
Outside, the yard is asphalt, the facade is red-brown brick over a
concrete plinth, the fences are galvanised chain-link, and the sky is
blue with light cloud.

The palette: concrete greys around `#8a8c88`, safety yellow `#e0b62a`,
FPS Tech blue `#1e6fbf` on signs and the androids' accents, steel
`#7d838a`, brick `#9b5a44` and its neighbours, plaster `#d8cfc0`.

The android is a humanoid frame 1.8 metres tall: a matte pale-grey
shell over darker joints, a smooth head with one horizontal blue
visor band, FPS Tech blue on the shoulders and the chest plate, and a
serial marking. It carries the G-1 across its chest while standing or
patrolling and shouldered while aiming or firing. The G-1 is a rifle
of the AR-15 pattern in black polymer and steel: a flat top, a
magazine well holding a thirty-round magazine, a muzzle; the player's
own is unseen, a semi-translucent dot at the screen's centre marking
the aim.

The drawing style is flat colour with two tones a surface and a dark
outline, readable at 64 pixels; no gradients are needed and no text
elements, lettering being drawn as shapes, since the renderer has no
font. The sky is the one exception: a smooth gradient with soft,
blurred clouds and no outlines.

## The formats

- An image is an SVG whose width and height are powers of two, since
  the span wraps texels by masks. A texture for a wall, floor, or
  ceiling is 256 square and tiles seamlessly on both axes. A masked
  material, a fence or a grate, has no background and its holes at
  alpha 0; the fence is 256 by 1024 with its mesh in the bottom 308
  rows, since a masked texture covers the whole opening it is drawn
  over and the yard's opening stands 8 metres. The sky is 1024 by 512
  with its top 64 rows one solid colour, which the test reads.
- A sprite is an SVG of a power-of-two size on a transparent
  background, drawn once across the entity's quad, at 128 pixels a
  metre. An android frame is 128 by 256 for a quad a metre wide and
  two tall, the feet on the bottom edge and the figure 1.8 tall; the
  aim and fire frames are 256 by 256 for a quad two metres wide, since
  a shouldered rifle reaches past a metre's width in profile, the
  figure centred and its feet still on the bottom edge; the fallen
  frame is 256 by 64 for a quad two metres long and half a metre high
  that faces the camera, the android lying on its back seen from its
  side with the floor along the bottom edge; sparks are 64 square.
  The magazine on the floor is 64 square, its HUD icon 64 by 32.
- An android's rotation frame `r`, 0 to 7, shows the android turned
  `r` eighths of a turn to its own left from facing the viewer: 0
  faces the viewer, 2 shows its right side, 4 its back, 6 its left
  side. Its states are `stand`, `walk1` to `walk4` (a step cycle),
  `aim`, `fire`, and `struck`, each in eight rotations, and `fallen`,
  one image from above; `spark1` to `spark3` are its companion where a
  round lands.
- A sound is a NUON recipe: `seconds`, and `layers`, each a `wave`
  (sine, square, saw, triangle, noise) from `frequency` sliding to
  `sweep` hertz over the sound, under an envelope of `attack`,
  `decay`, `sustain`, and `release` in seconds and a level, times a
  `gain`; the layers sum and clamp to 16-bit mono at 48 kHz.
- An ambient piece is a NUON note list: a `gain` scaling every volume
  and velocity as rendered, capped at 127, and `tracks`, each a
  `channel`, a General MIDI `program` from 0, and a `volume`, with
  `notes` of `at` seconds, a `note` number, a `velocity`, and a
  `length` in seconds; channel 9 is the drum kit. The engine starts a
  piece again as it ends, so a piece is written to loop; it is
  environmental noise for its area, not music.
