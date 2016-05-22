#!/usr/bin/python -i
# This example shows how to use the BREL interface
#

######################################
###
### NOTE: THIS IS STILL IN BETA
###
######################################

import repycudd
m = repycudd.DdManager()

# Note how the DdArrays are created and initialised
ips = repycudd.DdArray(m, 2)
ops = repycudd.DdArray(m, 2)
a = m.IthVar(0)
not_a = m.Not(a)
b = m.IthVar(1)
not_b = m.Not(b)
c = m.IthVar(2)
not_c = m.Not(c)
d = m.IthVar(3)
not_d = m.Not(d)
ips.Push(a)
ips.Push(b)
ops.Push(c)
ops.Push(d)

#
# Create a relation -- this maps 00 -> 00, 11; 11 -> 01, 10; 01 -> --; 10 -> --
#
#rel = (~a & ~b & ((~c & ~d) | (c & d))) |
#      (a & b & ((~c & d) | (c & ~d)))
rel = m.Or(m.And(m.And(not_a, not_b),
                 m.Or(m.And(not_c, not_d),
                      m.And(c, d))),
           m.And(m.And(a, b), m.Or(m.And(not_c, d),
                                   m.And(c, not_d))))
rel = m.Or(rel, m.And(not_a, b))
rel = m.Or(rel, m.And(a, not_b))

print("The relation is")
m.PrintMinterm(rel)

# Objects depending on the manager need to be free'd before the manager
# Forcing this here
del ips
del ops

## This is currently not supported
# # Create a BrelRelation_t object
# bbr = repycudd.BrelRelation_t(rel,ips,ops)
# # Create a BREL Context -- more methods will be added to this class
# ct = repycudd.BrelContext_t()
# # Call the solver
# z = bbr.SolveRelation(ct)

# #
# # The solution is returned as a DdArray, which contains functions for the onset of
# # each minimised output. In our case, note how output 1 is reduced to always 0 --
# # thus, the call to PrintMinterm doesn't produce any output
# #
# print "Output 0 is"
# z[0].PrintMinterm()

# print "Output 1 is"
# z[1].PrintMinterm()
