#!/usr/bin/python -i
# This example shows the 3 different ways to iterate over a DdNode

# Import the module, create the manager
import repycudd
m = repycudd.DdManager()

#
# Create a random function as an example
# Note that you don't need to create the variable individually to use them --
# you can directly use IthVar() to provide the variable
#
a = m.IthVar(0)
b = m.IthVar(1)
c = m.IthVar(2)
#  (~a & ~b & ((~c & ~m.IthVar(3)) |
#              (c & m.IthVar(3)))) |
#  (a & b & ((~c & m.IthVar(3)) | (c & ~m.IthVar(3))))

not_a = m.Not(a)
not_b = m.Not(b)
not_c = m.Not(c)

rel_a = m.And(m.And(not_a, not_b),
              m.Or(m.And(not_c, m.Not(m.IthVar(3))),
                   m.And(c, m.IthVar(3))))
rel_b = m.And(m.And(a, b),
              m.Or(m.And(not_c, m.IthVar(3)),
                   m.And(c, m.Not(m.IthVar(3)))))
rel = m.Or(rel_a, rel_b)
#rel = m.Or(rel, m.And(not_a, b))
#rel = m.Or(rel, m.And(a, not_b))

print("Going to iterate over the following function")
m.PrintMinterm(rel)

#
# The 3 iteration methods produce cubes, nodes and primes respectively
# Note that since the package uses complement edges, the nodes may not be what
# you expected!! Refer pyiter.i and ddnode.i for details on how this is done.
#
print("Testing iteration methods ...")
# Over cubes
print("Over cubes ...")
repycudd.set_iter_meth(0)
for cube in repycudd.ForeachCubeIterator(m, rel):
    print(repycudd.cube_tuple_to_str(cube))

# Over nodes
print("Over nodes ...")
repycudd.set_iter_meth(1)
for node in repycudd.ForeachNodeIterator(m, rel):
    print("***")
    m.PrintMinterm(node)

# Over primes
# print("Over primes ...")
# repycudd.set_iter_meth(2)
# for prime in repycudd.ForeachPrimeIterator(m, repycudd.NodePair(rel, rel)):
#     print(repycudd.cube_tuple_to_str(prime))

#
# One/two literal clause enumeration
#

#
# Simple POS expression (a + b)(!c + d)(!e + !f)(g + !h)i
#
# h = (a | b) & (~c | m.IthVar(3)) & (~m.IthVar(4) | ~m.IthVar(5)) & (m.IthVar(6) | ~m.IthVar(7)) & m.IthVar(8)

h = m.And(m.And(m.And(m.Or(a, b),
                      m.Or(not_c, m.IthVar(3))),
                m.And(m.Or(m.Not(m.IthVar(4)),
                           m.Not(m.IthVar(5))),
                      m.Or(m.IthVar(6), m.Not(m.IthVar(7))))),
          m.IthVar(8))

#
# Create the DdTlcInfo object by calling
#
tlc = m.FindTwoLiteralClauses(h)
#
# Read the clauses by calling ReadIthClause on the TlcInfo struct
# This returns the clauses as 3-tuples -- the first member is 1 if a valid clause is returned,
# and 0 if the index passed to the func was too large. The next 2 members are tuples encoding (variable,phase)
# phase = 0 is uncomplemented, phase = 1 is complemented. For one literal clauses, the second variable is set to -1
#
i=0
cl = tlc.ReadIthClause(i)
while cl[0] != 0:
    print(cl[1:])
    i += 1
    cl = tlc.ReadIthClause(i)
