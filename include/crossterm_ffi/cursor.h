#ifndef CROSSTERM_FFI_CURSOR_H
#define CROSSTERM_FFI_CURSOR_H

#include <stdint.h>

struct crossterm_stream;

struct crossterm_cursor_position {
    uint16_t x;
    uint16_t y;
};

int crossterm_show_cursor(struct crossterm_stream *stream);
int crossterm_hide_cursor(struct crossterm_stream *stream);
int crossterm_get_cursor_position(struct crossterm_cursor_position *position);
int crossterm_save_cursor_position(struct crossterm_stream *stream);
int crossterm_restore_cursor_position(struct crossterm_stream *stream);
int crossterm_move_cursor_up(struct crossterm_stream *stream, uint16_t nrows);
int crossterm_move_cursor_down(struct crossterm_stream *stream, uint16_t nrows);
int crossterm_move_cursor_left(struct crossterm_stream *stream, uint16_t ncols);
int crossterm_move_cursor_right(struct crossterm_stream *stream,
                                uint16_t ncols);
int crossterm_move_cursor_to(struct crossterm_stream *stream, uint16_t row,
                             uint16_t col);
int crossterm_move_cursor_to_row(struct crossterm_stream *stream, uint16_t row);
int crossterm_move_cursor_to_col(struct crossterm_stream *stream, uint16_t col);
int crossterm_move_cursor_to_next_line(struct crossterm_stream *stream,
                                       uint16_t nlines);
int crossterm_move_cursor_to_previous_line(struct crossterm_stream *stream,
                                           uint16_t nlines);

#endif
