use crate::*;

/// The invocation, each subcommand's arguments.
const USAGE: &str = "footprint derivative <coord> <izb> <uzb> <z> | footprint blocks <levels.ppm> | footprint reference <map> <tree> <x> <y> <z> <yaw> <pitch> <roll> <owner.ppm> <levels.ppm>... [--rows <rows.nuon>] | footprint differ <a.ppm> <b.ppm>";

/// The subcommand named, its answer printed as NUON.
pub fn run() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match dispatch(&args) {
        Ok(answer) => {
            println!("{answer}");
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("footprint: {error}");
            ExitCode::FAILURE
        }
    }
}

/// The subcommand's answer.
fn dispatch(args: &[String]) -> FootprintResult<Nuon> {
    match args.first().map(String::as_str) {
        Some("derivative") => derivative_command(&args[1..]),
        Some("blocks") => blocks_command(&args[1..]),
        Some("reference") => reference_command(&args[1..]),
        Some("differ") => differ_command(&args[1..]),
        _ => Err(FootprintError::Usage(USAGE.to_string())),
    }
}

/// A number argument, named in the refusal.
fn number<T: FromStr>(text: &str, what: &str) -> FootprintResult<T> {
    text.parse::<T>().map_err(|_| FootprintError::Usage(format!("{what} is not a number: {text}")))
}

/// The exact row derivative of one case.
fn derivative_command(args: &[String]) -> FootprintResult<Nuon> {
    let [coord, izb, uzb, z] = args else {
        return Err(FootprintError::Usage(USAGE.to_string()));
    };
    Ok(derivative_nuon(number(coord, "coord")?, number(izb, "izb")?, number(uzb, "uzb")?, number(z, "z")?))
}

/// A block's fields as NUON.
fn block_nuon(block: &Block) -> Nuon {
    record(vec![
        ("span", Nuon::Int(block.span as i64)),
        ("row", Nuon::Int(block.row as i64)),
        ("x0", Nuon::Int(block.x0 as i64)),
        ("level", Nuon::Int(block.level as i64)),
        ("pixels", Nuon::Int(block.pixels as i64)),
        ("end", Nuon::Int(block.end as i64)),
    ])
}

/// A LEVELS capture's blocks.
fn blocks_command(args: &[String]) -> FootprintResult<Nuon> {
    let [path] = args else {
        return Err(FootprintError::Usage(USAGE.to_string()));
    };
    let path = Path::new(path);
    let image = read_ppm(path)?;
    let found = blocks(&image).map_err(|message| FootprintError::refused(path, message))?;
    Ok(record(vec![
        ("width", Nuon::Int(image.width as i64)),
        ("height", Nuon::Int(image.height as i64)),
        ("blocks", Nuon::List(found.iter().map(block_nuon).collect())),
    ]))
}

/// A tally's counts as NUON, beside the capture's file.
fn tally_nuon(file: &str, tally: &Tally) -> Nuon {
    record(vec![
        ("file", Nuon::Str(file.to_string())),
        ("blocks", count(tally.blocks)),
        ("judged", count(tally.judged)),
        ("sky", count(tally.sky)),
        ("actors", count(tally.actors)),
        ("unknown", count(tally.unknown)),
        ("unread", count(tally.unread)),
        ("clamped", count(tally.clamped)),
        ("degenerate", count(tally.degenerate)),
        ("sensitive", count(tally.sensitive)),
        ("agree", count(tally.agree)),
        ("sharper", count(tally.sharper)),
        ("coarser", count(tally.coarser)),
        ("secant_agree", count(tally.secant_agree)),
        ("secant_sharper", count(tally.secant_sharper)),
        ("secant_coarser", count(tally.secant_coarser)),
        ("levels", Nuon::List(tally.levels.iter().map(|&n| count(n)).collect())),
    ])
}

/// A judged block's fields as NUON.
fn row_nuon(row: &Row) -> Nuon {
    record(vec![
        ("span", Nuon::Int(row.span as i64)),
        ("row", Nuon::Int(row.row as i64)),
        ("x0", Nuon::Int(row.x0 as i64)),
        ("surface", Nuon::Int(row.surface as i64)),
        ("footprint", Nuon::Float(row.footprint)),
        ("along", Nuon::Float(row.along)),
        ("down", Nuon::Float(row.down)),
        ("secant", Nuon::Float(row.secant)),
        ("reference", Nuon::Int(row.reference as i64)),
        ("band", row.band.map(|m| Nuon::Int(m as i64)).unwrap_or(Nuon::Null)),
        ("secant_reference", Nuon::Int(row.secant_reference as i64)),
        ("secant_band", row.secant_band.map(|m| Nuon::Int(m as i64)).unwrap_or(Nuon::Null)),
        ("levels", Nuon::List(row.levels.iter().map(|level| level.map(|l| Nuon::Int(l as i64)).unwrap_or(Nuon::Null)).collect())),
    ])
}

