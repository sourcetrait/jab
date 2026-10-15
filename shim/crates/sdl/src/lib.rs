//! Logs the SDL calls QEMU's window makes, each make_current with its callers.
#![allow(clippy::missing_safety_doc)]

use std::ffi::{CStr, c_char, c_int, c_void};
use std::fs::{File, Metadata};
use std::io::Write;
use std::os::unix::fs::MetadataExt;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

#[repr(C)]
struct DlInfo {
    dli_fname: *const c_char,
    dli_fbase: *mut c_void,
    dli_sname: *const c_char,
    dli_saddr: *mut c_void,
}

/// The leading fields of glibc's `struct link_map`, which its ABI fixes.
#[repr(C)]
struct LinkMap {
    l_addr: usize,
    l_name: *const c_char,
    l_ld: *mut c_void,
    l_next: *mut LinkMap,
    l_prev: *mut LinkMap,
}

unsafe extern "C" {
    fn dlopen(filename: *const c_char, flags: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
    fn dladdr1(address: *const c_void, info: *mut DlInfo, extra: *mut *mut c_void, flags: c_int) -> c_int;
    fn dlinfo(handle: *mut c_void, request: c_int, info: *mut c_void) -> c_int;
    fn backtrace(buffer: *mut *mut c_void, size: c_int) -> c_int;
}

const RTLD_LAZY: c_int = 1;
const RTLD_DL_LINKMAP: c_int = 2;
const RTLD_DI_LINKMAP: c_int = 2;
/// The most frames one make_current records, the shim's own included.
const FRAMES: usize = 10;

/// The open log and the link map each object-table index names.
struct Log {
    file: File,
    named: Vec<usize>,
}

static LOG: Mutex<Option<Log>> = Mutex::new(None);

/// Appends one timestamped line.
fn line(log: &mut Log, text: &str) {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default();
    let _ = writeln!(log.file, "{}.{:06} {}", now.as_secs(), now.subsec_micros(), text);
}

/// An object-table line: index, inode, size, mtime in ns, then the path.
fn object_line(log: &mut Log, index: usize, path: &str, meta: Option<Metadata>) {
    let fields = match meta {
        Some(m) => format!("{} {} {}", m.ino(), m.len(), m.mtime() as i128 * 1_000_000_000 + m.mtime_nsec() as i128),
        None => "- - -".to_string(),
    };
    line(log, &format!("object {index} {fields} {path}"));
}

/// A loaded object's path, canonical where the file exists, and its metadata.
fn object_of(map: *mut LinkMap) -> (String, Option<Metadata>) {
    let name = unsafe { (*map).l_name };
    let named = if name.is_null() { String::new() } else { unsafe { CStr::from_ptr(name) }.to_string_lossy().into_owned() };
    match std::fs::canonicalize(&named) {
        Ok(path) => {
            let meta = std::fs::metadata(&path).ok();
            (path.to_string_lossy().into_owned(), meta)
        }
        Err(_) => (named, None),
    }
}

/// The link map of the object an address lies in, or null for none.
fn map_of(address: *const c_void) -> *mut LinkMap {
    let mut info = DlInfo {
        dli_fname: std::ptr::null(),
        dli_fbase: std::ptr::null_mut(),
        dli_sname: std::ptr::null(),
        dli_saddr: std::ptr::null_mut(),
    };
    let mut extra: *mut c_void = std::ptr::null_mut();
    if unsafe { dladdr1(address, &mut info, &mut extra, RTLD_DL_LINKMAP) } == 0 {
        return std::ptr::null_mut();
    }
    extra as *mut LinkMap
}

/// The main program's link map, the head of the loader's chain.
fn main_map() -> *mut LinkMap {
    let handle = unsafe { dlopen(std::ptr::null(), RTLD_LAZY) };
    if handle.is_null() {
        return std::ptr::null_mut();
    }
    let mut map: *mut LinkMap = std::ptr::null_mut();
    if unsafe { dlinfo(handle, RTLD_DI_LINKMAP, &mut map as *mut *mut LinkMap as *mut c_void) } != 0 {
        return std::ptr::null_mut();
    }
    map
}

/// Names a newly seen object at the next index, its line ahead of its use.
fn name(log: &mut Log, map: *mut LinkMap) -> usize {
    let index = log.named.len();
    let (path, meta) = if map.is_null() { (String::new(), None) } else { object_of(map) };
    object_line(log, index, &path, meta);
    log.named.push(map as usize);
    index
}

/// The object table: the executable, this library, then every object loaded.
fn table(log: &mut Log) {
    let main = main_map();
    let exe = std::fs::read_link("/proc/self/exe").map(|p| p.to_string_lossy().into_owned()).unwrap_or_default();
    let exe_meta = std::fs::metadata("/proc/self/exe").ok();
    object_line(log, 0, &exe, exe_meta);
    log.named.push(main as usize);
    let own = map_of(table as *const c_void);
    name(log, own);
    let mut map = main;
    while !map.is_null() {
        if map != main && map != own {
            name(log, map);
        }
        map = unsafe { (*map).l_next };
    }
}

/// The log, opened with its object table on first use; none when unset.
fn opened(slot: &mut Option<Log>) -> Option<&mut Log> {
    if slot.is_none() {
        let path = std::env::var_os("SDL_SHIM_LOG")?;
        let file = std::fs::OpenOptions::new().create(true).append(true).open(path).ok()?;
        let mut log = Log { file, named: Vec::new() };
        table(&mut log);
        *slot = Some(log);
    }
    slot.as_mut()
}

/// Every frame from the caller of backtrace up, as index and link address.
fn frames(log: &mut Log) -> String {
    let mut addresses: [*mut c_void; FRAMES] = [std::ptr::null_mut(); FRAMES];
    let count = unsafe { backtrace(addresses.as_mut_ptr(), FRAMES as c_int) }.max(0) as usize;
    let mut out = String::new();
    for &address in addresses.iter().take(count) {
        let map = map_of(address);
        if map.is_null() {
            out.push_str(&format!(" ?+{:x}", address as usize));
            continue;
        }
        let index = match log.named.iter().position(|&m| m == map as usize) {
            Some(i) => i,
            None => name(log, map),
        };
        let link = (address as usize).wrapping_sub(unsafe { (*map).l_addr });
        out.push_str(&format!(" {index}+{link:x}"));
    }
    out
}

/// Logs an event, a make_current's with its frames; nothing when unlogged.
fn record(event: &str, with_frames: bool) {
    let mut guard = match LOG.lock() {
        Ok(guard) => guard,
        Err(_) => return,
    };
    let Some(log) = opened(&mut guard) else { return };
    let text = if with_frames { format!("{event}{}", frames(log)) } else { event.to_string() };
    line(log, &text);
}

/// The real SDL function of that name, from libSDL2.
fn real(symbol: &CStr) -> *mut c_void {
    let lib = unsafe { dlopen(c"libSDL2-2.0.so.0".as_ptr(), RTLD_LAZY) };
    if lib.is_null() {
        record("libSDL2 not found", false);
        std::process::abort();
    }
    let function = unsafe { dlsym(lib, symbol.as_ptr()) };
    if function.is_null() {
        record("symbol not found", false);
        std::process::abort();
    }
    function
}

type MakeCurrent = unsafe extern "C" fn(*mut c_void, *mut c_void) -> c_int;
type Swap = unsafe extern "C" fn(*mut c_void);
type WindowSize = unsafe extern "C" fn(*mut c_void, *mut c_int, *mut c_int);
type Poll = unsafe extern "C" fn(*mut c_void) -> c_int;

#[unsafe(no_mangle)]
pub unsafe extern "C" fn SDL_GL_MakeCurrent(window: *mut c_void, context: *mut c_void) -> c_int {
    record("make_current", true);
    let function: MakeCurrent = unsafe { std::mem::transmute(real(c"SDL_GL_MakeCurrent")) };
    unsafe { function(window, context) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn SDL_GL_SwapWindow(window: *mut c_void) {
    record("swap", false);
    let function: Swap = unsafe { std::mem::transmute(real(c"SDL_GL_SwapWindow")) };
    unsafe { function(window) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn SDL_GetWindowSize(window: *mut c_void, width: *mut c_int, height: *mut c_int) {
    record("size", false);
    let function: WindowSize = unsafe { std::mem::transmute(real(c"SDL_GetWindowSize")) };
    unsafe { function(window, width, height) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn SDL_PollEvent(event: *mut c_void) -> c_int {
    record("poll", false);
    let function: Poll = unsafe { std::mem::transmute(real(c"SDL_PollEvent")) };
    unsafe { function(event) }
}
