use ../../../../../../nu/mod/build
use ../../../../../../nu/mod/capture
use ../../../../../../nu/mod/launch
use ../../tree
use std/assert
use ../../tree [GROW_MAP]

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../../..

# The bytes Render One's map is cut to for the short-file case
const SHORT_BYTES = 2000

# When the load screen is captured, the map loading behind it
const TITLE_AT = 300ms

# The title's off-white ink, as hex
const TITLE_INK = "ebe6dc"

# A title character's cell in pixels, four times the console's
const TITLE_CELL = 48

# The title's rows in pixels from TITLE_Y
const TITLE_HEIGHT = 96

# The title's first row on the load screen
const TITLE_Y = 492

# The functions whose loops run a pixel or a sample, each held to a page
const HOT_FUNCTIONS = [
    span_fill span_light tile_build mixer_update
    row_crossings span_bound row_range poly_fill span_record
    packet_render band_render
]

# The traps each hot function may make within its page
const HOT_ECALLS = {
    span_fill: 0, span_light: 0, tile_build: 0, mixer_update: 2,
    row_crossings: 0, span_bound: 0, row_range: 0, poly_fill: 0, span_record: 0,
    packet_render: 0, band_render: 0,
}

# The hot functions' families, each held together on one page
const HOT_FAMILIES = [
    { name: "the span loop's", members: [row_crossings span_bound row_range poly_fill span_record] }
    { name: "the packet's render", members: [packet_render band_render span_fill] }
]

# The program's text only a debug build carries
const DEBUG_TEXT = [
    "fps: frame in "
    "fps: sectors "
    "fps: ambient "
    "fps: frames "
    "fps: frame "
    "fps: soundfont "
    "fps: soundfont refused "
    "fps: soundfont none, the chip voices play"
    "fps: lumel maps "
    "fps: sound "
    "fps: sounds "
    "fps: alpha "
    "fps: mips "
    "fps: tile pool: side "
    "fps: harts reserved "
    "fps: workers "
    "fps: worker refused on hart "
    "fps: workers stopped on harts"
    "fps: workers started on harts"
    "fps: harts claimed "
    "fps: harts claim refused "
    "fps: harts released "
    "fps: harts release refused "
    "fps: harts take refused under the floor: "
    "fps: harts take refused: claim "
    "fps: harts give refused: no claim standing"
    "fps: dispatch outside the grant: active"
    "fps: round lost bands\n"
    "fps: round unjoined\n"
    "fps: tile pool changed in flight\n"
    "fps: tile boundary before the round joined\n"
    "fps: held job never released\n"
]

# The program's text every build carries: exits and a failed load
const EXIT_TEXT = [
    "fps: "
    "fps: material "
    "fps: a load failed on material "
    "fps: no display\n"
    "fps: no sound\n"
    "fps: no disk of serial fps\n"
    "fps: the disk has no /map/name\n"
    "fps: harts short: "
    "fps: harts reserve refused "
    "fps: harts take interrupted on harts"
]