/// Each LEVELS capture's blocks held to the reference, and the rows with --rows.
fn reference_command(args: &[String]) -> FootprintResult<Nuon> {
    let mut positional = Vec::new();
    let mut rows_out = None;
    let mut it = args.iter();
    while let Some(arg) = it.next() {
        if arg == "--rows" {
            rows_out = Some(PathBuf::from(it.next().ok_or_else(|| FootprintError::Usage(USAGE.to_string()))?));
        } else {
            positional.push(arg.as_str());
        }
    }
    if positional.len() < 10 {
        return Err(FootprintError::Usage(USAGE.to_string()));
    }
    let map_path = Path::new(positional[0]);
    let tree = Path::new(positional[1]);
    let eye = [number::<f64>(positional[2], "x")?, number::<f64>(positional[3], "y")?, number::<f64>(positional[4], "z")?];
    let (yaw, pitch, roll) = (number::<f64>(positional[5], "yaw")?, number::<f64>(positional[6], "pitch")?, number::<f64>(positional[7], "roll")?);
    let owner_path = Path::new(positional[8]);
    let map = read_map(map_path)?;
    let sizes = texture_sizes(&map, tree);
    let camera = Camera::from_angles(eye, yaw, pitch, roll);
    let owner = read_ppm(owner_path)?;
    let files = &positional[9..];
    let captures = files.iter().map(|file| read_ppm(Path::new(file))).collect::<FootprintResult<Vec<_>>>()?;
    let (tallies, rows) = compare(&map, &sizes, &camera, &owner, &captures).map_err(|message| FootprintError::refused(Path::new(files[0]), message))?;
    if let Some(out) = rows_out {
        let table = Nuon::List(rows.iter().map(row_nuon).collect());
        fs::write(&out, format!("{table}\n")).map_err(FootprintError::io(&out))?;
    }
    let unread = map.materials.iter().zip(&sizes).filter_map(|(name, size)| size.as_ref().err().map(|why| record(vec![("material", Nuon::Str(name.clone())), ("why", Nuon::Str(why.clone()))]))).collect();
    Ok(record(vec![
        ("camera", record(vec![("x", Nuon::Float(eye[0])), ("y", Nuon::Float(eye[1])), ("z", Nuon::Float(eye[2])), ("yaw", Nuon::Float(yaw)), ("pitch", Nuon::Float(pitch)), ("roll", Nuon::Float(roll))])),
        ("rows", count(rows.len() as u64)),
        ("unread_materials", Nuon::List(unread)),
        ("captures", Nuon::List(files.iter().zip(&tallies).map(|(file, tally)| tally_nuon(file, tally)).collect())),
    ]))
}

/// A region's fields as NUON.
fn region_nuon(region: &Region) -> Nuon {
    record(vec![
        ("x0", Nuon::Int(region.x0 as i64)),
        ("y0", Nuon::Int(region.y0 as i64)),
        ("x1", Nuon::Int(region.x1 as i64)),
        ("y1", Nuon::Int(region.y1 as i64)),
        ("pixels", count(region.pixels)),
        ("largest", Nuon::Int(region.largest as i64)),
    ])
}

/// Two captures' differing pixels by region, the stamp's cells skipped.
fn differ_command(args: &[String]) -> FootprintResult<Nuon> {
    let [a_path, b_path] = args else {
        return Err(FootprintError::Usage(USAGE.to_string()));
    };
    let (a_path, b_path) = (Path::new(a_path), Path::new(b_path));
    let (a, b) = (read_ppm(a_path)?, read_ppm(b_path)?);
    let regions = differ(&a, &b).map_err(|message| FootprintError::refused(b_path, message))?;
    Ok(record(vec![
        ("width", Nuon::Int(a.width as i64)),
        ("height", Nuon::Int(a.height as i64)),
        ("pixels", count(regions.iter().map(|r| r.pixels).sum())),
        ("regions", Nuon::List(regions.iter().map(region_nuon).collect())),
    ]))
}
