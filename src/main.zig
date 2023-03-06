const std = @import("std");
const net = std.net;
const mem = std.mem;
const xev = @import("xev");
const lua = @import("lua");
const Lua = lua.Lua;
const exportLoop = @import("wrap_loop.zig").exportLoop;
const allocator = std.heap.c_allocator;

pub fn main() !void {
    var vm = try Lua.init(allocator);
    defer vm.deinit();
    vm.openLibs();

    // expose Loop
    try exportLoop(&vm);

    try vm.loadString(@embedFile("main.lua"));
    vm.protectedCall(0, 0, 0) catch |e| {
        std.debug.print("VM error: {}\n", .{ e });
    };
}
