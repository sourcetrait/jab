# map/plan

The plan views: a storey of a map source drawn as an SVG, its sectors filled by
a colour keyed to the floor's height and named in the kernel's console font, its
walls and entities marked.

## font_path

The plan view's labels are drawn in the kernel's console font, the
glyph table the kernel assembles, so the renderer needs no font

## font-glyphs

The kernel's console font from its assembled glyph table: a record
from each printable character to its rows, 24 of them, each the
glyph's 12 columns in the high bits of a 16-bit value.

## label-svg

A label as SVG rects of the font's pixels, one a run of set columns
a row, centred on a point, a pixel a font pixel; a character the
font lacks draws as a space.

## plan-svg

The plan view of a storey: every sector of it filled by a colour
keyed to its floor height with its name at its centre in the
kernel's font, walls as lines (grey with a portal, black solid, red
tagged), entities as marks.
