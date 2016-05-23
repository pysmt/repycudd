#!/usr/bin/python -i
## Change above to point to your python.  The -i option leaves you in
## interactive mode after the script has completed. Use ctrl-d to exit
## python.

## Import the repycudd module
import repycudd

##
## PyCUDD has the concept of global DdManager. In rePyCUDD, this is
## not allowed, and the reference to the DdManager must always be
## provided explicietly. This is the key difference between PyCUDD and
## rePyCUDD. By having an explicit reference to the DdManager, it is
## possible to manage multiple instances of the BDD package, deal with
## multi-threading etc.
mgr = repycudd.DdManager()

## This simple example finds the truths set of f = (f0 | f1) & f2 where
## f0 = (x4 & ~x3) | x2
## f1 = (x3 & x1) | ~x0
## f2 = ~x0 + ~x3 + x4
## and x0 through x4 are individual Boolean variables

## Create bdd variables x0 through x4
x0 = mgr.IthVar(0)
x1 = mgr.IthVar(1)
x2 = mgr.IthVar(2)
x3 = mgr.IthVar(3)
x4 = mgr.IthVar(4)

## Compute functions f0 through f2
f0 = mgr.Or(mgr.And(x4,
                    mgr.Not(x3)),
            x2)

f1 = mgr.Or(mgr.And(x3, x1),
            mgr.Not(x0))

f2 = mgr.Or(mgr.Or(mgr.Not(x0),
                   mgr.Not(x3)),
            x4)



## Compute function f
f = mgr.And(mgr.Or(f0, f1), f2)

## Print the truth set of f
mgr.PrintMinterm(f)

## To simplify the usage of the package, we recommend using pySMT to
## build expressions. This allows a higher-level usage of the package.
