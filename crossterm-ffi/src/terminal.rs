use crate::error::crossterm_error;
use crate::stream::crossterm_stream;

#[no_mangle]
pub unsafe extern "C" fn crossterm_is_raw_mode_enabled(is_enabled: *mut bool) -> libc::c_int {
    let ret = crossterm::terminal::is_raw_mode_enabled();
    match ret {
        Ok(enabled) => {
            (*is_enabled) = enabled;
            return 0;
        }
        Err(err) => {
            return -(crossterm_error::from(err) as i32);
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_enable_raw_mode() -> libc::c_int {
    let ret = crossterm::terminal::enable_raw_mode();
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_disable_raw_mode() -> libc::c_int {
    let ret = crossterm::terminal::disable_raw_mode();
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_enter_alternate_screen(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), crossterm::terminal::EnterAlternateScreen);
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_leave_alternate_screen(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), crossterm::terminal::LeaveAlternateScreen);
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_enable_line_wrap(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), crossterm::terminal::EnableLineWrap);
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_disable_line_wrap(stream: *mut crossterm_stream) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), crossterm::terminal::DisableLineWrap);
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_scroll_up(
    stream: *mut crossterm_stream,
    nlines: u16,
) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), crossterm::terminal::ScrollUp(nlines));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_scroll_down(
    stream: *mut crossterm_stream,
    nlines: u16,
) -> libc::c_int {
    let ret = crossterm::queue!((&mut *stream), crossterm::terminal::ScrollDown(nlines));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_clear_all(stream: *mut crossterm_stream) -> libc::c_int {
    use crossterm::terminal::Clear;
    use crossterm::terminal::ClearType;

    let ret = crossterm::queue!((&mut *stream), Clear(ClearType::All));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_clear_purge(stream: *mut crossterm_stream) -> libc::c_int {
    use crossterm::terminal::Clear;
    use crossterm::terminal::ClearType;

    let ret = crossterm::queue!((&mut *stream), Clear(ClearType::Purge));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_clear_from_cursor_up(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    use crossterm::terminal::Clear;
    use crossterm::terminal::ClearType;

    let ret = crossterm::queue!((&mut *stream), Clear(ClearType::FromCursorUp));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_clear_from_cursor_down(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    use crossterm::terminal::Clear;
    use crossterm::terminal::ClearType;

    let ret = crossterm::queue!((&mut *stream), Clear(ClearType::FromCursorDown));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_clear_current_line(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    use crossterm::terminal::Clear;
    use crossterm::terminal::ClearType;

    let ret = crossterm::queue!((&mut *stream), Clear(ClearType::CurrentLine));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_clear_until_new_line(
    stream: *mut crossterm_stream,
) -> libc::c_int {
    use crossterm::terminal::Clear;
    use crossterm::terminal::ClearType;

    let ret = crossterm::queue!((&mut *stream), Clear(ClearType::UntilNewLine));
    if let Err(err) = ret {
        -(crossterm_error::from(err) as i32)
    } else {
        0
    }
}

#[repr(C)]
pub struct crossterm_size {
    width: u16,
    height: u16,
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_get_size(size: *mut crossterm_size) -> libc::c_int {
    let ret = crossterm::terminal::size();
    match ret {
        Ok((width, height)) => {
            (*size).width = width;
            (*size).height = height;
            0
        }
        Err(err) => -(crossterm_error::from(err) as i32),
    }
}
