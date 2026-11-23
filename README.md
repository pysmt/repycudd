# repycudd
Reentrant version of pycudd: a python wrapper for the CUDD BDD library.

This is a fork of PyCUDD (http://bears.ece.ucsb.edu/pycudd.html) providing a re-entrant version of the wrapper.

The main purpose of this fork is to provide pySMT (www.pysmt.org) a re-entrant wrapper for CUDD, hence some features (especially ADD and ZDD) not currently used by PySMT could be broken in repycudd.

Take a look at examples/ to see how to use the wrapper. For a higher level interface for using BDDs, consider using pySMT.

## Installation

    pip install repycudd

PyPI has wheels for Linux (x86_64 and aarch64), macOS (x86_64 and arm64) and Windows (x86_64), for CPython 3.9 and later. CUDD 3.0.0 is linked statically into the extension, so there is nothing else to install.

## Building from source

    python -m pip install .

This needs a C/C++ compiler; see INSTALL for the details. SWIG comes from PyPI as a build dependency.

## Releasing

Set the new version in `pyproject.toml` and in `docstring.h` (`test_smoke.py` checks that they match), merge to master, then push a `vX.Y.Z` tag. The `wheels` workflow builds and tests the sdist and the wheels, uploads them to PyPI and creates the GitHub release.
