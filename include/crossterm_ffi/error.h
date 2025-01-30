#ifndef CROSSTERM_FFI_ERROR_H
#define CROSSTERM_FFI_ERROR_H

/// @brief Crossterm error type.
enum crossterm_error {
    CROSSTERM_SUCCESS = 0,
    CROSSTERM_EUNDEF,
    CROSSTERM_EOS,
    CROSSTERM_EINVAL,
};

const char *crossterm_strerror(enum crossterm_error error);

#endif
