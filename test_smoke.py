"""Minimal smoke test for a freshly built repycudd.

This is a regression net for the build, not a test suite for CUDD. Run it with
PYTHONPATH pointing at a directory holding repycudd.py and _repycudd.*.
"""
import repycudd

mgr = repycudd.DdManager()
x = mgr.IthVar(0)

assert mgr.And(x, mgr.Not(x)) == mgr.ReadLogicZero()
assert mgr.Or(x, mgr.Not(x)) == mgr.ReadOne()

# Exercises the %exception blocks (RangeError -> IndexError). Nothing in
# examples/ reaches them, and they are the only hand-written exception
# handling in the SWIG interface files.
try:
    repycudd.IntArray(2)[5]
except IndexError:
    pass
else:
    raise AssertionError("out-of-bounds IntArray access did not raise IndexError")

# Pointer truncation canary (Win64 has a 32-bit long). x_i == y_i for all i,
# with all x before all y, needs ~2**N nodes; sifting brings it down to ~3N.
# A pointer cast through a 32-bit integer anywhere on these paths (unique
# table, cache, complement edges, reordering) crashes or breaks the counts.
N = 16
mgr = repycudd.DdManager()
xs = [mgr.IthVar(i) for i in range(N)]
ys = [mgr.IthVar(N + i) for i in range(N)]
f = mgr.ReadOne()
for x, y in zip(xs, ys):
    f = mgr.And(f, mgr.Xnor(x, y))
assert f.DagSize() > 2 ** N
assert mgr.CountMinterm(f, 2 * N) == 2.0 ** N
assert mgr.CountMinterm(mgr.Not(f), 2 * N) == 2.0 ** (2 * N) - 2.0 ** N

CUDD_REORDER_SIFT = 4
assert mgr.ReduceHeap(CUDD_REORDER_SIFT, 0) == 1
assert f.DagSize() <= 3 * N + 1
assert mgr.CountMinterm(f, 2 * N) == 2.0 ** N
g = mgr.ReadOne()
for x, y in zip(reversed(xs), reversed(ys)):
    g = mgr.And(g, mgr.Xnor(y, x))
assert f == g

# Memory limits above 4 GB must survive the round trip (long is 32 bits on Win64).
SIX_GB = 6 << 30
mgr = repycudd.DdManager(0, 0, 256, 262144, SIX_GB)
assert mgr.ReadMaxMemory() >= 2 ** 64 - 1  # default hard limit is SIZE_MAX
mgr.SetMaxMemory(SIX_GB)
assert mgr.ReadMaxMemory() == SIX_GB
assert mgr.ReadMemoryInUse() > 0

print("ok")
