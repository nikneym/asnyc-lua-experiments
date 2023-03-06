const std = @import("std");
const mem = std.mem;
const xev = @import("xev");
const lua = @import("lua");
const Lua = lua.Lua;
pub const Loop = @import("loop.zig").Loop;

fn loopNew(vm: *Lua) i32 {
    const ptr = vm.newUserdata(Loop);
    ptr.* = Loop.init() catch {
        vm.pushNil();
        vm.pushString("failed initializing a new loop");
        return 2;
    };
    vm.getMetatableRegistry("loopMt");
    vm.setMetatable(-2);

    return 1;
}

fn loopRun(vm: *Lua) i32 {
    const loop = vm.toUserdata(Loop, 1) catch {
        vm.pushString("received nil instead of loop");
        return 1;
    };

    loop.run() catch {
        vm.pushString("error while running the loop");
        return 1;
    };

    return 0;
}

fn loopSchedule(vm: *Lua) i32 {
    const loop = vm.toUserdata(Loop, 1) catch {
        vm.pushString("received nil instead of loop");
        return 1;
    };
    const task = vm.toThread(2) catch {
        vm.pushString("second argument expects a coroutine");
        return 1;
    };

    loop.schedule(std.heap.c_allocator, task) catch {
        vm.pushString("could not scheduled the given coroutine");
        return 1;
    };

    return 0;
}

fn loopSpawn(vm: *Lua) i32 {
    const loop = vm.toUserdata(Loop, 1) catch {
        vm.pushString("received nil instead of loop");
        return 1;
    };
    var task = vm.toThread(2) catch {
        vm.pushString("second argument expects a coroutine");
        return 1;
    };

    _ = loop;
    _ = task.resumeThread(0) catch {
        vm.pushString("failed running given coroutine");
        return 1;
    };

    return 0;
}

fn tcpConnect(vm: *Lua) i32 {
    const loop = vm.toUserdata(Loop, 1) catch {
        vm.pushNil();
        vm.pushString("received nil instead of loop");
        return 2;
    };
    const host = vm.toString(2) catch {
        vm.pushNil();
        vm.pushString("expected host as string");
        return 2;
    };
    const port = vm.toInteger(3);

    const addr = std.net.Address.parseIp(mem.span(host), @intCast(u16, port)) catch {
        vm.pushNil();
        vm.pushString("failed parsing address");
        return 2;
    };

    loop.scheduleConnect(std.heap.c_allocator, vm, addr) catch {
        vm.pushNil();
        vm.pushString("failed opening a TCP connection");
        return 2;
    };

    return vm.yield2(0);
}

/// Expose Loop to the Lua VM.
pub fn exportLoop(vm: *Lua) !void {
    // file
    try vm.newMetatable("fileMt");
    vm.newTable();
    vm.setField(-2, "__index");

    // loop
    try vm.newMetatable("loopMt");
    vm.newTable();
    vm.pushString("run");
    vm.pushFunction(lua.wrap(loopRun));
    vm.rawSetTable(-3);
    vm.pushString("schedule");
    vm.pushFunction(lua.wrap(loopSchedule));
    vm.rawSetTable(-3);
    vm.pushString("spawn");
    vm.pushFunction(lua.wrap(loopSpawn));
    vm.rawSetTable(-3);
    vm.pushString("tcpConnect");
    vm.pushFunction(lua.wrap(tcpConnect));
    vm.rawSetTable(-3);

    vm.setField(-2, "__index");

    vm.register("newLoop", lua.wrap(loopNew));
}
