import ctypes
import os
import struct
import sys
from glob import glob

from setuptools import Extension, setup
from setuptools.command.build_py import build_py

CUDD = "cudd-3.0.0"
CUDD_DIRS = ["cudd", "dddmp", "epd", "mtr", "st", "util"]

# Same file lists as CUDD's Included.am files, minus the util files that
# CUDD does not call (most of them are POSIX-only).
cudd_sources = (
    glob(f"{CUDD}/cudd/cudd*.c")
    + [f"{CUDD}/dddmp/dddmp{n}.c" for n in (
        "StoreBdd", "StoreAdd", "StoreCnf", "Load", "LoadCnf", "NodeBdd",
        "NodeAdd", "NodeCnf", "StoreMisc", "Util", "Binary", "Convert", "Dbg")]
    + [f"{CUDD}/mtr/mtrBasic.c", f"{CUDD}/mtr/mtrGroup.c",
       f"{CUDD}/st/st.c", f"{CUDD}/epd/epd.c"]
    + [f"{CUDD}/util/{n}.c" for n in (
        "safe_mem", "cpu_time", "prtime", "datalimit", "ucbqsort", "cstringstream")]
)

# The rest of the configuration lives in cudd-3.0.0/config.h.
define_macros = [
    ("SIZEOF_VOID_P", str(struct.calcsize("P"))),
    ("SIZEOF_INT", str(ctypes.sizeof(ctypes.c_int))),
]
if sys.platform == "win32":
    define_macros += [("_CRT_SECURE_NO_WARNINGS", None)]
    # C4311/C4312 are pointer truncation/extension: any hit is an LLP64 bug.
    extra_compile_args = ["/we4311", "/we4312"]
else:
    extra_compile_args = ["-w"]  # ponytail: CUDD is noisy and we do not maintain it


class BuildPyAfterExt(build_py):
    # SWIG writes repycudd.py during build_ext, which normally runs after build_py.
    def run(self):
        self.run_command("build_ext")
        super().run()


setup(
    py_modules=["repycudd"],
    ext_modules=[Extension(
        "_repycudd",
        sources=["repycudd.i", "repycudd.cpp"] + cudd_sources,
        include_dirs=[".", CUDD] + [os.path.join(CUDD, d) for d in CUDD_DIRS],
        define_macros=define_macros,
        extra_compile_args=extra_compile_args,
        swig_opts=["-c++"],
        language="c++",
    )],
    cmdclass={"build_py": BuildPyAfterExt},
)
