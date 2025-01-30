#ifndef CROSSTERM_FFI_EVENT_H
#define CROSSTERM_FFI_EVENT_H

#include <stdint.h>

// clang-format off

#define CROSSTERM_SHIFT_KEY_MODIFIER     (1 << 0)
#define CROSSTERM_CONTROL_KEY_MODIFIER   (1 << 1)
#define CROSSTERM_ALT_KEY_MODIFIER       (1 << 2)
#define CROSSTERM_SUPER_KEY_MODIFIER     (1 << 3)
#define CROSSTERM_HYPER_KEY_MODIFIER     (1 << 4)
#define CROSSTERM_META_KEY_MODIFIER      (1 << 5)
#define CROSSTERM_KEYPAD_KEY_MODIFIER    (1 << 6)
#define CROSSTERM_CAPS_LOCK_KEY_MODIFIER (1 << 7)
#define CROSSTERM_NUM_LOCK_KEY_MODIFIER  (1 << 8)

// clang-format on

enum crossterm_event_type {
    CROSSTERM_KEY_EVENT,
    CROSSTERM_RESIZE_EVENT,
};

enum crossterm_key_type {
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
};

struct crossterm_key_event {
    enum crossterm_key_type type;
    uint32_t code;
    uint16_t modifiers;
};

struct crossterm_resize_event {
    uint16_t width;
    uint16_t height;
};

struct crossterm_event {
    enum crossterm_event_type type;
    union {
        struct crossterm_key_event key;
        struct crossterm_resize_event resize;
    };
};

int crossterm_event_read(struct crossterm_event *event);
int crossterm_event_poll(int *is_available);

#endif
