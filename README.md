# SimpleEnvs

A lightweight, secure, and idiomatic Zig library for loading and parsing `.env` files, inspired by `python-dotenv`. It provides a simple API to load environment variables into a process-local `EnvMap`, with support for strings, numbers, and booleans. Designed with Zig's philosophy of explicitness, conciseness, and safety, it ensures robust security and memory management.

## Features

- **Automatic** `.env` **Loading**: Scans the current directory and up to 2 subdirectories for `.env` files with `loadAuto()`.
- **Type-Safe Parsing**: Supports strings, integers (`i64`), and booleans using a `Value` union.
- **Secure Value Lookup**: Provides `get` and `getWithDefault` for safe access without forced unwrapping.
- **Robust Security**:
  - Path traversal protection (`..` blocked).
  - Input validation (10MB file limit, 128-byte keys, 1024-byte values, 4096-byte lines).
  - UTF-8 encoding validation.
  - Symbolic link protection (`no_follow`).
- **Memory Efficiency**:
  - Uses `std.heap.GeneralPurposeAllocator` (GPA) for leak detection.
  - Minimized memory usage (\~1-2MB for typical use).
  - Explicit memory cleanup with `deinit()`.
- **Test Coverage**: Comprehensive tests for parsing, scanning, and edge cases.

## Installation

### Prerequisites

- Zig 0.14.0 or later.

### Adding to Your Project

1. Clone or copy the library to your project:

   ```bash
   git clone https://github.com/vmintf/SimpleEnvs.git
   ```

2. Add it to your `build.zig`:

   ```zig
   const std = @import("std");
   
   pub fn build(b: *std.Build) void {
       const target = b.standardTargetOptions(.{});
       const optimize = b.standardOptimizeOption(.{});
   
       const exe = b.addExecutable(.{
           .name = "my-app",
           .root_source_file = b.path("src/main.zig"),
           .target = target,
           .optimize = optimize,
       });
   
       // Add zig-dotenv as a module
       const dotenv_module = b.addModule("env", .{
           .root_source_file = b.path("zig-dotenv/src/root.zig"),
       });
       exe.root_module.addImport("env", dotenv_module);
   
       b.installArtifact(exe);
   }
   ```

3. Import and use in your code:

   ```zig
   const env = @import("Simple");
   ```

## Usage

### Basic Example

Load a `.env` file and read values:

```zig
const env = @import("env");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var env_map = try env.loadAuto(allocator);
    defer env.deinit(&env_map); // Always call to free memory

    if (env.get(env_map, "DB_HOST")) |host| {
        std.debug.print("DB_HOST: {}\n", .{host}); // Outputs: DB_HOST: localhost
    }
    const port = env.getWithDefault(env_map, "DB_PORT", env.Value{ .Number = 8080 });
    std.debug.print("DB_PORT: {}\n", .{port}); // Outputs: DB_PORT: 5432
}
```

Example `.env` file:

```
DB_HOST=localhost
DB_PORT=5432
DB_USER=admin
DEBUG=true
```

### Advanced Usage

Load a specific `.env` file with custom options:

```zig
const env = @import("env");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var env_map = try env.load(allocator, .{
        .path = "./config/.env",
    });
    defer env.deinit(&env_map);

    if (env.get(env_map, "API_KEY")) |key| {
        std.debug.print("API_KEY: {}\n", .{key});
    }
}
```

### Important Notes

- **Memory Management**: Always call `env.deinit(&env_map)` to free memory. Use `GeneralPurposeAllocator` to detect leaks.
- **Security**: The library validates paths, file sizes, and encodings to prevent attacks. Do not expose `EnvMap` values externally.
- **Input Validation**: Keys and values are limited to 128 and 1024 bytes, respectively. Lines are capped at 4096 bytes.

## Testing

Run the tests to verify functionality:

```bash
zig test src/root.zig
```

Tests cover:

- Automatic `.env` file scanning and loading.
- Parsing strings, numbers, and booleans.
- Edge cases (empty files, invalid paths, large files).

## Security Features

- **Path Traversal Protection**: Blocks `..` in paths to prevent unauthorized access.
- **File Size Limits**: Rejects files larger than 10MB to prevent DoS attacks.
- **UTF-8 Validation**: Ensures `.env` files are valid UTF-8 to avoid encoding issues.
- **Symbolic Link Protection**: Uses `no_follow` to avoid following links.
- **Memory Safety**: Explicit cleanup with `deinit()` and GPA for leak detection.

## Future Features

- Encrypted `.env` file support with Diffie-Hellman key exchange and AES-256-GCM.
- Support for scanning parent directories.
- Environment variable override prevention.

## Contributing

We welcome contributions! To contribute:

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/my-feature`).
3. Commit your changes (`git commit -m "Add my feature"`).
4. Push to the branch (`git push origin feature/my-feature`).
5. Open a pull request.

Please include tests for new features and follow Zig's coding style.

## License

MIT License. See LICENSE for details.

## Acknowledgments

Inspired by `python-dotenv` and designed for Zig's explicit and secure philosophy.
