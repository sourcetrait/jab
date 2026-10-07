# error.rs

## enum Svg2PngError

Five variants for the five things that stop the tool: a wrong
invocation, a file the host would not give up, an SVG the parser
refused, a size no pixmap can hold, and a PNG the encoder refused. The
path rides with the source so a failure among many files names the
one. Written out by hand; the lowkick workspaces carry no derive
crate for errors, and one enum does not earn the dependency.
