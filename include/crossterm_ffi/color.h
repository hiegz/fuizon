#ifndef CROSSTERM_FFI_COLOR_H
#define CROSSTERM_FFI_COLOR_H

#include <stdint.h>

enum crossterm_color_type {
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
};

struct crossterm_ansi_color {
    uint8_t value;
};

struct crossterm_rgb_color {
    uint8_t r;
    uint8_t g;
    uint8_t b;
};

struct crossterm_color {
    enum crossterm_color_type type;
    union {
        struct crossterm_ansi_color ansi;
        struct crossterm_rgb_color rgb;
    };
};

#endif
