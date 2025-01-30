#ifndef CROSSTERM_FFI_STREAM_H
#define CROSSTERM_FFI_STREAM_H

#include <stddef.h>
#include <stdint.h>

#include "color.h"

/// @brief Represents a generic stream.
struct crossterm_stream {
    void *context;

    ///
    /// @brief   Expected to write the specified number of bytes from the
    ///          buffer to an implementation-dependent destination.
    ///
    /// @returns Should return the number of bytes written successfully.
    ///          On failure, should return a negative value representing the
    ///          error.
    long (*write_fn)(const uint8_t *buf, size_t buflen, void *context);

    ///
    /// @brief    Expected to flush all intermediately buffered contents.
    ///
    /// @returns  Should return 0 on success. On failure, should return a
    ///           negative value.
    int (*flush_fn)(void *context);
};

// clang-format off
int crossterm_stream_set_foreground_color(struct crossterm_stream *stream, const struct crossterm_color *color);
int crossterm_stream_set_background_color(struct crossterm_stream *stream, const struct crossterm_color *color);

int crossterm_stream_set_bold_attribute(struct crossterm_stream *stream);
int crossterm_stream_reset_bold_attribute(struct crossterm_stream *stream);
int crossterm_stream_set_dim_attribute(struct crossterm_stream *stream);
int crossterm_stream_reset_dim_attribute(struct crossterm_stream *stream);
int crossterm_stream_set_underlined_attribute(struct crossterm_stream *stream);
int crossterm_stream_reset_underlined_attribute(struct crossterm_stream *stream);
int crossterm_stream_set_reverse_attribute(struct crossterm_stream *stream);
int crossterm_stream_reset_reverse_attribute(struct crossterm_stream *stream);
int crossterm_stream_set_hidden_attribute(struct crossterm_stream *stream);
int crossterm_stream_reset_hidden_attribute(struct crossterm_stream *stream);

int crossterm_stream_reset_attributes(struct crossterm_stream *stream);

// clang-format on

#endif
