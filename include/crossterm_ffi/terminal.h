#ifndef CROSSTERM_FFI_TERMINAL_H
#define CROSSTERM_FFI_TERMINAL_H

#include <stdbool.h>
#include <stdint.h>

struct crossterm_stream;

int crossterm_is_raw_mode_enabled(bool *is_enabled);
int crossterm_enable_raw_mode(void);
int crossterm_disable_raw_mode(void);
int crossterm_enter_alternate_screen(struct crossterm_stream *stream);
int crossterm_leave_alternate_screen(struct crossterm_stream *stream);
int crossterm_enable_line_wrap(struct crossterm_stream *stream);
int crossterm_disable_line_wrap(struct crossterm_stream *stream);
int crossterm_scroll_up(struct crossterm_stream *stream, uint16_t nlines);
int crossterm_scroll_down(struct crossterm_stream *stream, uint16_t nlines);
int crossterm_clear_all(struct crossterm_stream *stream);
int crossterm_clear_purge(struct crossterm_stream *stream);
int crossterm_clear_from_cursor_up(struct crossterm_stream *stream);
int crossterm_clear_from_cursor_down(struct crossterm_stream *stream);
int crossterm_clear_current_line(struct crossterm_stream *stream);
int crossterm_clear_until_new_line(struct crossterm_stream *stream);

struct crossterm_size {
    uint16_t width;
    uint16_t height;
};
int crossterm_get_size(struct crossterm_size *size);

#endif
