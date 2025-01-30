use std::ops::BitOrAssign;

use libc;

use crossterm;
use crossterm::event::Event;
use crossterm::event::KeyEvent;
use crossterm::event::KeyEventState;
use crossterm::event::KeyModifiers;

use crate::error::crossterm_error;

#[derive(Debug, PartialEq, Eq)]
pub struct crossterm_key_modifiers(pub u16);

#[rustfmt::skip]
mod unformatted {

use super::crossterm_key_modifiers;

pub const CROSSTERM_SHIFT_KEY_MODIFIER:     crossterm_key_modifiers = crossterm_key_modifiers(1 << 0);
pub const CROSSTERM_CONTROL_KEY_MODIFIER:   crossterm_key_modifiers = crossterm_key_modifiers(1 << 1);
pub const CROSSTERM_ALT_KEY_MODIFIER:       crossterm_key_modifiers = crossterm_key_modifiers(1 << 2);
pub const CROSSTERM_SUPER_KEY_MODIFIER:     crossterm_key_modifiers = crossterm_key_modifiers(1 << 3);
pub const CROSSTERM_HYPER_KEY_MODIFIER:     crossterm_key_modifiers = crossterm_key_modifiers(1 << 4);
pub const CROSSTERM_META_KEY_MODIFIER:      crossterm_key_modifiers = crossterm_key_modifiers(1 << 5);
pub const CROSSTERM_KEYPAD_KEY_MODIFIER:    crossterm_key_modifiers = crossterm_key_modifiers(1 << 6);
pub const CROSSTERM_CAPS_LOCK_KEY_MODIFIER: crossterm_key_modifiers = crossterm_key_modifiers(1 << 7);
pub const CROSSTERM_NUM_LOCK_KEY_MODIFIER:  crossterm_key_modifiers = crossterm_key_modifiers(1 << 8);

}
pub use unformatted::*;

impl std::ops::BitOr for crossterm_key_modifiers {
    type Output = crossterm_key_modifiers;

    fn bitor(self, rhs: crossterm_key_modifiers) -> crossterm_key_modifiers {
        return crossterm_key_modifiers(self.0 | rhs.0);
    }
}

impl BitOrAssign<crossterm_key_modifiers> for crossterm_key_modifiers {
    fn bitor_assign(&mut self, rhs: crossterm_key_modifiers) {
        return self.0 |= rhs.0;
    }
}

impl From<(KeyModifiers, KeyEventState)> for crossterm_key_modifiers {
    #[rustfmt::skip]
    fn from(value: (KeyModifiers, KeyEventState)) -> Self {
        let mut target: Self = Self(0);

        let m = value.0;
        let s = value.1;

        if m.contains(KeyModifiers::SHIFT)      { target |= CROSSTERM_SHIFT_KEY_MODIFIER;     }
        if m.contains(KeyModifiers::CONTROL)    { target |= CROSSTERM_CONTROL_KEY_MODIFIER;   }
        if m.contains(KeyModifiers::ALT)        { target |= CROSSTERM_ALT_KEY_MODIFIER;       }
        if m.contains(KeyModifiers::SUPER)      { target |= CROSSTERM_SUPER_KEY_MODIFIER;     }
        if m.contains(KeyModifiers::HYPER)      { target |= CROSSTERM_HYPER_KEY_MODIFIER;     }
        if m.contains(KeyModifiers::META)       { target |= CROSSTERM_META_KEY_MODIFIER;      }
        if s.contains(KeyEventState::KEYPAD)    { target |= CROSSTERM_KEYPAD_KEY_MODIFIER;    }
        if s.contains(KeyEventState::CAPS_LOCK) { target |= CROSSTERM_CAPS_LOCK_KEY_MODIFIER; }
        if s.contains(KeyEventState::NUM_LOCK)  { target |= CROSSTERM_NUM_LOCK_KEY_MODIFIER;  }

        return target;
    }
}

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum crossterm_event_type {
    CROSSTERM_KEY_EVENT,
    CROSSTERM_RESIZE_EVENT,
}
pub use crossterm_event_type::*;

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum crossterm_key_type {
    CROSSTERM_CHAR_KEY = 0,
    CROSSTERM_BACKSPACE_KEY,
    CROSSTERM_ENTER_KEY,
    CROSSTERM_LEFT_ARROW_KEY,
    CROSSTERM_RIGHT_ARROW_KEY,
    CROSSTERM_UP_ARROW_KEY,
    CROSSTERM_DOWN_ARROW_KEY,
    CROSSTERM_HOME_KEY,
    CROSSTERM_END_KEY,
    CROSSTERM_PAGE_UP_KEY,
    CROSSTERM_PAGE_DOWN_KEY,
    CROSSTERM_TAB_KEY,
    CROSSTERM_BACKTAB_KEY,
    CROSSTERM_DELETE_KEY,
    CROSSTERM_INSERT_KEY,
    CROSSTERM_ESCAPE_KEY,

    CROSSTERM_F1_KEY = 244,
    CROSSTERM_F2_KEY,
    CROSSTERM_F3_KEY,
    CROSSTERM_F4_KEY,
    CROSSTERM_F5_KEY,
    CROSSTERM_F6_KEY,
    CROSSTERM_F7_KEY,
    CROSSTERM_F8_KEY,
    CROSSTERM_F9_KEY,
    CROSSTERM_F10_KEY,
    CROSSTERM_F11_KEY,
    CROSSTERM_F12_KEY,
}
pub use crossterm_key_type::*;

