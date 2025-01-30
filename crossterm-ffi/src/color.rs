use crossterm;
use crossterm::style::Color;

#[repr(C)]
#[allow(dead_code)]
pub enum crossterm_color_type {
    CROSSTERM_RESET_COLOR,

    CROSSTERM_BLACK_COLOR,
    CROSSTERM_WHITE_COLOR,

    CROSSTERM_RED_COLOR,
    CROSSTERM_GREEN_COLOR,
    CROSSTERM_BLUE_COLOR,
    CROSSTERM_YELLOW_COLOR,
    CROSSTERM_MAGENTA_COLOR,
    CROSSTERM_CYAN_COLOR,
    CROSSTERM_GREY_COLOR,

    CROSSTERM_DARK_RED_COLOR,
    CROSSTERM_DARK_GREEN_COLOR,
    CROSSTERM_DARK_BLUE_COLOR,
    CROSSTERM_DARK_YELLOW_COLOR,
    CROSSTERM_DARK_MAGENTA_COLOR,
    CROSSTERM_DARK_CYAN_COLOR,
    CROSSTERM_DARK_GREY_COLOR,

    CROSSTERM_ANSI_COLOR,
    CROSSTERM_RGB_COLOR,
}
pub use crossterm_color_type::*;

#[repr(C)]
#[derive(Copy, Clone)]
pub struct crossterm_ansi_color {
    pub value: u8,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct crossterm_rgb_color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

#[repr(C)]
pub union crossterm_color_value {
    pub ansi: crossterm_ansi_color,
    pub rgb: crossterm_rgb_color,
}

#[repr(C)]
pub struct crossterm_color {
    pub t: crossterm_color_type,
    pub v: crossterm_color_value,
}

impl Into<Color> for &crossterm_color {
    fn into(self) -> Color {
        unsafe {
            match self.t {
                CROSSTERM_RESET_COLOR => Color::Reset,
                CROSSTERM_BLACK_COLOR => Color::Black,
                CROSSTERM_WHITE_COLOR => Color::White,
                CROSSTERM_RED_COLOR => Color::Red,
                CROSSTERM_GREEN_COLOR => Color::Green,
                CROSSTERM_BLUE_COLOR => Color::Blue,
                CROSSTERM_YELLOW_COLOR => Color::Yellow,
                CROSSTERM_MAGENTA_COLOR => Color::Magenta,
                CROSSTERM_CYAN_COLOR => Color::Cyan,
                CROSSTERM_GREY_COLOR => Color::Grey,
                CROSSTERM_DARK_RED_COLOR => Color::DarkRed,
                CROSSTERM_DARK_GREEN_COLOR => Color::DarkGreen,
                CROSSTERM_DARK_BLUE_COLOR => Color::DarkBlue,
                CROSSTERM_DARK_YELLOW_COLOR => Color::DarkYellow,
                CROSSTERM_DARK_MAGENTA_COLOR => Color::DarkMagenta,
                CROSSTERM_DARK_CYAN_COLOR => Color::DarkCyan,
                CROSSTERM_DARK_GREY_COLOR => Color::DarkGrey,
                CROSSTERM_ANSI_COLOR => Color::AnsiValue(self.v.ansi.value),
                CROSSTERM_RGB_COLOR => Color::Rgb {
                    r: self.v.rgb.r,
                    g: self.v.rgb.g,
                    b: self.v.rgb.b,
                },
            }
        }
    }
}

impl Into<Color> for crossterm_color {
    fn into(self) -> Color {
        (&self).into()
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use crossterm::style::Color;

    #[test]
    fn reset_color_cast() {
        assert_eq!(
            Color::Reset,
            crossterm_color {
                t: CROSSTERM_RESET_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into(),
        );
    }

    #[test]
    fn black_color_cast() {
        assert_eq!(
            Color::Black,
            crossterm_color {
                t: CROSSTERM_BLACK_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into(),
        );
    }

    #[test]
    fn white_color_cast() {
        assert_eq!(
            Color::White,
            crossterm_color {
                t: CROSSTERM_WHITE_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn red_color_cast() {
        assert_eq!(
            Color::Red,
            crossterm_color {
                t: CROSSTERM_RED_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn green_color_cast() {
        assert_eq!(
            Color::Green,
            crossterm_color {
                t: CROSSTERM_GREEN_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn blue_color_cast() {
        assert_eq!(
            Color::Blue,
            crossterm_color {
                t: CROSSTERM_BLUE_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn yellow_color_cast() {
        assert_eq!(
            Color::Yellow,
            crossterm_color {
                t: CROSSTERM_YELLOW_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn magenta_color_cast() {
        assert_eq!(
            Color::Magenta,
            crossterm_color {
                t: CROSSTERM_MAGENTA_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn cyan_color_cast() {
        assert_eq!(
            Color::Cyan,
            crossterm_color {
                t: CROSSTERM_CYAN_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn grey_color_cast() {
        assert_eq!(
            Color::Grey,
            crossterm_color {
                t: CROSSTERM_GREY_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn dark_red_color_cast() {
        assert_eq!(
            Color::DarkRed,
            crossterm_color {
                t: CROSSTERM_DARK_RED_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn dark_green_color_cast() {
        assert_eq!(
            Color::DarkGreen,
            crossterm_color {
                t: CROSSTERM_DARK_GREEN_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn dark_blue_color_cast() {
        assert_eq!(
            Color::DarkBlue,
            crossterm_color {
                t: CROSSTERM_DARK_BLUE_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn dark_yellow_color_cast() {
        assert_eq!(
            Color::DarkYellow,
            crossterm_color {
                t: CROSSTERM_DARK_YELLOW_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn dark_magenta_color_cast() {
        assert_eq!(
            Color::DarkMagenta,
            crossterm_color {
                t: CROSSTERM_DARK_MAGENTA_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn dark_cyan_color_cast() {
        assert_eq!(
            Color::DarkCyan,
            crossterm_color {
                t: CROSSTERM_DARK_CYAN_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn dark_grey_color_cast() {
        assert_eq!(
            Color::DarkGrey,
            crossterm_color {
                t: CROSSTERM_DARK_GREY_COLOR,
                v: unsafe { std::mem::MaybeUninit::uninit().assume_init() },
            }
            .into()
        );
    }

    #[test]
    fn ansi_color_cast() {
        assert_eq!(
            Color::AnsiValue(59),
            crossterm_color {
                t: CROSSTERM_ANSI_COLOR,
                v: crossterm_color_value {
                    ansi: crossterm_ansi_color { value: 59 },
                }
            }
            .into(),
        );
    }

    #[test]
    fn rgb_color_cast() {
        assert_eq!(
            Color::Rgb { r: 5, g: 9, b: 15 },
            crossterm_color {
                t: CROSSTERM_RGB_COLOR,
                v: crossterm_color_value {
                    rgb: crossterm_rgb_color { r: 5, g: 9, b: 15 },
                },
            }
            .into(),
        );
    }
}
