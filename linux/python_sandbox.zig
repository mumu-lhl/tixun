const std = @import("std");

extern "c" fn Py_SetPath(path: [*:0]const u32) void;
extern "c" fn Py_DecodeLocale(arg: [*:0]const u8, size: ?*usize) ?[*:0]u32;
extern "c" fn PyMem_RawFree(ptr: ?*anyopaque) void;
extern "c" fn Py_BytesMain(argc: c_int, argv: [*][*:0]const u8) c_int;

pub fn main(init: std.process.Init) void {
    const allocator = init.gpa;
    var iterator = std.process.Args.Iterator.init(init.minimal.args);
    const program = iterator.next() orelse exitWithUsage();
    const option = iterator.next() orelse exitWithUsage();
    if (!std.mem.eql(u8, option, "--bundle")) exitWithUsage();
    const bundle = iterator.next() orelse exitWithUsage();
    const script = iterator.next() orelse exitWithUsage();
    if (iterator.next() != null) exitWithUsage();

    const python_path = std.fmt.allocPrint(allocator,
        "{s}/app:{s}/site-packages:{s}/python3.13:{s}/python3.13/lib-dynload",
        .{ bundle, bundle, bundle, bundle },
    ) catch std.process.exit(70);
    defer allocator.free(python_path);
    const path_z = allocator.dupeSentinel(u8, python_path, 0) catch std.process.exit(70);
    defer allocator.free(path_z);
    const wide_path = Py_DecodeLocale(path_z.ptr, null) orelse std.process.exit(70);
    defer PyMem_RawFree(wide_path);
    Py_SetPath(wide_path);

    var python_argv = [_][*:0]const u8{ program, script };
    const exit_code = Py_BytesMain(@intCast(python_argv.len), &python_argv);
    std.process.exit(@intCast(@as(u32, @bitCast(exit_code)) & 0xff));
}

fn exitWithUsage() noreturn {
    std.debug.print("Usage: tixun-python-sandbox --bundle <bundle-dir> <script>\n", .{});
    std.process.exit(64);
}
