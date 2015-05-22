////////////////////////////////////
//
// Wrapper for functions that naturally appear as methods of DdNode
//
////////////////////////////////////

%{
#ifndef FROM_PYCUDDI
#error Use only from pycudd.i. Make sure to define FROM_PYCUDDI!
#endif
%}

struct DdNode { };
%extend DdNode {
%feature("autodoc","1");
%pythoncode %{
def __deepcopy__(self,memo):
  return self
__doc__ = "This class wraps around the basic DdNode. The methods defined by this class take the default manager as their DdManager option (if needed) and provide themselves as the first DdNode option that those functions require, as indicated by the self argument. These functions may be found in ddnode.i."
%}

  DdNode() {
   return NULL;
  }

  ~DdNode() {
  }
  /* Generator stuff -- added by Aravind */
  /* For all the funcs FirstXXX, NextXXX, return value is 1 if a valid node came out, 0 if not             */
  /* This value can be used to determine whether to raise a StopIteration exception or not (cf. dditer.py) */
  /* Typemap and global magic is used to return the DdNode/cube represented as ints                        */
  /* A global variable XXX_iter is used to store the pointer that the generator returns to us. Note that we*/
  /* don't need to malloc the DdNode or ints, but we do malloc and extern the DdNode** and int**           */
  /* The typemaps defined in utils.i  point CUDD to use these globals, and return the values put there     */

  int FirstCube(DdGen *gen, DdManager* mgr, int **dum_cube) {
    if (Cudd_IsGenEmpty(gen)) { /* Happens if you call the generator on Logic Zero */ return 0; }
    return 1;
  }

  int NextCube(DdGen *gen, DdManager* mgr, int **dum_cube) {
    CUDD_VALUE_TYPE val;
    int tmp;
    if (!gen) { /* Something is seriously wrong ! */ assert(0); }
    if (Cudd_IsGenEmpty(gen)) { // We should never hit this -- raise StopIteration in python earlier.
      return 0;
    }
    else { // Have a cube to return
      tmp = Cudd_NextCube(gen, dum_cube, &val);
      if (tmp <= 0) { // The freakin' generator is already empty ...
	assert(Cudd_IsGenEmpty(gen));
	return 0;
      }
      return 1;
    }
  }

  int FirstNode(DdGen *gen, DdNode **dum_y) {
    if (Cudd_IsGenEmpty(gen)) { /* Happens if you call the generator on Logic Zero */ return 0; }
    return 1;
  }

  int NextNode(DdGen *gen, DdNode **dum_y) {
    int tmp;
    if (!gen) { /* Something is seriously wrong ! */ assert(gen); }
    if (Cudd_IsGenEmpty(gen)) { // We should never hit this -- raise StopIteration in python earlier.
      return 0;
    }
    else { // Have a cube to return
      tmp = Cudd_NextNode(gen, dum_y);
      if (tmp <= 0) { // The freakin' generator is already empty ...
	assert(Cudd_IsGenEmpty(gen));
	return 0;
      }
      return 1;
    }
  } // NextNode

  double CountPathsToNonZero() { return  Cudd_CountPathsToNonZero(self); }

  int NodeReadIndex () { return Cudd_NodeReadIndex(self); }
  int IsNonConstant() { return Cudd_IsNonConstant(self); }
  int DagSize() { return Cudd_DagSize(self); }
  int EstimateCofactorSimple(int i) { return Cudd_EstimateCofactorSimple(self, i); }
  double CountPath() { return Cudd_CountPath(self); }
  int CountLeaves() { return Cudd_CountLeaves(self); }

  int IsConstant() { return Cudd_IsConstant(self); }
  %newobject Not;   DdNode * Not() { DdNode* result = Cudd_Not(self); Cudd_Ref(result); return result;}
  %newobject NotCond;   DdNode * NotCond(int c) { DdNode* result = Cudd_NotCond(self, c); Cudd_Ref(result); return result;}
  %newobject Regular;   DdNode * Regular() { DdNode* result = Cudd_Regular(self); Cudd_Ref(result); return result;}
  %newobject Complement;   DdNode * Complement() { DdNode* result = Cudd_Complement(self); Cudd_Ref(result); return result;}
  int IsComplement() { return Cudd_IsComplement(self); }
  %newobject T;   DdNode * T() { DdNode* result = Cudd_T(self); Cudd_Ref(result); return result;}
  %newobject E;   DdNode * E() { DdNode* result = Cudd_E(self); Cudd_Ref(result); return result;}
  double V() { return Cudd_V(self); }

  int zddDagSize(DdNode *p_node) { return Cudd_zddDagSize(self); }

  /* Added to DdNode */
  int __hash__ () {
    return (long int)(self);
  }

  int __int__ () {
    return (long int)(self);
  }


  bool __cmp__ (DdNode* other) {
    if (self == other) return FALSE;
    return TRUE;
  }

  bool __eq__(DdNode* other) {
    return self == other ? TRUE : FALSE;
  }

  bool __ne__(DdNode* other) {
    return self != other ? TRUE : FALSE;
  }

  int __len__() {
    return Cudd_DagSize(self);
  }

  int SizeOf() {
    return sizeof(*self);
  }

};

#if CUDDVER >= 0x020400
// NodePair is a helper struct used for prime enumeration
%{
struct NodePair {
  DdNode * lower;
  DdNode * upper;
};
%}

struct NodePair { };

%extend NodePair {
%pythoncode %{
def __iter__(self):
  global iter_meth
  if iter_meth != 2:
    print "Can only enumerate primes for a NodePair. Setting iter_meth == 2 and proceeding"
    iter_meth == 2
  return ForeachPrimeIterator(self)
__doc__="This is used to provide the functionality of prime enumeration in CUDD 2.4.0. Create the NodePair by passing the DdNodes for lower and upper to the constructor. Once that is done, you can iterate over the primes of the NodePair using the Python for statement. There is no need to do this if you are interested in the primes of a simple DdNode -- the package automatically creates the NodePair and destroys it in that case."

%}

  NodePair(DdNode *lwr, DdNode *upr) {
    NodePair *res;
    res = (NodePair *) malloc(sizeof(NodePair));
    res->lower = lwr;
    res->upper = upr;
    return res;
  }

  ~NodePair() {
    free(self);
  }

  // Not expected to be used directly -- use a for loop
%newobject LOWER;  DdNode *LOWER() { return self->lower; }
%newobject UPPER;  DdNode *UPPER() { return self->upper; }

  int FirstPrime(DdGen *gen, DdManager* mgr, int **dum_cube) {
    if (Cudd_IsGenEmpty(gen)) { /* Happens if you call the generator on Logic Zero */ return 0; }
    return 1;
  }

  int NextPrime(DdGen *gen, DdManager* mgr, int **dum_cube) {
    int tmp;
    if (!gen) { /* Something is seriously wrong ! */ assert(0); }
    if (Cudd_IsGenEmpty(gen)) { // We should never hit this -- raise StopIteration in python earlier.
      return 0;
    }
    else { // Have a cube to return
      tmp = Cudd_NextPrime(gen, dum_cube);
      if (tmp <= 0) { // The freakin' generator is already empty ...
	assert(Cudd_IsGenEmpty(gen));
	return 0;
      }
      return 1;
    }
  }

};
#endif
