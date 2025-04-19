const env = @import("env");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var env_map = env.loadAuto(allocator) catch |e| {
        std.debug.print("Failed to load .env: {}\n", .{e});
        return e;
    };
    defer env.deinit(&env_map);

    if (env.get(env_map, "DB_HOST")) |host| {
        std.debug.print("DB_HOST: {}\n", .{host});
    }
    const port = env.getWithDefault(env_map, "DB_PORT", env.Value{ .Number = 8080 });
    std.debug.print("DB_PORT: {}\n", .{port});
}
