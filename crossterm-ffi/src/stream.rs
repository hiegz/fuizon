use libc;

use crossterm::style::Attribute;
use crossterm::style::SetAttribute;

use crate::color::crossterm_color;
use crate::error::crossterm_error;

use crossterm;

#[repr(C)]
pub struct crossterm_stream {
    context: *mut libc::c_void,
    write_fn: fn(buf: *const u8, buflen: libc::size_t, context: *mut libc::c_void) -> libc::c_long,
    flush_fn: fn(context: *mut libc::c_void) -> libc::c_int,
}

impl std::io::Write for crossterm_stream {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        let ret = (self.write_fn)(buf.as_ptr(), buf.len(), self.context);

        if ret >= 0 {
            Ok(ret as usize)
        } else {
            unsafe {
                assert!(-ret <= i32::max_value() as i64);
                *libc::__errno_location() = -ret as i32;
            }
            Err(std::io::Error::from(std::io::ErrorKind::Other))
        }
    }

    fn flush(&mut self) -> std::io::Result<()> {
        let ret = (self.flush_fn)(self.context);

        if ret == 0 {
            Ok(())
        } else {
            unsafe {
                *libc::__errno_location() = -ret as i32;
            }
            Err(std::io::Error::from(std::io::ErrorKind::Other))
        }
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_set_foreground_color(
    stream: *mut crossterm_stream,
    color: *const crossterm_color,
) -> libc::c_int {
    let ret = crossterm::queue!(
        (&mut *stream),
        crossterm::style::SetForegroundColor((&*color).into())
    );
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_set_background_color(
    stream: *mut crossterm_stream,
    color: *const crossterm_color,
) -> libc::c_int {
    let ret = crossterm::queue!(
        (&mut *stream),
        crossterm::style::SetBackgroundColor((&*color).into())
    );
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_set_bold_attribute(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::Bold));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_reset_bold_attribute(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::NormalIntensity));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_set_dim_attribute(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::Dim));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_reset_dim_attribute(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::NormalIntensity));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_set_underlined_attribute(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::Underlined));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_reset_underlined_attribute(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::NoUnderline));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_set_reverse_attribute(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::Reverse));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_reset_reverse_attribute(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::NoReverse));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_set_hidden_attribute(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::Hidden));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_reset_hidden_attribute(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::NoHidden));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe fn crossterm_stream_reset_attributes(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), SetAttribute(Attribute::Reset));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        return 0;
    }
}
