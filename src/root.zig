const std = @import("std");
const env_parser = @import("env_parser.zig");
const directory = @import("directory.zig");

pub const EnvMap = env_parser.EnvMap;
pub const Value = env_parser.Value;

pub const LoadOptions = struct {
    path: ?[]const u8 = null,
};

pub fn load(allocator: std.mem.Allocator, options: LoadOptions) !EnvMap {
    const test_ptr = allocator.alloc(u8, 1) catch return error.InvalidAllocator;
    allocator.free(test_ptr);

    if (options.path) |path| {
        const real_path = try std.fs.realpathAlloc(allocator, path);
        defer allocator.free(real_path);
        return try env_parser.parseEnvFile(allocator, real_path);
    } else {
        const env_path = try directory.scanForEnvFile(allocator, "./", 2) orelse return error.NoEnvFileFound;
        defer allocator.free(env_path);
        return try env_parser.parseEnvFile(allocator, env_path);
    }
}

pub fn loadAuto(allocator: std.mem.Allocator) !EnvMap {
    return try load(allocator, .{});
}

pub fn get(map: EnvMap, key: []const u8) ?Value {
    return env_parser.getEnv(map, key);
}

pub fn getWithDefault(map: EnvMap, key: []const u8, default: Value) Value {
    return map.get(key) orelse default;
}

pub fn deinit(map: *EnvMap) void {
    env_parser.deinitEnvMap(map);
}

test "loadAuto" {
    const allocator = std.testing.allocator;
    // const path = "./src/.env.test";
    // const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    // try file.writeAll("DB_HOST=localhost\nDB_PORT=5432\n");
    // defer file.close();
    // defer std.fs.cwd().deleteFile(path) catch {};

    var env_map = try loadAuto(allocator);
    defer deinit(&env_map);

    try std.testing.expect(env_map.contains("DB_HOST"));
    try std.testing.expect((env_map.get("DB_HOST") orelse return error.NoValue).eql(Value{ .String = "localhost" }));
    try std.testing.expect(env_map.contains("DB_PORT"));
    try std.testing.expect((env_map.get("DB_PORT") orelse return error.NoValue).eql(Value{ .Number = 5432 }));
    try std.testing.expect(env_map.contains("DEBUG"));
    try std.testing.expect((env_map.get("DEBUG") orelse return error.NoValue).eql(Value{ .Boolean = true }));
}
