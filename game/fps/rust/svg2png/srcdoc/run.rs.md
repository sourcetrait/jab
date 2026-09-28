# run.rs

## fn run

The tool exists because the content is authored as SVG, sprites,
textures, and the compiler's plan views alike, while the kernel
decodes PNG alone: one rasteriser turns any of them into the 8-bit
PNG the engine reads, at the size the caller wants through the scale.

## fn render

System fonts are loaded so a plan view's labels render; without them
usvg drops text silently. The scale multiplies the SVG's own size,
rounded up, so a 64-unit sprite drawn at scale 4 lands at 256 pixels.
The pixmap is RGBA with a transparent ground, which is what a sprite
with a cutout needs and what a plan view paints over with its own
white rectangle.
