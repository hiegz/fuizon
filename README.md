<div align="center">
    <img src="./assets/logo.png" width="100"/>
    <h3>Fuizon</h3>
    <p>A cross-platform TUI library for Zig</p>
</div>

## Requirements

- Zig 0.14.0
- Rust/Cargo

## Installation

1. Fetch:

```sh
zig fetch --save https://github.com/byut/fuizon/archive/<git-ref-here>.tar.gz
```

2. Link to your executable or module:

```zig
const fuizon = b.dependency("fuizon", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("fuizon", fuizon.module("fuizon"));
```

3. Import:

```zig
const fuizon = @import("fuizon");
```

## What you can build

https://github.com/user-attachments/assets/e1e4189d-2b1c-481f-a519-0430aa619ace

Discover more examples [here](https://github.com/byut/fuizon/tree/main/examples)