# Each hot function within a page and its listed traps, each family on a page
def hot-functions [image: path]: nothing -> nothing {
    let elf = ($image | path parse | update extension "elf" | path join)
    let hot = (capture hot $elf $HOT_FUNCTIONS)
    for h in $hot {
        assert $h.paged $"($h.name) within one page of code: ($h.start) to ($h.end)"
        assert equal $h.ecalls ($HOT_ECALLS | get $h.name) $"($h.name) traps inside its page"
    }
    for f in $HOT_FAMILIES {
        let family = ($hot | where {|h| $h.name in $f.members })
        assert equal ($family | length) ($f.members | length) $"every member of ($f.name) family among the hot functions"
        let lowest = ($family | get start | math min)
        let highest = (($family | get end | math max) - 1)
        assert equal ($lowest // 4096) ($highest // 4096) $"($f.name) family within one page of code together: ($lowest) to ($highest)"
    }
}

# The release image built and scanned: no debug text, only exits' strings
def release-strings [image: path]: nothing -> nothing {
    let here = ($WORKSPACE | path join "kit" "fierce")
    let tool = ($here | path join ".." ".." "nu" "bin" "do.nu" | path expand)
    let built = (^nu $tool build $here | complete)
    assert equal $built.exit_code 0 $"the release image built: ($built.stderr)"
    let release = (build program-out $here "release" | path join "fierce.jab")
    assert ($release | path exists) $"the release image at ($release)"
    let debug_found = (capture strings $image "fps: ")
    for text in $DEBUG_TEXT {
        assert ($debug_found | any {|s| $s | str starts-with $text }) $"the debug build carries '($text)'"
    }
    for text in $EXIT_TEXT {
        assert ($text in $debug_found) $"the debug build carries the exit text '($text)'"
    }
    let release_found = (capture strings $release "fps: ")
    for text in $DEBUG_TEXT {
        assert (not ($release_found | any {|s| $s | str starts-with $text })) $"the release build carries no '($text)'"
    }
    assert equal ($release_found | sort) ($EXIT_TEXT | sort) $"every fps: string in the release build is an exit's: ($release_found)"
}

# A load-screen title held: inked centred, its text's width, on its rows
def title-holds [kernel: path, image: path, out: path, set: string, name: string, tree: path, text: string]: nothing -> record<count: int, left: int, top: int, right: int, bottom: int> {
    let run = (launch --kernel $kernel --image $image --out ($out | path join $"title_($name)") --set $set --sound --disk (tree romfs $tree ($out | path join $"title_($name).romfs")) --serial "fps" --capture $TITLE_AT --seconds 5)
    assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($name)'s load screen"
    assert ($run.screen != "") $"a screen was taken on ($name)'s load screen"
    let ink = (capture ink (capture screen $run.screen) $TITLE_INK)
    let cells = ($text | str length)
    let half = ($cells * $TITLE_CELL // 2)
    let width = ($ink.right - $ink.left + 1)
    assert ($ink.count > 0) $"($name)'s load screen draws ($text): ($ink)"
    assert ($ink.left >= (960 - $half) and $ink.right < (960 + $half)) $"($text) centred within its ($cells) cells on ($name)'s load screen: ($ink)"
    assert ($width > (($cells - 1) * $TITLE_CELL)) $"the ink as wide as ($text)'s ($cells) cells on ($name)'s load screen, not a shorter text's: ($width) px, ($ink)"
    assert ($ink.top >= $TITLE_Y and $ink.bottom < ($TITLE_Y + $TITLE_HEIGHT)) $"($text) on the title's rows on ($name)'s load screen: ($ink)"
    $ink
}

# Hot functions each within a page, and a release build bearing no debug text
export def release [context: record, records: record]: nothing -> record {
    let image = $context.image
    hot-functions $image
    release-strings $image
    {}
}

# The load screen: Render One's title inked, the growth map's name in its place
export def title [context: record, records: record]: nothing -> record {
    let game = $context.game
    let out = $context.out
    let render_1_source = $context.render_1.source
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let render_1_tree = $context.render_1.tree
    let grow_tree = (tree grow-tree $game ($out | path join "grow"))
    let titles = [
        { text: $render_1_source.title, ink: (title-holds $kernel $image $out $set "render_1" $render_1_tree $render_1_source.title) }
        { text: $GROW_MAP, ink: (title-holds $kernel $image $out $set "grow" $grow_tree $GROW_MAP) }
    ]
    {grow_tree: $grow_tree, titles: $titles}
}

# First frames drawn with no fault on hart 0 or a worker, the pool unchanged
export def first-frames [context: record, records: record]: nothing -> record {
    let plain_run = $records."render_one plain".plain_run
    let plain_faulted = (($plain_run.serial | str contains "jab: program fault") or ($plain_run.serial | str contains "jab: worker fault"))
    assert (not $plain_faulted) $"no program or worker fault drawing the plain run's frames: ($plain_run.serial | lines | where {|l| $l starts-with 'jab: ' })"
    assert (not ($plain_run.serial | str contains "fps: tile pool changed in flight")) $"the tile pool held unchanged through every frame's renders on the plain run: ($plain_run.serial | lines | last 2)"
    assert ($plain_run.screen != "") "a screen was taken on the plain run"
    {}
}

# A map of wrong magic exits 6, Render One's map cut short exits 7
export def broken [context: record, records: record]: nothing -> record {
    let out = $context.out
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let render_1_tree = $context.render_1.tree
    let bad = (tree broken ($out | path join "bad_tree") "bad" ([("XXXX" | into binary), (0..<60 | each {|i| 0x[00] } | bytes collect)] | bytes collect))
    let bad_run = (launch --kernel $kernel --image $image --out ($out | path join "bad") --set $set --sound --disk (tree romfs $bad ($out | path join "bad.romfs")) --serial "fps" --seconds 8)
    assert equal $bad_run.status 6 $"a wrong magic exits 6: ($bad_run.status), ($bad_run.serial)"
    assert ("fps: /map/bad.jabfps.map is not a Jab FPS map" in ($bad_run.serial | lines)) $"and says so: ($bad_run.serial)"

    let whole = (open --raw ($render_1_tree | path join "map" "render_1.jabfps.map") | into binary)
    assert (($whole | bytes length) > $SHORT_BYTES) $"Render One's map runs past ($SHORT_BYTES) bytes: ($whole | bytes length)"
    let short = (tree broken ($out | path join "short_tree") "short" ($whole | bytes at 0..<$SHORT_BYTES))
    let short_run = (launch --kernel $kernel --image $image --out ($out | path join "short") --set $set --sound --disk (tree romfs $short ($out | path join "short.romfs")) --serial "fps" --seconds 8)
    assert equal $short_run.status 7 $"a short file exits 7: ($short_run.status), ($short_run.serial)"
    assert ($"fps: /map/short.jabfps.map ends at ($SHORT_BYTES) bytes before its structures do" in ($short_run.serial | lines)) $"and says so: ($short_run.serial)"
    {bad_run: $bad_run, short_run: $short_run}
}
