use crate::*;

/// One SVG rendered to an 8-bit RGBA PNG at a scale, 1 by default.
pub fn run() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match render(&args) {
        Ok((width, height)) => {
            println!("svg2png: {} -> {} {width}x{height}", args[0], args[1]);
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("svg2png: {error}");
            ExitCode::FAILURE
        }
    }
}

/// The input, the output, and the scale from the arguments; the size written.
fn render(args: &[String]) -> Svg2PngResult<(u32, u32)> {
    let (source, target, scale) = match args {
        [source, target] => (Path::new(source), Path::new(target), 1.0),
        [source, target, scale] => (Path::new(source), Path::new(target), scale.parse::<f32>().map_err(|_| Svg2PngError::Usage)?),
        _ => return Err(Svg2PngError::Usage),
    };
    let data = fs::read(source).map_err(|error| Svg2PngError::Io { path: source.to_path_buf(), source: error })?;
    let mut options = resvg::usvg::Options::default();
    options.fontdb_mut().load_system_fonts();
    let tree = resvg::usvg::Tree::from_data(&data, &options).map_err(|error| Svg2PngError::Svg { path: source.to_path_buf(), source: error })?;
    let size = tree.size();
    let width = (size.width() * scale).ceil();
    let height = (size.height() * scale).ceil();
    let mut pixmap = resvg::tiny_skia::Pixmap::new(width as u32, height as u32).ok_or(Svg2PngError::Size { width, height })?;
    resvg::render(&tree, resvg::tiny_skia::Transform::from_scale(scale, scale), &mut pixmap.as_mut());
    pixmap.save_png(target).map_err(|error| Svg2PngError::Png { path: target.to_path_buf(), message: error.to_string() })?;
    Ok((width as u32, height as u32))
}
