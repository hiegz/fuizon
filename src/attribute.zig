const fuizon = @import("fuizon.zig");
const c = @import("headers.zig").c;
const Attribute = fuizon.style.Attribute;
const Attributes = fuizon.style.Attributes;

pub fn setAttribute(attribute: Attribute) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = switch (attribute) {
        // zig fmt: off
        .underlined => c.crossterm_stream_set_underlined_attribute(&s),
        .reverse    => c.crossterm_stream_set_reverse_attribute(&s),
        .hidden     => c.crossterm_stream_set_hidden_attribute(&s),
        .bold       => c.crossterm_stream_set_bold_attribute(&s),
        .dim        => c.crossterm_stream_set_dim_attribute(&s),
        // zig fmt: on
    };
    if (0 != ret) return error.TerminalError;
}

pub fn resetAttribute(attribute: Attribute) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = switch (attribute) {
        // zig fmt: off
        .underlined => c.crossterm_stream_reset_underlined_attribute(&s),
        .reverse    => c.crossterm_stream_reset_reverse_attribute(&s),
        .hidden     => c.crossterm_stream_reset_hidden_attribute(&s),
        .bold       => c.crossterm_stream_reset_bold_attribute(&s),
        .dim        => c.crossterm_stream_reset_dim_attribute(&s),
        // zig fmt: on
    };
    if (0 != ret) return error.TerminalError;
}
