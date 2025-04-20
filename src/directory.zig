const std = @import("std");
const fs = std.fs;

pub fn scanForEnvFile(allocator: std.mem.Allocator, path: []const u8, max_depth: usize) !?[]const u8 {
    if (std.mem.containsAtLeast(u8, path, 1, "..")) {
        return error.InvalidPath;
    }

    var dir = fs.cwd().openDir(path, .{ .iterate = true, .no_follow = true }) catch |e| {
        if (@import("builtin").mode == .Debug) {
            std.debug.print("Failed to open directory '{s}': {}\n", .{ path, e });
        }
        return null;
    };
    defer dir.close();

    var dir_iter = dir.iterate();
    var entry_count: usize = 0;
    const MAX_ENTRIES = 1000;

    while (try dir_iter.next()) |entry| {
        if (entry_count >= MAX_ENTRIES) {
            return error.TooManyEntries;
        }
        entry_count += 1;

        if (std.mem.eql(u8, entry.name, ".env") and entry.kind == .file) {
            return try std.fs.path.join(allocator, &.{ path, entry.name });
        }
    }

    if (max_depth == 0) {
        return null;
    }

    dir_iter = dir.iterate();
    entry_count = 0;
    while (try dir_iter.next()) |entry| {
        if (entry_count >= MAX_ENTRIES) {
            return error.TooManyEntries;
        }
        entry_count += 1;

        if (entry.kind == .directory) {
            const sub_path = try std.fs.path.join(allocator, &.{ path, entry.name });
            defer allocator.free(sub_path);

            if (try scanForEnvFile(allocator, sub_path, max_depth - 1)) |env_path| {
                return env_path;
            }
        }
    }

    return null;
}

test "scanForEnvFile" {
    const allocator = std.testing.allocator;
    // const path = "./src/.env.test";
    // const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    // try file.writeAll("TEST=example\n");
    // defer file.close();
    // defer std.fs.cwd().deleteFile(path) catch {};

    const env_path = try scanForEnvFile(allocator, "./", 2) orelse return error.NoEnvFileFound;
    defer allocator.free(env_path);

    // try std.testing.expect(std.mem.endsWith(u8, env_path, ".env.test"));
}
