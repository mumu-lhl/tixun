"""An in-memory compatibility filesystem, NOT a security boundary.

Android's isolated UID/SELinux is the boundary. No app directory is shared.
Only validated regular-file snapshots are transferred by the trusted app.
Native extensions must use file-like objects, not virtual pathnames.
"""
import base64
import stat

MAX_BYTES = 8 * 1024 * 1024
MAX_ENTRIES = 1000


def execute(code, snapshot):
    import io
    import sys
    from pyfakefs.fake_filesystem_unittest import Patcher
    from pyfakefs.fake_io import FakeIoModule2
    from pyfakefs.fake_file import FakeFileWrapper

    class ArchiveIo(FakeIoModule2):
        # CPython's open_code internally imports _io.open again. Bypass that
        # cycle only for immutable runtime reads, not public workspace IO.
        def open_code(self, path, _real_open=io.open):
            return _real_open(path, "rb")

        def open(self, *args, _real_open=io.open, **kwargs):
            # Newer CPython zipimport uses _io.open rather than open_code.
            if sys._getframe(1).f_globals.get("__name__") == "zipimport":
                return _real_open(*args, **kwargs)
            return super().open(*args, **kwargs)

    # Frozen zipimport imports _io locally, so skip_names alone cannot protect
    # it. Replacing low-level _io recurses through pyfakefs traceback lookup.
    with Patcher(
        allow_root_user=False,
        additional_skip_names=["_sp_bootstrap"],
        modules_to_patch={"_io": ArchiveIo},
    ) as patcher:
        fs = patcher.fs
        fake_os = patcher.fake_modules["os"]
        fake_io = patcher.fake_modules["io"]
        fake_os.makedirs("/workspace", exist_ok=True)
        for name in snapshot["directories"]:
            fake_os.makedirs("/workspace/" + name, exist_ok=True)
        for name, value in snapshot["files"].items():
            fs.create_file("/workspace/" + name, contents=base64.b64decode(value))
        fake_os.chdir("/workspace")
        fake_os.environ["HOME"] = "/workspace"
        fake_os.environ["TMPDIR"] = "/workspace"
        error = None
        try:
            exec(compile(code, "<sandbox>", "exec"), {"__name__": "__main__"})
        except BaseException as exc:
            import traceback
            traceback.print_exc()
            error = type(exc).__name__

        # The service exits after this snapshot, so flush handles as a normal
        # interpreter shutdown would (pyfakefs retains its open wrappers).
        for handles in fs.open_files[3:]:
            for handle in handles or []:
                if isinstance(handle, FakeFileWrapper) and not handle.closed:
                    handle.flush()

        files, directories = {}, []
        total = 0
        for directory, dirs, names in fake_os.walk("/workspace", followlinks=False):
            for name in dirs + names:
                path = directory + "/" + name
                info = fake_os.lstat(path)
                relative = path[len("/workspace/"):]
                if stat.S_ISDIR(info.st_mode):
                    directories.append(relative)
                elif stat.S_ISREG(info.st_mode):
                    total += info.st_size
                    if total > MAX_BYTES:
                        raise ValueError("Workspace exceeds 8 MiB")
                    with fake_io.open(path, "rb") as source:
                        files[relative] = base64.b64encode(source.read()).decode("ascii")
                else:
                    raise ValueError("Workspace links and special files cannot be exported")
                if len(files) + len(directories) > MAX_ENTRIES:
                    raise ValueError("Workspace exceeds 1000 entries")
        return {"files": files, "directories": directories}, error
