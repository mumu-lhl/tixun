const std = @import("std");
const j = @import("jni");
extern "c" fn syscall(number: c_long, ...) c_long;
extern "c" fn write(fd: c_int, buf: [*]const u8, len: usize) isize;
extern "c" fn lseek(fd: c_int, offset: i64, whence: c_int) i64;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn dup2(old: c_int, new: c_int) c_int;
extern "c" fn dlerror() ?[*:0]const u8;
extern "c" fn dlopen(path: [*:0]const u8, flags: c_int) ?*anyopaque;
extern "c" fn dlsym(handle: *anyopaque, name: [*:0]const u8) ?*anyopaque;
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;

export fn Java_org_tixun_tixun_python_PythonSandboxNative_archive(env: [*c]j.JNIEnv, _: j.jobject, bytes: j.jbyteArray) j.jint {
    const api = env.*.*;
    const length = api.GetArrayLength.?(env, bytes);
    const data = api.GetByteArrayElements.?(env, bytes, null);
    if (data == null) return -1;
    defer api.ReleaseByteArrayElements.?(env, bytes, data, j.JNI_ABORT);
    // A path-like memfd name also gives mobile-forge sysconfig a deep enough
    // __file__.resolve().parents chain; no actual directory is created.
    const fd: c_int = @intCast(syscall(j.SYS_memfd_create, @as([*:0]const u8, "tixun/python/runtime/archive.zip"), @as(c_uint, 0)));
    if (fd < 0) return -1;
    var done: usize = 0;
    while (done < @as(usize, @intCast(length))) {
        const count = write(fd, @as([*]const u8, @ptrCast(data)) + done, @as(usize, @intCast(length)) - done);
        if (count <= 0) {
            _ = close(fd);
            return -1;
        }
        done += @intCast(count);
    }
    _ = lseek(fd, 0, 0);
    return fd;
}

fn symbol(comptime T: type, handle: *anyopaque, name: [*:0]const u8) ?T {
    return @ptrCast(@alignCast(dlsym(handle, name) orelse return null));
}

export fn Java_org_tixun_tixun_python_PythonSandboxNative_run(env: [*c]j.JNIEnv, _: j.jobject, prefix: j.jstring, archives: j.jintArray, input: j.jint, output: j.jint) j.jint {
    const api = env.*.*;
    const native_prefix = api.GetStringUTFChars.?(env, prefix, null);
    if (native_prefix == null) return 70;
    defer api.ReleaseStringUTFChars.?(env, prefix, native_prefix);
    _ = setenv("ANDROID_APK_NATIVE_PREFIX", native_prefix, 1);
    _ = setenv("OPENBLAS_NUM_THREADS", "1", 1);
    var library_buf: [4096]u8 = undefined;
    const library = std.fmt.bufPrintSentinel(&library_buf, "{s}libpython3.13.so", .{native_prefix}, 0) catch return 70;
    _ = dup2(output, 2);
    const handle = dlopen(library, 2 | 0x100) orelse {
        if (dlerror()) |error_text| _ = write(output, error_text, std.mem.len(error_text));
        return 71;
    };
    const decode = symbol(*const fn ([*:0]const u8, ?*usize) callconv(.c) ?[*:0]u32, handle, "Py_DecodeLocale") orelse return 72;
    const set_path = symbol(*const fn ([*:0]const u32) callconv(.c) void, handle, "Py_SetPath") orelse return 72;
    const initialize = symbol(*const fn (c_int) callconv(.c) void, handle, "Py_InitializeEx") orelse return 72;
    const run = symbol(*const fn ([*:0]const u8) callconv(.c) c_int, handle, "PyRun_SimpleString") orelse return 72;
    const fds = api.GetIntArrayElements.?(env, archives, null);
    if (fds == null) return 70;
    defer api.ReleaseIntArrayElements.?(env, archives, fds, j.JNI_ABORT);
    if (api.GetArrayLength.?(env, archives) != 4) return 70;
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrintSentinel(&path_buf, "/proc/self/fd/{d}:/proc/self/fd/{d}:/proc/self/fd/{d}:/proc/self/fd/{d}", .{ fds[0], fds[1], fds[2], fds[3] }, 0) catch return 70;
    const wide = decode(path, null) orelse return 70;
    set_path(wide);
    const no_site = symbol(*c_int, handle, "Py_NoSiteFlag") orelse return 72;
    no_site.* = 1;
    const isolated = symbol(*c_int, handle, "Py_IsolatedFlag") orelse return 72;
    isolated.* = 1;
    const no_bytecode = symbol(*c_int, handle, "Py_DontWriteBytecodeFlag") orelse return 72;
    no_bytecode.* = 1;
    initialize(0);
    var code_buf: [1024]u8 = undefined;
    const code = std.fmt.bufPrintSentinel(&code_buf, "import _sp_bootstrap; _sp_bootstrap.install()\nimport android_worker\nandroid_worker.run({d}, {d})\n", .{ input, output }, 0) catch return 70;
    return run(code);
}