#[repr(C)]
#[derive(Copy, Clone)]
#[rustfmt::skip]
pub struct crossterm_key_event {
    r#type:    crossterm_key_type,
    code:      u32,
    modifiers: u16,
}

impl From<KeyEvent> for crossterm_key_event {
    #[rustfmt::skip]
    fn from(event: KeyEvent) -> Self {
        use crossterm::event::KeyCode::*;

        #[allow(invalid_value)]
        let mut target: Self = unsafe { std::mem::MaybeUninit::uninit().assume_init() };
        target.modifiers = crossterm_key_modifiers::from((event.modifiers, event.state)).0;

        match event.code {
            Char(char)  => { target.r#type = CROSSTERM_CHAR_KEY; target.code = char as u32; }
            Backspace   =>   target.r#type = CROSSTERM_BACKSPACE_KEY,
            Enter       =>   target.r#type = CROSSTERM_ENTER_KEY,
            Left        =>   target.r#type = CROSSTERM_LEFT_ARROW_KEY,
            Right       =>   target.r#type = CROSSTERM_RIGHT_ARROW_KEY,
            Up          =>   target.r#type = CROSSTERM_UP_ARROW_KEY,
            Down        =>   target.r#type = CROSSTERM_DOWN_ARROW_KEY,
            Home        =>   target.r#type = CROSSTERM_HOME_KEY,
            End         =>   target.r#type = CROSSTERM_END_KEY,
            PageUp      =>   target.r#type = CROSSTERM_PAGE_UP_KEY,
            PageDown    =>   target.r#type = CROSSTERM_PAGE_DOWN_KEY,
            Tab         =>   target.r#type = CROSSTERM_TAB_KEY,
            BackTab     =>   target.r#type = CROSSTERM_BACKTAB_KEY,
            Delete      =>   target.r#type = CROSSTERM_DELETE_KEY,
            Insert      =>   target.r#type = CROSSTERM_INSERT_KEY,
            Esc         =>   target.r#type = CROSSTERM_ESCAPE_KEY,
            F(1)        =>   target.r#type = CROSSTERM_F1_KEY,
            F(2)        =>   target.r#type = CROSSTERM_F2_KEY,
            F(3)        =>   target.r#type = CROSSTERM_F3_KEY,
            F(4)        =>   target.r#type = CROSSTERM_F4_KEY,
            F(5)        =>   target.r#type = CROSSTERM_F5_KEY,
            F(6)        =>   target.r#type = CROSSTERM_F6_KEY,
            F(7)        =>   target.r#type = CROSSTERM_F7_KEY,
            F(8)        =>   target.r#type = CROSSTERM_F8_KEY,
            F(9)        =>   target.r#type = CROSSTERM_F9_KEY,
            F(10)       =>   target.r#type = CROSSTERM_F10_KEY,
            F(11)       =>   target.r#type = CROSSTERM_F11_KEY,
            F(12)       =>   target.r#type = CROSSTERM_F12_KEY,
            F(_)        =>   unreachable!("F what?"),
            Null        =>   unreachable!(),
            CapsLock    =>   unreachable!(),
            ScrollLock  =>   unreachable!(),
            NumLock     =>   unreachable!(),
            PrintScreen =>   unreachable!(),
            Pause       =>   unreachable!(),
            Menu        =>   unreachable!(),
            KeypadBegin =>   unreachable!(),
            Media(_)    =>   unreachable!(),
            Modifier(_) =>   unreachable!(),
        }

        return target;
    }
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct crossterm_resize_event {
    width: u16,
    height: u16,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct crossterm_event {
    r#type: crossterm_event_type,
    value: crossterm_event_,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub union crossterm_event_ {
    key: crossterm_key_event,
    resize: crossterm_resize_event,
}

impl From<Event> for crossterm_event {
    fn from(event: Event) -> Self {
        match event {
            crossterm::event::Event::Key(key_event) => crossterm_event {
                r#type: CROSSTERM_KEY_EVENT,
                value: crossterm_event_ {
                    key: key_event.into(),
                },
            },
            crossterm::event::Event::Resize(w, h) => crossterm_event {
                r#type: CROSSTERM_RESIZE_EVENT,
                value: crossterm_event_ {
                    resize: crossterm_resize_event {
                        width: w,
                        height: h,
                    },
                },
            },

            crossterm::event::Event::Paste(_) => unreachable!(),
            crossterm::event::Event::FocusGained => unreachable!(),
            crossterm::event::Event::FocusLost => unreachable!(),
            crossterm::event::Event::Mouse(_) => unreachable!(),
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_event_read(event: *mut crossterm_event) -> libc::c_int {
    let ret = crossterm::event::read();
    match ret {
        Ok(ev) => (*event) = crossterm_event::from(ev),
        Err(err) => return -(crossterm_error::from(err) as i32),
    }
    return 0;
}

#[no_mangle]
pub unsafe extern "C" fn crossterm_event_poll(is_available: *mut libc::c_int) -> libc::c_int {
    let ret = crossterm::event::poll(std::time::Duration::from_secs(0));
    match ret {
        Ok(available) => *is_available = available.into(),
        Err(err) => return -(crossterm_error::from(err) as i32),
    }
    return 0;
}

#[cfg(test)]
mod test {
    use super::*;
    use crossterm::event::KeyCode;
    use crossterm::event::KeyEventKind;

    #[test]
    fn shift_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_SHIFT_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::SHIFT, KeyEventState::NONE))
        );
    }

    #[test]
    fn control_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_CONTROL_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::CONTROL, KeyEventState::NONE))
        )
    }

    #[test]
    fn alt_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_ALT_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::ALT, KeyEventState::NONE))
        );
    }

    #[test]
    fn super_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_SUPER_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::SUPER, KeyEventState::NONE))
        );
    }

    #[test]
    fn hyper_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_HYPER_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::HYPER, KeyEventState::NONE))
        );
    }

    #[test]
    fn meta_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_META_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::META, KeyEventState::NONE))
        );
    }

    #[test]
    fn keypad_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_KEYPAD_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::NONE, KeyEventState::KEYPAD))
        );
    }

    #[test]
    fn caps_lock_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_CAPS_LOCK_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::NONE, KeyEventState::CAPS_LOCK))
        );
    }

    #[test]
    fn num_lock_key_modifier_cast() {
        assert_eq!(
            CROSSTERM_NUM_LOCK_KEY_MODIFIER,
            crossterm_key_modifiers::from((KeyModifiers::NONE, KeyEventState::NUM_LOCK))
        );
    }

    #[test]
    fn char_key_event_cast() {
        let event =
            crossterm_key_event::from(KeyEvent::new(KeyCode::Char(59 as char), KeyModifiers::NONE));

        assert_eq!(event.r#type, CROSSTERM_CHAR_KEY);
        assert_eq!(event.code, 59);
    }

    #[test]
    fn backspace_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Backspace, KeyModifiers::NONE)).r#type,
            CROSSTERM_BACKSPACE_KEY,
        );
    }

    #[test]
    fn enter_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Enter, KeyModifiers::NONE)).r#type,
            CROSSTERM_ENTER_KEY,
        );
    }

    #[test]
    fn left_arrow_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Left, KeyModifiers::NONE)).r#type,
            CROSSTERM_LEFT_ARROW_KEY,
        );
    }

    #[test]
    fn right_arrow_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Right, KeyModifiers::NONE)).r#type,
            CROSSTERM_RIGHT_ARROW_KEY,
        );
    }

    #[test]
    fn up_arrow_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Up, KeyModifiers::NONE)).r#type,
            CROSSTERM_UP_ARROW_KEY,
        );
    }

    #[test]
    fn down_arrow_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Down, KeyModifiers::NONE)).r#type,
            CROSSTERM_DOWN_ARROW_KEY,
        );
    }

    #[test]
    fn home_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Home, KeyModifiers::NONE)).r#type,
            CROSSTERM_HOME_KEY,
        );
    }

    #[test]
    fn end_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::End, KeyModifiers::NONE)).r#type,
            CROSSTERM_END_KEY,
        );
    }

    #[test]
    fn page_up_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::PageUp, KeyModifiers::NONE)).r#type,
            CROSSTERM_PAGE_UP_KEY,
        );
    }

    #[test]
    fn page_down_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::PageDown, KeyModifiers::NONE)).r#type,
            CROSSTERM_PAGE_DOWN_KEY,
        );
    }

    #[test]
    fn tab_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Tab, KeyModifiers::NONE)).r#type,
            CROSSTERM_TAB_KEY,
        );
    }

    #[test]
    fn backtab_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::BackTab, KeyModifiers::NONE)).r#type,
            CROSSTERM_BACKTAB_KEY,
        );
    }

    #[test]
    fn delete_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Delete, KeyModifiers::NONE)).r#type,
            CROSSTERM_DELETE_KEY,
        );
    }

    #[test]
    fn insert_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Insert, KeyModifiers::NONE)).r#type,
            CROSSTERM_INSERT_KEY,
        );
    }

    #[test]
    fn escape_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::Esc, KeyModifiers::NONE)).r#type,
            CROSSTERM_ESCAPE_KEY,
        );
    }

    #[test]
    fn f1_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(1), KeyModifiers::NONE)).r#type,
            CROSSTERM_F1_KEY,
        );
    }

    #[test]
    fn f2_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(2), KeyModifiers::NONE)).r#type,
            CROSSTERM_F2_KEY,
        );
    }

    #[test]
    fn f3_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(3), KeyModifiers::NONE)).r#type,
            CROSSTERM_F3_KEY,
        );
    }

    #[test]
    fn f4_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(4), KeyModifiers::NONE)).r#type,
            CROSSTERM_F4_KEY,
        );
    }

    #[test]
    fn f5_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(5), KeyModifiers::NONE)).r#type,
            CROSSTERM_F5_KEY,
        );
    }

    #[test]
    fn f6_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(6), KeyModifiers::NONE)).r#type,
            CROSSTERM_F6_KEY,
        );
    }

    #[test]
    fn f7_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(7), KeyModifiers::NONE)).r#type,
            CROSSTERM_F7_KEY,
        );
    }

    #[test]
    fn f8_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(8), KeyModifiers::NONE)).r#type,
            CROSSTERM_F8_KEY,
        );
    }

    #[test]
    fn f9_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(9), KeyModifiers::NONE)).r#type,
            CROSSTERM_F9_KEY,
        );
    }

    #[test]
    fn f10_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(10), KeyModifiers::NONE)).r#type,
            CROSSTERM_F10_KEY,
        );
    }

    #[test]
    fn f11_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(11), KeyModifiers::NONE)).r#type,
            CROSSTERM_F11_KEY,
        );
    }

    #[test]
    fn f12_key_event_cast() {
        assert_eq!(
            crossterm_key_event::from(KeyEvent::new(KeyCode::F(12), KeyModifiers::NONE)).r#type,
            CROSSTERM_F12_KEY,
        );
    }

    #[test]
    fn key_event_cast() {
        let event = crossterm_event::from(Event::Key(KeyEvent::new_with_kind_and_state(
            KeyCode::Char(59 as char),
            KeyModifiers::all(),
            KeyEventKind::Press,
            KeyEventState::all(),
        )));

        unsafe {
            assert_eq!(CROSSTERM_KEY_EVENT, event.r#type);
            assert_eq!(CROSSTERM_CHAR_KEY, event.value.key.r#type);
            assert_eq!(59, event.value.key.code);
            assert_eq!(
                (CROSSTERM_SHIFT_KEY_MODIFIER
                    | CROSSTERM_CONTROL_KEY_MODIFIER
                    | CROSSTERM_ALT_KEY_MODIFIER
                    | CROSSTERM_SUPER_KEY_MODIFIER
                    | CROSSTERM_HYPER_KEY_MODIFIER
                    | CROSSTERM_META_KEY_MODIFIER
                    | CROSSTERM_KEYPAD_KEY_MODIFIER
                    | CROSSTERM_CAPS_LOCK_KEY_MODIFIER
                    | CROSSTERM_NUM_LOCK_KEY_MODIFIER)
                    .0,
                event.value.key.modifiers
            );
        }
    }

    #[test]
    fn resize_event_cast() {
        let event = crossterm_event::from(Event::Resize(59, 15));

        unsafe {
            assert_eq!(CROSSTERM_RESIZE_EVENT, event.r#type);
            assert_eq!(59, event.value.resize.width);
            assert_eq!(15, event.value.resize.height);
        }
    }
}
