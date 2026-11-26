"""Exercise image-only resolution, including copy_exec's ignored ldd error."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


RESOLVER = Path(__file__).resolve().parents[1] / "minimal" / "initramfs-ldd"


class ImageLibraries(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix="regolith-ldd-")
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name) / "root"
        self.libdir = self.root / "usr/lib/x86_64-linux-gnu"
        self.libdir.mkdir(parents=True)
        (self.root / "usr/bin").mkdir()
        shutil.copyfile("/usr/bin/true", self.root / "usr/bin/true")
        for name in ("ld-linux-x86-64.so.2", "libc.so.6"):
            shutil.copy2("/usr/lib/x86_64-linux-gnu/" + name, self.libdir / name)
        self.errors = Path(self.work.name) / "errors"
        self.used = Path(self.work.name) / "used"

    def resolve(self):
        env = dict(os.environ, REGOLITH_BUILD_ROOT=str(self.root),
                   REGOLITH_LDD_ERRORS=str(self.errors), REGOLITH_LDD_USED=str(self.used))
        env.pop("LD_PRELOAD", None)
        return subprocess.run(["/usr/bin/python3", str(RESOLVER), "/usr/bin/true"],
                              env=env, text=True, capture_output=True)

    def test_resolves_image_and_returns_virtual_paths(self):
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("=> /usr/lib/x86_64-linux-gnu/libc.so.6", result.stdout)
        self.assertIn("\t/lib64/ld-linux-x86-64.so.2 (", result.stdout)
        self.assertNotIn(str(self.root), result.stdout)
        self.assertFalse(self.errors.exists())
        self.assertTrue(self.used.exists())

    def test_host_library_cannot_hide_missing_image_library(self):
        (self.libdir / "libc.so.6").unlink()
        result = self.resolve()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("library resolved outside the image", self.errors.read_text())

    def test_absolute_runpath_uses_image_private_library(self):
        private = self.root / "usr/lib/private"
        private.mkdir()
        library = Path(self.work.name) / "library.s"
        library.write_text('.text\n.global probe\nprobe:\nret\n')
        program = Path(self.work.name) / "program.s"
        program.write_text('.text\n.global _start\n_start:\ncall probe\n')
        for source in (library, program):
            subprocess.run(["as", "-o", str(source.with_suffix(".o")), str(source)], check=True)
        subprocess.run(["ld", "-shared", "-soname", "libprobe.so", "-o",
                        str(private / "libprobe.so"), str(library.with_suffix(".o"))], check=True)
        subprocess.run(["ld", "--dynamic-linker", "/lib64/ld-linux-x86-64.so.2",
                        "-rpath", "/usr/lib/private", "-o", str(self.root / "usr/bin/true"),
                        str(program.with_suffix(".o")), "-L" + str(private), "-lprobe"], check=True)
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("=> /usr/lib/private/libprobe.so", result.stdout)

    def test_env_finds_resolver_inside_fakechroot(self):
        shutil.copy2("/usr/bin/env", self.root / "usr/bin/env")
        shim = Path(self.work.name) / "shim"
        shim.mkdir()
        shutil.copy2(RESOLVER.with_name("initramfs-ldd-wrapper"), shim / "ldd")
        (shim / "ldd").chmod(0o755)
        shutil.copy2("/usr/bin/python3", self.root / "usr/bin/python3")
        shutil.copy2("/bin/sh", self.root / "usr/bin/sh")
        (self.root / "bin").symlink_to("usr/bin")
        (self.root / "lib").symlink_to("usr/lib")
        (self.root / "lib64").symlink_to("usr/lib/x86_64-linux-gnu")
        env = dict(os.environ, REGOLITH_BUILD_ROOT=str(self.root),
                   REGOLITH_LDD_ERRORS=str(self.errors), REGOLITH_LDD_USED=str(self.used),
                   REGOLITH_LDD_SCRIPT=str(RESOLVER), REGOLITH_LDD_WRAPPER=str(shim / "ldd"),
                   PATH="/usr/sbin:/usr/bin:/sbin:/bin")
        env.pop("LD_PRELOAD", None)
        result = subprocess.run(
            ["/usr/bin/fakechroot", "/usr/sbin/chroot", str(self.root),
             "/bin/sh", "-c",
             'export FAKECHROOT_CMD_SUBST="/usr/bin/ldd=$REGOLITH_LDD_WRAPPER:/bin/ldd=$REGOLITH_LDD_WRAPPER"; /bin/sh -c "/usr/bin/env --unset=LD_PRELOAD ldd /usr/bin/true"'],
            env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("=> /usr/lib/x86_64-linux-gnu/libc.so.6", result.stdout)
        self.assertTrue(self.used.exists())


if __name__ == "__main__":
    unittest.main()
