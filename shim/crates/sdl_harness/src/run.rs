//! Calls SDL_GL_MakeCurrent from a named function of its own, out of line.

use crate::*;

unsafe extern "C" {
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
}

/// glibc's `RTLD_DEFAULT`: the global scope, a preloaded library first.
const RTLD_DEFAULT: *mut c_void = std::ptr::null_mut();

type MakeCurrent = unsafe extern "C" fn(*mut c_void, *mut c_void) -> c_int;

/// Calls make_current once through the global scope and prints its answer.
pub fn run() -> ExitCode {
    let found = unsafe { dlsym(RTLD_DEFAULT, c"SDL_GL_MakeCurrent".as_ptr()) };
    if found.is_null() {
        eprintln!("jabshim_sdl_harness: no SDL_GL_MakeCurrent in the global scope");
        return ExitCode::from(2);
    }
    let function: MakeCurrent = unsafe { std::mem::transmute(found) };
    println!("make_current {}", harness_make_current(function));
    ExitCode::SUCCESS
}

/// The named caller the shim must resolve, its answer used after the call.
#[inline(never)]
#[unsafe(no_mangle)]
pub(crate) extern "C" fn harness_make_current(function: MakeCurrent) -> c_int {
    let answer = unsafe { function(std::ptr::null_mut(), std::ptr::null_mut()) };
    std::hint::black_box(answer)
}
