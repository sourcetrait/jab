use crate::*;

/// The invocation, each subcommand's arguments.
const USAGE: &str = "footprint derivative <coord> <izb> <uzb> <z> | footprint blocks <levels.ppm> | footprint reference <map> <tree> <x> <y> <z> <yaw> <pitch> <roll> --iz-min <n> --owner <owner.ppm> [--export <api.out> <frame>] --levels <levels.ppm> [--export <api.out> <frame>]... [--rows <rows.nuon>] | footprint clamp-plan <map> <tree> <x> <y> <z> <yaw> <pitch> <roll> --owner <owner.ppm> --levels <levels.ppm> --surface <index> | footprint differ <a.ppm> <b.ppm>";

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
        Some("clamp-plan") => clamp_plan_command(&args[1..]),
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

/// A capture on the command line: its picture, and its export and frame.
struct Named {
    picture: PathBuf,
    export: Option<(PathBuf, u32)>,
}

/// The reference's and the plan's arguments, positionals and flags.
struct Invocation {
    map: PathBuf,
    tree: PathBuf,
    pose: [f64; 6],
    iz_min: Option<i64>,
    owner: Option<Named>,
    levels: Vec<Named>,
    rows: Option<PathBuf>,
    surface: Option<u32>,
}

/// The arguments read: eight positionals, then the flags.
fn invocation(args: &[String]) -> FootprintResult<Invocation> {
    let usage = || FootprintError::Usage(USAGE.to_string());
    if args.len() < 8 {
        return Err(usage());
    }
    let names = ["x", "y", "z", "yaw", "pitch", "roll"];
    let mut pose = [0.0; 6];
    for (k, name) in names.iter().enumerate() {
        pose[k] = number(&args[2 + k], name)?;
    }
    let mut found = Invocation { map: PathBuf::from(&args[0]), tree: PathBuf::from(&args[1]), pose, iz_min: None, owner: None, levels: Vec::new(), rows: None, surface: None };
    let mut owner_last = false;
    let mut it = args[8..].iter();
    while let Some(flag) = it.next() {
        let mut value = || it.next().ok_or_else(usage);
        match flag.as_str() {
            "--iz-min" => found.iz_min = Some(number(value()?, "--iz-min")?),
            "--owner" => {
                found.owner = Some(Named { picture: PathBuf::from(value()?), export: None });
                owner_last = true;
            }
            "--levels" => {
                found.levels.push(Named { picture: PathBuf::from(value()?), export: None });
                owner_last = false;
            }
            "--export" => {
                let api = PathBuf::from(value()?);
                let frame = number(value()?, "--export's frame")?;
                let named = if owner_last { found.owner.as_mut() } else { found.levels.last_mut() };
                named.ok_or_else(usage)?.export = Some((api, frame));
            }
            "--rows" => found.rows = Some(PathBuf::from(value()?)),
            "--surface" => found.surface = Some(number(value()?, "--surface")?),
            _ => return Err(usage()),
        }
    }
    Ok(found)
}

/// The snapshot of a capture's frame from its export, a LEVELS table held whole.
fn snapshot_for(named: &Named, height: usize, tabled: bool) -> FootprintResult<Option<Snapshot>> {
    let Some((api, frame)) = &named.export else {
        return Ok(None);
    };
    let bytes = fs::read(api).map_err(FootprintError::io(api))?;
    let held = snapshots(&bytes).map_err(|message| FootprintError::refused(api, message))?;
    snapshot_of(&held, *frame, height, tabled).map(Some).map_err(|message| FootprintError::refused(api, message))
}

/// A population's classes as NUON.
fn population_nuon(population: &Population) -> Nuon {
    let classes = [Class::Judged, Class::Sky, Class::Unknown, Class::Unread, Class::Actor, Class::Degenerate, Class::NoEnd, Class::Unpaired];
    record(vec![
        ("blocks", count(population.blocks)),
        ("classes", Nuon::Record(classes.iter().map(|c| (c.name().to_string(), count(population.count(*c)))).collect())),
        ("unresolved", count(population.unresolved())),
        ("sensitive", count(population.sensitive)),
        ("clamped", count(population.clamped)),
        ("actors", count(population.actors)),
    ])
}

/// A tally's counts as NUON, beside the capture's file and the snapshot it read.
fn tally_nuon(file: &Path, tally: &Tally, snapshot: Option<&Snapshot>) -> Nuon {
    record(vec![
        ("file", Nuon::Str(file.display().to_string())),
        ("blocks", count(tally.blocks)),
        ("judged", count(tally.judged)),
        ("agree", count(tally.agree)),
        ("sharper", count(tally.sharper)),
        ("coarser", count(tally.coarser)),
        ("secant_agree", count(tally.secant_agree)),
        ("secant_sharper", count(tally.secant_sharper)),
        ("secant_coarser", count(tally.secant_coarser)),
        ("levels", Nuon::List(tally.levels.iter().map(|&n| count(n)).collect())),
        ("snapshot", snapshot.map(snapshot_nuon).unwrap_or(Nuon::Null)),
    ])
}

/// A snapshot's frame and sizes as NUON.
fn snapshot_nuon(snapshot: &Snapshot) -> Nuon {
    record(vec![("frame", Nuon::Int(snapshot.frame as i64)), ("spans", count(snapshot.spans.len() as u64)), ("actors", count(snapshot.actors.len() as u64))])
}

