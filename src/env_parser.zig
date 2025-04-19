const std = @import("std");

const MAX_KEY_LENGTH = 128;
const MAX_VALUE_LENGTH = 1024;
const MAX_LINE_LENGTH = 4096;

pub const EnvMap = std.StringHashMap(Value);

pub const Value = union(enum) {
    String: []const u8,
    Number: i64,
    Boolean: bool,

    pub fn deinit(self: Value, allocator: std.mem.Allocator) void {
        switch (self) {
            .String => |s| allocator.free(s),
            else => {},
        }
    }

    pub fn eql(self: Value, other: Value) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) {
            return false;
        }
        switch (self) {
            .String => |s| return std.mem.eql(u8, s, other.String),
            .Number => |n| return n == other.Number,
            .Boolean => |b| return b == other.Boolean,
        }
    }

    // 사용자 정의 포맷팅
    pub fn format(
        self: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .String => |s| try writer.print("{s}", .{s}),
            .Number => |n| try writer.print("{}", .{n}),
            .Boolean => |b| try writer.print("{}", .{b}),
        }
    }
};

pub fn parseEnvFile(allocator: std.mem.Allocator, path: []const u8) !EnvMap {
    if (std.mem.containsAtLeast(u8, path, 1, "..")) {
        return error.InvalidPath;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch |e| {
        if (@import("builtin").mode == .Debug) {
            std.debug.print("Failed to open file '{s}': {}\n", .{ path, e });
        }
        return e;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    if (file_size == 0) {
        return error.EmptyFile;
    }
    if (file_size > 10 * 1024 * 1024) {
        return error.FileTooLarge;
    }
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    const bytes_read = try file.readAll(buffer);
    if (bytes_read != file_size) {
        return error.FileReadError;
    }

    if (!std.unicode.utf8ValidateSlice(buffer)) {
        return error.InvalidEncoding;
    }

    var env_map = EnvMap.init(allocator);

    var lines = std.mem.splitAny(u8, buffer, "\r\n");
    while (lines.next()) |line| {
        if (line.len > MAX_LINE_LENGTH) {
            continue;
        }
        if (line.len == 0 or line[0] == '#') continue;

        var parts = std.mem.splitSequence(u8, line, "=");
        const key = parts.next() orelse continue;
        const value = parts.next() orelse continue;

        const trimmed_key = std.mem.trim(u8, key, " \t");
        const trimmed_value = std.mem.trim(u8, value, " \t");

        if (trimmed_key.len == 0 or trimmed_key.len > MAX_KEY_LENGTH) {
            continue;
        }
        if (trimmed_value.len > MAX_VALUE_LENGTH) {
            continue;
        }

        const key_copy = try allocator.dupe(u8, trimmed_key);
        const value_copy = try parseValue(allocator, trimmed_value);

        try env_map.put(key_copy, value_copy);
    }

    return env_map;
}

fn parseValue(allocator: std.mem.Allocator, value: []const u8) !Value {
    if (std.ascii.eqlIgnoreCase(value, "true")) {
        return Value{ .Boolean = true };
    }
    if (std.ascii.eqlIgnoreCase(value, "false")) {
        return Value{ .Boolean = false };
    }

    if (std.fmt.parseInt(i64, value, 10)) |num| {
        if (num < std.math.minInt(i64) or num > std.math.maxInt(i64)) {
            return error.NumberOutOfRange;
        }
        return Value{ .Number = num };
    } else |_| {
        const value_copy = try allocator.dupe(u8, value);
        return Value{ .String = value_copy };
    }
}

pub fn getEnv(map: EnvMap, key: []const u8) ?Value {
    return map.get(key);
}

pub fn deinitEnvMap(map: *EnvMap) void {
    var iter = map.iterator();
    while (iter.next()) |entry| {
        map.allocator.free(entry.key_ptr.*);
        entry.value_ptr.deinit(map.allocator);
    }
    map.deinit();
}

test "parseEnvFile" {
    const allocator = std.testing.allocator;
    const path = "./src/.env.test";
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    try file.writeAll("DB_HOST=localhost\nDB_PORT=5432\nDB_USER=admin\nDEBUG=true\n");
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};

    var env_map = try parseEnvFile(allocator, path);
    defer deinitEnvMap(&env_map);

    try std.testing.expect(env_map.contains("DB_HOST"));
    try std.testing.expect((env_map.get("DB_HOST") orelse return error.NoValue).eql(Value{ .String = "localhost" }));

    try std.testing.expect(env_map.contains("DB_PORT"));
    try std.testing.expect((env_map.get("DB_PORT") orelse return error.NoValue).eql(Value{ .Number = 5432 }));

    try std.testing.expect(env_map.contains("DB_USER"));
    try std.testing.expect((env_map.get("DB_USER") orelse return error.NoValue).eql(Value{ .String = "admin" }));

    try std.testing.expect(env_map.contains("DEBUG"));
    try std.testing.expect((env_map.get("DEBUG") orelse return error.NoValue).eql(Value{ .Boolean = true }));
}
