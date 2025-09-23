pub const BorderType = enum(u8) {
    /// A plain, simple border.
    ///
    /// ┌───────┐
    /// │       │
    /// └───────┘
    ///
    plain = 0,

    /// A plain border with rounded corners.
    ///
    /// ╭───────╮
    /// │       │
    /// ╰───────╯
    ///
    rounded = 1,

    /// A doubled border.
    ///
    /// ╔═══════╗
    /// ║       ║
    /// ╚═══════╝
    ///
    double = 2,

    /// A thick border.
    ///
    /// ┏━━━━━━━┓
    /// ┃       ┃
    /// ┗━━━━━━━┛
    ///
    thick = 3,
};