/// A union block's fields as NUON.
fn row_nuon(row: &Row) -> Nuon {
    let maybe = |value: Option<u8>| value.map(|v| Nuon::Int(v as i64)).unwrap_or(Nuon::Null);
    record(vec![
        ("span", Nuon::Int(row.span as i64)),
        ("row", Nuon::Int(row.row as i64)),
        ("x0", Nuon::Int(row.x0 as i64)),
        ("class", Nuon::Str(row.class.name().to_string())),
        ("surface", row.surface.map(|s| Nuon::Int(s as i64)).unwrap_or(Nuon::Null)),
        ("depth", row.depth.map(Nuon::Float).unwrap_or(Nuon::Null)),
        ("clamped", Nuon::Bool(row.clamped)),
        ("footprint", Nuon::Float(row.footprint)),
        ("along", Nuon::Float(row.along)),
        ("down", Nuon::Float(row.down)),
        ("secant", Nuon::Float(row.secant)),
        ("length", Nuon::Float(row.length)),
        ("reference", Nuon::Int(row.reference as i64)),
        ("band", maybe(row.band)),
        ("secant_reference", Nuon::Int(row.secant_reference as i64)),
        ("secant_band", maybe(row.secant_band)),
        ("levels", Nuon::List(row.levels.iter().map(|level| maybe(*level)).collect())),
    ])
}

/// Each LEVELS capture's blocks held to the reference at the images' floor.
fn reference_command(args: &[String]) -> FootprintResult<Nuon> {
    let call = invocation(args)?;
    let usage = || FootprintError::Usage(USAGE.to_string());
    let iz_min = call.iz_min.ok_or_else(usage)?;
    let owner_named = call.owner.as_ref().ok_or_else(usage)?;
    if call.levels.is_empty() {
        return Err(usage());
    }
    let map = read_map(&call.map)?;
    let textures = textures(&map, &call.tree);
    let lumels = lumels(&map, &textures);
    let [x, y, z, yaw, pitch, roll] = call.pose;
    let camera = Camera::from_angles([x, y, z], yaw, pitch, roll);
    let owner = read_ppm(&owner_named.picture)?;
    let owner_snapshot = snapshot_for(owner_named, owner.height, false)?;
    let mut captures = Vec::new();
    let mut snapshots = Vec::new();
    for named in &call.levels {
        let image = read_ppm(&named.picture)?;
        let snapshot = snapshot_for(named, image.height, true)?;
        captures.push(Capture { image, spans: snapshot.as_ref().map(|s| s.spans.clone()) });
        snapshots.push(snapshot);
    }
    let actors = owner_snapshot.as_ref().map(|s| s.actors.clone()).unwrap_or_default();
    for (named, snapshot) in call.levels.iter().zip(&snapshots) {
        if let Some(s) = snapshot
            && owner_snapshot.is_some()
            && s.actors != actors
        {
            return Err(FootprintError::refused(&named.picture, format!("its frame {}'s actors differ from the OWNER capture's", s.frame)));
        }
    }
    let first = &call.levels[0].picture;
    let scene = Scene { map: &map, textures: &textures, lumels: &lumels, actors: &actors, camera: &camera, floor: depth_floor(iz_min) };
    let (population, tallies, rows) = compare(&scene, &owner, &captures).map_err(|message| FootprintError::refused(first, message))?;
    if let Some(out) = &call.rows {
        let table = Nuon::List(rows.iter().map(row_nuon).collect());
        fs::write(out, format!("{table}\n")).map_err(FootprintError::io(out))?;
    }
    let unread = textures.unread(&map).into_iter().map(|(name, why)| record(vec![("material", Nuon::Str(name)), ("why", Nuon::Str(why))])).collect();
    Ok(record(vec![
        ("camera", record(vec![("x", Nuon::Float(x)), ("y", Nuon::Float(y)), ("z", Nuon::Float(z)), ("yaw", Nuon::Float(yaw)), ("pitch", Nuon::Float(pitch)), ("roll", Nuon::Float(roll))])),
        ("iz_min", Nuon::Int(iz_min)),
        ("floor_depth", Nuon::Float(1.0 / depth_floor(iz_min))),
        ("rows", count(rows.len() as u64)),
        ("lumels", lumels_nuon(&lumels)),
        ("unread_materials", Nuon::List(unread)),
        ("owner", owner_snapshot.as_ref().map(snapshot_nuon).unwrap_or(Nuon::Null)),
        ("population", population_nuon(&population)),
        ("captures", Nuon::List(call.levels.iter().zip(&tallies).zip(&snapshots).map(|((named, tally), snapshot)| tally_nuon(&named.picture, tally, snapshot.as_ref())).collect())),
    ]))
}

/// The clamp's plan for a surface: its threshold and its witnesses.
fn clamp_plan_command(args: &[String]) -> FootprintResult<Nuon> {
    let call = invocation(args)?;
    let usage = || FootprintError::Usage(USAGE.to_string());
    let surface = call.surface.ok_or_else(usage)?;
    let owner_named = call.owner.as_ref().ok_or_else(usage)?;
    let [levels_named] = call.levels.as_slice() else {
        return Err(usage());
    };
    let map = read_map(&call.map)?;
    let textures = textures(&map, &call.tree);
    let lumels = lumels(&map, &textures);
    let [x, y, z, yaw, pitch, roll] = call.pose;
    let camera = Camera::from_angles([x, y, z], yaw, pitch, roll);
    let owner = read_ppm(&owner_named.picture)?;
    let capture = Capture { image: read_ppm(&levels_named.picture)?, spans: None };
    clamp_plan(&map, &textures, &lumels, &camera, &owner, &capture, surface).map_err(|message| FootprintError::refused(&levels_named.picture, message))
}

/// The bake's counts as the engine's load line gives them.
fn lumels_nuon(lumels: &Lumels) -> Nuon {
    record(vec![("maps", count(lumels.maps)), ("lumels", count(lumels.lumels)), ("unmapped", count(lumels.unmapped))])
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
