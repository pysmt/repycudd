# repycudd
Reentrant version of pycudd: a python wrapper for the CUDD BDD library.

This is a fork of PyCUDD (http://bears.ece.ucsb.edu/pycudd.html) providing a re-entrant version of the wrapper.

The main purpose of this fork is to provide pySMT (www.pysmt.org) a re-entrant wrapper for CUDD, hence some features (especially ADD and ZDD) not currently used by PySMT could be broken in repycudd.

Take a look at examples/ to see how to use the wrapper. For a higher level interface for using BDDs, consider using pySMT.

## Building

    python -m pip install .

This works on Linux and 64-bit Windows; see INSTALL for the compiler requirements. SWIG comes from PyPI as a build dependency.
