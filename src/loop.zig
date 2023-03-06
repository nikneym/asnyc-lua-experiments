const std = @import("std");
const mem = std.mem;
const xev = @import("xev");
const lua = @import("lua");
const Lua = lua.Lua;

pub const Loop = struct {
    loop: xev.Loop,
    tasks: std.ArrayListUnmanaged(Lua) = .{},

    /// Initialize a new event loop.
    pub fn init() !Loop {
        var loop = try xev.Loop.init(.{});

        return .{
            .loop = loop,
        };
    }

    /// Deinitialize the event loop and release it's resources.
    pub fn deinit(self: Loop, allocator: mem.Allocator) void {
        self.loop.deinit();
        self.tasks.deinit(allocator);
    }

    /// Run the event loop.
    pub fn run(self: *Loop) !void {
        //while (true) {
            //var task = self.tasks.popOrNull() orelse break;
            //const status = try task.resumeThread(0);

            // task is not finished yet, reschedule
            //if (status == .yield)
            //    self.tasks.appendAssumeCapacity(task);

        //    self.loop.run(.no_wait) catch {
        //        break;
        //    };
        //}

        return self.loop.run(.until_done);
    }

    /// Push the coroutine to the tasks.
    pub fn schedule(self: *Loop, allocator: mem.Allocator, task: Lua) mem.Allocator.Error!void {
        return self.tasks.append(allocator, task);
    }

    pub const File = struct {
        file: std.fs.File,
        fd: xev.File,
        c: xev.Completion,

        pub fn init(_: mem.Allocator, file: std.fs.File, fd: xev.File) !File {
            return .{
                .file = file,
                .fd = fd,
                .c = undefined,
            };
        }
    };

    pub fn scheduleConnect(
        self: *Loop,
        allocator: mem.Allocator,
        vm: *Lua,
        addr: std.net.Address,
    ) !void {
        const socket = try xev.TCP.init(addr);
        const c = try allocator.create(xev.Completion);

        socket.connect(
            &self.loop,
            c,
            addr,
            Lua,
            vm,
            (struct {
                fn callback(
                    vm_: ?*Lua,
                    _: *xev.Loop,
                    c_: *xev.Completion,
                    _: xev.TCP,
                    res: xev.TCP.ConnectError!void,
                ) xev.CallbackAction {
                    _ = res catch unreachable;

                    const vmm = vm_.?;
                    _ = vmm.resumeThread(0) catch |e| {
                        std.debug.print("{}\n", .{ e });
                    };

                    std.heap.c_allocator.destroy(c_);
                    return .disarm;
                }
            }).callback,
        );
    }

    /// FIXME: do not use anytype for file
    pub fn scheduleRead(self: *Loop, allocator: mem.Allocator, co: *Lua, file: *File, size: usize) !void {
        _ = co;
        _ = size;

        var n: usize = undefined;
        var buf: [1024]u8 = undefined;
        const c = try allocator.create(xev.Completion);

        file.fd.read(
            &self.loop,
            c,
            .{ .slice = &buf },
            usize,
            &n,
            (struct {
                fn callback(
                    _: ?*usize,
                    _: *xev.Loop,
                    c_: *xev.Completion,
                    _: xev.File,
                    buf_: xev.ReadBuffer,
                    res: xev.File.ReadError!usize,
                ) xev.CallbackAction {
                    _ = res catch |e| {
                        std.debug.print("{}\n", .{ e });
                    };

                    std.debug.print("completed a read action\n", .{});
                    //std.heap.c_allocator.free(buf_.slice);
                    _ = buf_;
                    std.heap.c_allocator.destroy(c_);

                    return .rearm;
                }
            }).callback,
        );
    }
};
