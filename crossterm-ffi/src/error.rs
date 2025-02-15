use libc;

#[repr(C)]
#[derive(Debug)]
#[allow(dead_code)]
pub enum crossterm_error {
    CROSSTERM_SUCCESS = 0,
    CROSSTERM_EUNDEF,
    CROSSTERM_EOTHER,
    CROSSTERM_EOS,
    CROSSTERM_EINVAL,
}
pub use crossterm_error::*;

#[no_mangle]
pub unsafe extern "C" fn crossterm_strerror(error: crossterm_error) -> *const libc::c_char {
    fn to_const_char_ptr(str: &'static str) -> *const libc::c_char {
        return str.as_ptr() as *const libc::c_char;
    }

    match error {
        CROSSTERM_SUCCESS => to_const_char_ptr("success"),
        CROSSTERM_EOS => libc::strerror(*libc::__errno_location()),
        CROSSTERM_EINVAL => libc::strerror(libc::EINVAL),
        // CROSSTERM_EOTHER => to_const_char_ptr("other"),
        _ => to_const_char_ptr("undefined error"),
    }
}

impl From<std::io::Error> for crossterm_error {
    fn from(err: std::io::Error) -> crossterm_error {
        if let Some(eos) = err.raw_os_error() {
            unsafe {
                *libc::__errno_location() = eos;
            }
            return CROSSTERM_EOS;
        } else if err.kind() == std::io::ErrorKind::Other {
            return CROSSTERM_EOTHER;
        } else {
            return CROSSTERM_EUNDEF;
        }
    }
}

impl std::fmt::Display for crossterm_error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::error::Error for crossterm_error {}
