"""Minimal smoke test for a freshly built repycudd.

This is a regression net for the build, not a test suite for CUDD. Run it with
PYTHONPATH pointing at a directory holding repycudd.py and _repycudd.so.
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

print("ok")
