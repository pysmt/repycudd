%{
#ifndef FROM_PYCUDDI
#error Use only from pycudd.i. Make sure to define FROM_PYCUDDI!
#endif
class CuddFatalError {
public:
  CuddFatalError(string err);
  string er;
};

 CuddFatalError::CuddFatalError(string err) {
   er = err;
 }

%}
%{
void KillAllNodes(DdManager * self) {
#ifdef PYCUDD_DEBUG
  cerr << "Entering kill all nodes" << endl;
#endif
  int size;
  int i, j;
  int remain;	/* the expected number of remaining references to one */
  DdNodePtr *nodelist;
  DdNode *node;
  DdNode *Node;
  DdNode *sentinel = &(self->sentinel);
  DdSubtable *subtable;
  int count = 0;
  int badrefs = Cudd_CheckZeroRef(self);
  int collected = 0;
  int zeroed = 0;
  int ord, index;
  if (!badrefs) {
    cerr << "All nodes have already been disposed of correctly!" << endl;
    return;
  }
#ifdef PYCUDD_DEBUG
  cerr << badrefs << " uncollected nodes" << endl;
#endif
  /* First look at the BDD/ADD subtables. */
  remain = 1; /* reference from the manager */
  size = self->size;
  remain += 2 * size;	/* reference from the BDD projection functions */

  for (i = 0; i < size; i++) {
    subtable = &(self->subtables[i]);
    nodelist = subtable->nodelist;
    for (j = 0; (unsigned) j < subtable->slots; j++) {
      node = nodelist[j];
      while (node != sentinel) {
	if (node->ref != 0 && node->ref != DD_MAXREF) {
	  index = (int) node->index;
	  if (node != self->vars[index]) {
	    Node = Cudd_Regular(node);   // Do I need to do this?
#ifdef PYCUDD_DEBUG
	    cerr << "Node: " << hex << node << " Refs: " << node->ref << endl;
#endif
	    Node->ref = 0;
	    self->dead++;
	    ord = self->perm[Node->index];
	    self->subtables[ord].dead++;
	    zeroed++;
	  } else {
	    if (node->ref != 1) {
	      node->ref = 1;
	      zeroed++;      // Reducing a projection funcs refs to 1 preps it for killing
	    }
	  }
	}
	node = node->next;
      }
    }
  }

  /* Then look at the ZDD subtables. */
  size = self->sizeZ;
  if (size) /* references from ZDD universe */
    remain += 2;

  for (i = 0; i < size; i++) {
    subtable = &(self->subtableZ[i]);
    nodelist = subtable->nodelist;
    for (j = 0; (unsigned) j < subtable->slots; j++) {
      node = nodelist[j];
      while (node != NULL) {
	if (node->ref != 0 && node->ref != DD_MAXREF) {
	  index = (int) node->index;
	  if (node == self->univ[self->permZ[index]]) {
	    if (node->ref > 2) {
	      node->ref = 2;   // Playing safe ... set it to values that CheckZeroRefs will feel happy about
	      zeroed++;
	    }
	  } else {
	    node->ref = 0;
	    zeroed++;
	    self->dead++;
	    ord = self->permZ[Node->index];
	    self->subtableZ[ord].dead++;
	  }
	}
	node = node->next;
      }
    }
  }

  /* Now examine the constant table. Plusinfinity, minusinfinity, and
  ** zero are referenced by the manager. One is referenced by the
  ** manager, by the ZDD universe, and by all projection functions.
  ** All other nodes should have no references.
  */

  nodelist = self->constants.nodelist;
  for (j = 0; (unsigned) j < self->constants.slots; j++) {
    node = nodelist[j];
    while (node != NULL) {
      if (node->ref != 0 && node->ref != DD_MAXREF) {
	if (node == self->one) {
	  node->ref = remain;
	}
	else if (node == self->zero || node == self->plusinfinity || node == self->minusinfinity) {
	  if (node->ref != 1) {
	    node->ref = 1;
	  }
	}
      }
      node = node->next;
    }
  }

  collected = cuddGarbageCollect(self, 1);
#ifdef PYCUDD_DEBUG
  cerr << "Exiting kill all nodes" << endl << "Zeroed refs for " << zeroed <<  " nodes.\nGarbage collection freed a total of " << collected << " nodes" << endl;
  assert(!Cudd_CheckZeroRef(self)); // Better be zero!!
#endif
}
%}

struct DdManager { };

%extend DdManager {
%feature("autodoc","1");
%pythoncode %{
  __doc__ = "This class wraps around the DdManager. The methods defined by this class provide themselves as the DdManager option (if needed)."
%}
%newobject DdManager;  DdManager(unsigned int numVars = 0, unsigned int numVarsZ = 0, unsigned int numSlots = CUDD_UNIQUE_SLOTS, unsigned int cacheSize = CUDD_CACHE_SLOTS, unsigned long maxMemory = 0) {
    return Cudd_Init(numVars,numVarsZ,numSlots,cacheSize,maxMemory);
  }

  ~DdManager() {
#ifdef PYCUDD_DEBUG
    cerr << "About to get rid of manager" << endl;
#endif
    int retval = Cudd_CheckZeroRef(self);
    if (!retval) {
#ifdef PYCUDD_DEBUG
cerr << "Quitting manager" << endl;
#endif
    } else {
#ifdef PYCUDD_DEBUG
      cerr << retval << " unexpected non-zero reference counts" << endl;
#endif
#ifdef TESTING
      KillAllNodes(self);
#endif
    }
    Cudd_Quit(self);
  }

  // This takes a long int representing the address of a DdNode and
  // derefs it. Use with caution!!
  void KillNode(long int num) {
#ifdef PYCUDD_DEBUG
    cerr << "Derefing " << hex << num << endl;
#endif
    Cudd_RecursiveDeref(self, (DdNode *) num);
  }

  /* CUDD Manager functions */

  /* Start wrapped by Aravind */
  int IsPsVar(int index) { return Cudd_bddIsPsVar(self, index); }
  int IsNsVar(int index) {  return Cudd_bddIsNsVar(self, index);  }
  int SetPsVar(int index) { return Cudd_bddSetPsVar(self, index);  }
  int SetNsVar(int index) { return Cudd_bddSetNsVar(self, index);  }
  int SetPairIndex(int index, int pairIndex) { return Cudd_bddSetPairIndex(self,index,pairIndex);  }
  int ReadPairIndex(int index) { return Cudd_bddReadPairIndex(self,index); }
  int SetVarToBeGrouped(int index)  { return Cudd_bddSetVarToBeGrouped(self,index); }
  int SetVarHardGroup(int index)    { return Cudd_bddSetVarHardGroup(self,index); }
  int ResetVarToBeGrouped(int index){ return Cudd_bddResetVarToBeGrouped(self,index); }
  int IsVarToBeGrouped(int index)   { return Cudd_bddIsVarToBeGrouped(self,index); }
  int IsVarHardGroup(int index)     { return Cudd_bddIsVarHardGroup(self,index); }
  int SetVarToBeUngrouped (int index) { return Cudd_bddSetVarToBeUngrouped(self,index); }
  int IsVarToBeUngrouped  (int index) { return Cudd_bddIsVarToBeUngrouped(self,index); }
  int SetPiVar(int index) { return Cudd_bddSetPiVar(self,index); }
  int IsPiVar (int index) { return Cudd_bddIsPiVar(self,index); }
  int BindVar   (int index) { return Cudd_bddBindVar(self,index); }
  int UnbindVar (int index) { return Cudd_bddUnbindVar(self,index); }
  int VarIsBound (int index) { return Cudd_bddVarIsBound(self,index); }
  double ReadMaxGrowthAlternate() { return Cudd_ReadMaxGrowthAlternate(self); }
  void SetMaxGrowthAlternate (double mg) { Cudd_SetMaxGrowthAlternate(self,mg); }
  int ReadReorderingCycle () { return Cudd_ReadReorderingCycle(self); }
  void SetReorderingCycle (int cycle) { Cudd_SetReorderingCycle(self,cycle);}
  int PrintCover(DdNode *l, DdNode *u) { return Cudd_bddPrintCover(self, l, u); }
  unsigned int Prime(unsigned int p) { return Cudd_Prime(p); }
  int __len__() { return Cudd_ReadSize(self); }
%exception{
    try {
      $function
    } catch (CuddFatalError x) {
      PyErr_SetString(PyExc_RuntimeError,x.er.c_str());
      return NULL;
    }
}

  // Disallow all negative indices when using __getitem__
  %newobject __getitem__;
%newobject __getitem__;   DdNode * __getitem__(int i) {
    if (i < 0) throw CuddFatalError("CUDD Fatal error: Negative argument to bddIthVar.");
    DdNode * result = Cudd_bddIthVar(self, i);
    Cudd_Ref(result);
    return result;
  }
  %exception;
  /* End wrapped by Aravind */

  bool __eq__(DdManager* other) {
    return self == other ? TRUE : FALSE;
  }

  bool __ne__(DdManager* other) {
    return self != other ? TRUE : FALSE;
  }


%newobject addNewVar;  DdNode *  addNewVar() { DdNode* result = Cudd_addNewVar(self); Cudd_Ref(result); return result; }
%newobject addNewVarAtLevel;  DdNode *  addNewVarAtLevel( int level) { DdNode* result = Cudd_addNewVarAtLevel(self,  level); Cudd_Ref(result); return result; }
%newobject NewVar;  DdNode *  NewVar() { DdNode* result = Cudd_bddNewVar(self); Cudd_Ref(result); return result; }
%newobject NewVarAtLevel;  DdNode *  NewVarAtLevel( int level) { DdNode* result = Cudd_bddNewVarAtLevel(self,  level); Cudd_Ref(result); return result; }
%newobject addIthVar;  DdNode *  addIthVar( int i) { DdNode* result = Cudd_addIthVar(self,  i); Cudd_Ref(result); return result; }
%newobject IthVar;  DdNode *  IthVar( int i) { DdNode* result = Cudd_bddIthVar(self,  i); Cudd_Ref(result); return result; }
%newobject zddIthVar;  DdNode *  zddIthVar( int i) { DdNode* result = Cudd_zddIthVar(self,  i); Cudd_Ref(result); return result; }
  int  zddVarsFromBddVars( int multiplicity) { return Cudd_zddVarsFromBddVars(self,  multiplicity); }
%newobject addConst;  DdNode *  addConst( CUDD_VALUE_TYPE c) { DdNode* result = Cudd_addConst(self, c); Cudd_Ref(result); return result; }
  void  AutodynEnable( int method) { Cudd_AutodynEnable(self, (Cudd_ReorderingType) method); }
  void  AutodynDisable() { Cudd_AutodynDisable(self); }
  %apply int * OUTPUT { int * dum_status };
  int  ReorderingStatus( int *dum_status) { return Cudd_ReorderingStatus(self, (Cudd_ReorderingType*) dum_status); }
  void  AutodynEnableZdd( int method) { Cudd_AutodynEnableZdd(self, (Cudd_ReorderingType) method); }
  void  AutodynDisableZdd() { Cudd_AutodynDisableZdd(self); }
  int  ReorderingStatusZdd( int *dum_status) { return Cudd_ReorderingStatusZdd(self, (Cudd_ReorderingType*) dum_status); }
  %clear int * dum_status;
  int  zddRealignmentEnabled() { return Cudd_zddRealignmentEnabled(self); }
  void  zddRealignEnable() { Cudd_zddRealignEnable(self); }
  void  zddRealignDisable() { Cudd_zddRealignDisable(self); }
  int  RealignmentEnabled() { return Cudd_bddRealignmentEnabled(self); }
  void  RealignEnable() { Cudd_bddRealignEnable(self); }
  void  RealignDisable() { Cudd_bddRealignDisable(self); }
%newobject ReadOne;  DdNode *  ReadOne() { DdNode* result = Cudd_ReadOne(self); Cudd_Ref(result); return result; }
%newobject ReadZddOne;  DdNode *  ReadZddOne( int i) { DdNode* result = Cudd_ReadZddOne(self,  i); Cudd_Ref(result); return result; }
%newobject ReadZero;  DdNode *  ReadZero() { DdNode* result = Cudd_ReadZero(self); Cudd_Ref(result); return result; }
%newobject ReadLogicZero;  DdNode *  ReadLogicZero() { DdNode* result = Cudd_ReadLogicZero(self); Cudd_Ref(result); return result; }
%newobject ReadPlusInfinity;   DdNode *  ReadPlusInfinity() { DdNode* result = Cudd_ReadPlusInfinity(self); Cudd_Ref(result); return result; }
%newobject ReadMinusInfinity;   DdNode *  ReadMinusInfinity() { DdNode* result = Cudd_ReadMinusInfinity(self); Cudd_Ref(result); return result; }
%newobject ReadBackground;   DdNode *  ReadBackground() { DdNode* result = Cudd_ReadBackground(self); Cudd_Ref(result); return result; }
  unsigned int  ReadCacheSlots() { return Cudd_ReadCacheSlots(self); }
  double  ReadCacheUsedSlots() { return Cudd_ReadCacheUsedSlots(self); }
  double  ReadCacheLookUps() { return Cudd_ReadCacheLookUps(self); }
  double  ReadCacheHits() { return Cudd_ReadCacheHits(self); }
  double  ReadRecursiveCalls() { return Cudd_ReadRecursiveCalls(self); }
  unsigned int  ReadMinHit() { return Cudd_ReadMinHit(self); }
  void  SetMinHit( unsigned int hr) { Cudd_SetMinHit(self,   hr); }
  unsigned int  ReadLooseUpTo() { return Cudd_ReadLooseUpTo(self); }
  void  SetLooseUpTo( unsigned int lut) { Cudd_SetLooseUpTo(self,   lut); }
  unsigned int  ReadMaxCache() { return Cudd_ReadMaxCache(self); }
  unsigned int  ReadMaxCacheHard() { return Cudd_ReadMaxCacheHard(self); }
  void  SetMaxCacheHard( unsigned int mc) { Cudd_SetMaxCacheHard(self,   mc); }
  int  ReadSize() { return Cudd_ReadSize(self); }
  int  ReadZddSize() { return Cudd_ReadZddSize(self); }
  unsigned int  ReadSlots() { return Cudd_ReadSlots(self); }
  double  ReadUsedSlots() { return Cudd_ReadUsedSlots(self); }
  double  ExpectedUsedSlots() { return Cudd_ExpectedUsedSlots(self); }
  unsigned int  ReadKeys() { return Cudd_ReadKeys(self); }
  unsigned int  ReadDead() { return Cudd_ReadDead(self); }
  unsigned int  ReadMinDead() { return Cudd_ReadMinDead(self); }
  int  ReadReorderings() { return Cudd_ReadReorderings(self); }
  long  ReadReorderingTime() { return Cudd_ReadReorderingTime(self); }
  int  ReadGarbageCollections() { return Cudd_ReadGarbageCollections(self); }
  long  ReadGarbageCollectionTime() { return Cudd_ReadGarbageCollectionTime(self); }
  int GarbageCollect( int clearCache ) { return cuddGarbageCollect(self,clearCache); }
  double  ReadNodesFreed() { return Cudd_ReadNodesFreed(self); }
  double  ReadNodesDropped() { return Cudd_ReadNodesDropped(self); }
  double  ReadUniqueLookUps() { return Cudd_ReadUniqueLookUps(self); }
  double  ReadUniqueLinks() { return Cudd_ReadUniqueLinks(self); }
  int  ReadSiftMaxVar() { return Cudd_ReadSiftMaxVar(self); }
  void  SetSiftMaxVar( int smv) { Cudd_SetSiftMaxVar(self,  smv); }
  int  ReadSiftMaxSwap() { return Cudd_ReadSiftMaxSwap(self); }
  void  SetSiftMaxSwap( int sms) { Cudd_SetSiftMaxSwap(self,  sms); }
  double  ReadMaxGrowth() { return Cudd_ReadMaxGrowth(self); }
  void  SetMaxGrowth( double mg) { Cudd_SetMaxGrowth(self,  mg); }
  MtrNode *  ReadTree() { return Cudd_ReadTree(self); }
  void  SetTree( MtrNode *tree) { Cudd_SetTree(self, tree); }
  void  FreeTree() { Cudd_FreeTree(self); }
  MtrNode *  ReadZddTree() { return Cudd_ReadZddTree(self); }
  void  SetZddTree( MtrNode *tree) { Cudd_SetZddTree(self, tree); }
  void  FreeZddTree() { Cudd_FreeZddTree(self); }
  int  ReadPerm( int i) { return Cudd_ReadPerm(self,  i); }
  int  ReadPermZdd( int i) { return Cudd_ReadPermZdd(self,  i); }
  int  ReadInvPerm( int i) { return Cudd_ReadInvPerm(self,  i); }
  int  ReadInvPermZdd( int i) { return Cudd_ReadInvPermZdd(self,  i); }
%newobject ReadVars;   DdNode *  ReadVars( int i) { DdNode* result = Cudd_ReadVars(self,  i); Cudd_Ref(result); return result; }
  CUDD_VALUE_TYPE  ReadEpsilon() { return Cudd_ReadEpsilon(self); }
  void  SetEpsilon( CUDD_VALUE_TYPE ep) { Cudd_SetEpsilon(self, ep); }
  Cudd_AggregationType  ReadGroupcheck() { return Cudd_ReadGroupcheck(self); }
  void  SetGroupcheck( Cudd_AggregationType gc) { Cudd_SetGroupcheck(self, gc); }
  int  GarbageCollectionEnabled() { return Cudd_GarbageCollectionEnabled(self); }
  void  EnableGarbageCollection() { Cudd_EnableGarbageCollection(self); }
  void  DisableGarbageCollection() { Cudd_DisableGarbageCollection(self); }
  int  DeadAreCounted() { return Cudd_DeadAreCounted(self); }
  void  TurnOnCountDead() { Cudd_TurnOnCountDead(self); }
  void  TurnOffCountDead() { Cudd_TurnOffCountDead(self); }
  int  ReadRecomb() { return Cudd_ReadRecomb(self); }
  void  SetRecomb( int recomb) { Cudd_SetRecomb(self,  recomb); }
  int  ReadSymmviolation() { return Cudd_ReadSymmviolation(self); }
  void  SetSymmviolation( int symmviolation) { Cudd_SetSymmviolation(self,  symmviolation); }
  int  ReadArcviolation() { return Cudd_ReadArcviolation(self); }
  void  SetArcviolation( int arcviolation) { Cudd_SetArcviolation(self,  arcviolation); }
  int  ReadPopulationSize() { return Cudd_ReadPopulationSize(self); }
  void  SetPopulationSize( int populationSize) { Cudd_SetPopulationSize(self,  populationSize); }
  int  ReadNumberXovers() { return Cudd_ReadNumberXovers(self); }
  void  SetNumberXovers( int numberXovers) { Cudd_SetNumberXovers(self,  numberXovers); }
  long  ReadMemoryInUse() { return Cudd_ReadMemoryInUse(self); }
  int  PrintInfo(FILE *fp) { return Cudd_PrintInfo(self, fp); }
  long  ReadPeakNodeCount() { return Cudd_ReadPeakNodeCount(self); }
  int  ReadPeakLiveNodeCount() { return Cudd_ReadPeakLiveNodeCount(self); }
  long  ReadNodeCount() { return Cudd_ReadNodeCount(self); }
  long  zddReadNodeCount() { return Cudd_zddReadNodeCount(self); }
  int  EnableReorderingReporting() { return Cudd_EnableReorderingReporting(self); }
  int  DisableReorderingReporting() { return Cudd_DisableReorderingReporting(self); }
  int  ReorderingReporting() { return Cudd_ReorderingReporting(self); }
  Cudd_ErrorType  ReadErrorCode() { return Cudd_ReadErrorCode(self); }
  void  ClearErrorCode() { Cudd_ClearErrorCode(self); }
  FILE *  ReadStdout() { return Cudd_ReadStdout(self); }
  void  SetStdout( FILE *fp) { Cudd_SetStdout(self, fp); }
  FILE *  ReadStderr() { return Cudd_ReadStderr(self); }
  void  SetStderr( FILE *fp) { Cudd_SetStderr(self, fp); }
  unsigned int  ReadNextReordering() { return Cudd_ReadNextReordering(self); }
  double  ReadSwapSteps() { return Cudd_ReadSwapSteps(self); }
  unsigned int  ReadMaxLive() { return Cudd_ReadMaxLive(self); }
  void  SetMaxLive( unsigned int maxLive) { Cudd_SetMaxLive(self,   maxLive); }
  long  ReadMaxMemory() { return Cudd_ReadMaxMemory(self); }
  void  SetMaxMemory( long maxMemory) { Cudd_SetMaxMemory(self,  maxMemory); }
  void  SetNextReordering( unsigned int next) { Cudd_SetNextReordering(self,   next); }
  int  DebugCheck() { return Cudd_DebugCheck(self); }
  int  CheckKeys() { return Cudd_CheckKeys(self); }
  MtrNode * MakeTreeNode( unsigned int low, unsigned int size, unsigned int type) { return Cudd_MakeTreeNode(self,   low,   size,   type); }
  int  PrintLinear() { return Cudd_PrintLinear(self); }
  int  ReadLinear( int x, int y) { return Cudd_ReadLinear(self,  x,  y); }
  int  CheckZeroRef() { return Cudd_CheckZeroRef(self); }
  int  ReduceHeap( int heuristic, int minsize) { return Cudd_ReduceHeap(self, (Cudd_ReorderingType) heuristic,  minsize); }
  int  ShuffleHeap( IntArray *permutation) { return Cudd_ShuffleHeap(self,  permutation->vec); }
  void  SymmProfile( int lower, int upper) { Cudd_SymmProfile(self,  lower,  upper); }
%newobject IndicesToCube;   DdNode *  IndicesToCube( IntArray *array, int n) { DdNode* result = Cudd_IndicesToCube(self,  array->vec,  n); Cudd_Ref(result); return result; }
  double  AverageDistance() { return Cudd_AverageDistance(self); }
  MtrNode *  MakeZddTreeNode( unsigned int low, unsigned int size, unsigned int type) { return Cudd_MakeZddTreeNode(self,   low,   size,   type); }
  void  zddPrintSubtable() { Cudd_zddPrintSubtable(self); }
  int  zddReduceHeap( int heuristic, int minsize) { return Cudd_zddReduceHeap(self, (Cudd_ReorderingType) heuristic,  minsize); }
  int  zddShuffleHeap( IntArray *permutation) { return Cudd_zddShuffleHeap(self,  permutation->vec); }
  void  zddSymmProfile( int lower, int upper) { Cudd_zddSymmProfile(self,  lower,  upper); }
%newobject BddToAdd;   DdNode *  BddToAdd( DdNode *B) { DdNode* result = Cudd_BddToAdd(self,  B); Cudd_Ref(result); return result; }
%newobject addBddPattern;   DdNode *  addBddPattern( DdNode *f) { DdNode* result = Cudd_addBddPattern(self,  f); Cudd_Ref(result); return result; }
%newobject addBddThreshold;   DdNode *  addBddThreshold( DdNode *f, CUDD_VALUE_TYPE value) { DdNode* result = Cudd_addBddThreshold(self,  f, value); Cudd_Ref(result); return result; }
%newobject addBddStrictThreshold;   DdNode *  addBddStrictThreshold( DdNode *f, CUDD_VALUE_TYPE value) { DdNode* result = Cudd_addBddStrictThreshold(self,  f, value); Cudd_Ref(result); return result; }
%newobject addBddInterval;   DdNode *  addBddInterval( DdNode *f, CUDD_VALUE_TYPE lower, CUDD_VALUE_TYPE upper) { DdNode* result = Cudd_addBddInterval(self,  f, lower, upper); Cudd_Ref(result); return result; }
%newobject addBddIthBit;   DdNode *  addBddIthBit( DdNode *f, int bit) { DdNode* result = Cudd_addBddIthBit(self,  f,  bit); Cudd_Ref(result); return result; }
%newobject zddPortFromBdd;   DdNode *  zddPortFromBdd( DdNode *B) { DdNode* result = Cudd_zddPortFromBdd(self,  B); Cudd_Ref(result); return result; }
%newobject zddPortToBdd;   DdNode *  zddPortToBdd( DdNode *f) { DdNode* result = Cudd_zddPortToBdd(self,  f); Cudd_Ref(result); return result; }
%newobject MakeBddFromZddCover;   DdNode *  MakeBddFromZddCover( DdNode *node) { DdNode* result = Cudd_MakeBddFromZddCover(self,  node); Cudd_Ref(result); return result; }
  void PrintVersion(FILE *fp) { Cudd_PrintVersion(fp); }
  long Random() { return Cudd_Random(); }
  void Srandom( long seed) { Cudd_Srandom(seed); }
  void OutOfMem(long size) {  Cudd_OutOfMem(size); }
%newobject Transfer;   DdNode * Transfer( DdManager *ddDestination, DdNode *f) { DdNode* result = Cudd_bddTransfer(self, ddDestination, f); Cudd_Ref(result); return result; }

%newobject CubeArrayToBdd;   DdNode *  CubeArrayToBdd( IntArray *y) { DdNode* result = Cudd_CubeArrayToBdd(self, y->vec); Cudd_Ref(result); return result; }
  int  SetVarMap( DdArray *x, DdArray *y, int n) { return Cudd_SetVarMap(self,  x->vec,  y->vec,  n); }
%newobject ComputeCube;   DdNode *  ComputeCube( DdArray *vars, IntArray *phase, int n) { DdNode* result = Cudd_bddComputeCube(self,  vars->vec,  phase->vec,  n); Cudd_Ref(result); return result; }
  int  zddDumpDot( int n, DdArray *f, char **inames, char **onames, FILE *fp) { return Cudd_zddDumpDot(self,  n,  f->vec, inames, onames, fp); }
  int  DumpBlif( int n, DdArray *f, char **inames, char **onames, char *mname, FILE *fp, int mv) { return Cudd_DumpBlif(self,  n,  f->vec, inames, onames, mname, fp, mv); }
  int  DumpBlifBody( int n, DdArray *f, char **inames, char **onames, FILE *fp, int mv) { return Cudd_DumpBlifBody(self,  n,  f->vec, inames, onames, fp, mv); }
  int  DumpDot( int n, DdArray *f, char **inames, char **onames, FILE *fp) { return Cudd_DumpDot(self,  n,  f->vec,  inames,  onames, fp); }
  int  DumpDaVinci( int n, DdArray *f, char **inames, char **onames, FILE *fp) { return Cudd_DumpDaVinci(self,  n,  f->vec,  inames,  onames, fp); }
  int  DumpDDcal( int n, DdArray *f, char **inames, char **onames, FILE *fp) { return Cudd_DumpDDcal(self,  n,  f->vec,  inames,  onames, fp); }
  int  DumpFactoredForm( int n, DdArray *f, char **inames, char **onames, FILE *fp) { return Cudd_DumpFactoredForm(self,  n,  f->vec,  inames,  onames, fp); }

  /*  DDDmp Functions */
  int ArrayLoad( int rootmatchmode, char **rootmatchnames, int varmatchmode, char **varmatchnames, IntArray *varmatchauxids, IntArray *varcomposeids, int mode, char *filename, FILE *fp, DdArray *pproots) { return Dddmp_cuddBddArrayLoad( self, (Dddmp_RootMatchType) rootmatchmode, rootmatchnames, (Dddmp_VarMatchType) varmatchmode, varmatchnames, (int *) ( varmatchauxids ? varmatchauxids->vec : NULL), (int *) ( varcomposeids ? varcomposeids->vec : NULL), mode, filename, fp, &(pproots->vec)); }
  int ArrayStore( char *ddname, DdArray *roots, char **rootnames, char **varnames, IntArray *auxids, int mode, int varinfo, char *filename, FILE *fp) { return Dddmp_cuddBddArrayStore(self, ddname, roots->sz, roots->vec, rootnames, varnames, (int *) ( auxids ? auxids->vec : NULL), mode, (Dddmp_VarInfoType) varinfo, filename, fp); }
%newobject BddLoad;   DdNode *BddLoad( int varmatchmode, char **varmatchnames, IntArray *varmatchauxids, IntArray *varcomposeids, int mode, char *filename, FILE *fp) { return Dddmp_cuddBddLoad( self, (Dddmp_VarMatchType) varmatchmode, varmatchnames, (int *) ( varmatchauxids ? varmatchauxids->vec : NULL), (int *) ( varcomposeids ? varcomposeids->vec : NULL), mode, filename, fp); }
  int BddStore( char *ddname, DdNode *f, char **varnames, IntArray *auxids, int mode, int varinfo, char *fname, FILE *fp) { return Dddmp_cuddBddStore( self, ddname, f, varnames, (int *) (auxids ? auxids->vec : NULL), mode, (Dddmp_VarInfoType) varinfo, fname, fp); }
  int Bin2Text( char *filein, char *fileout) { return Dddmp_Bin2Text( filein, fileout); }
  int DisplayBinary( char *filein, char *fileout) { return Dddmp_cuddBddDisplayBinary( filein, fileout); }
  int Text2Bin( char *filein, char *fileout) { return Dddmp_Text2Bin( filein, fileout); }


  int  VectorSupportSize( DdArray *F, int n) { return Cudd_VectorSupportSize(self,  F->vec,  n); }
  int  ClassifySupport( DdNode *f, DdNode *g, DdArray *common, DdArray *onlyF, DdArray *onlyG) { return Cudd_ClassifySupport(self,  f,  g,  common->vec,  onlyF->vec,  onlyG->vec); }
%newobject Xgty;  DdNode *  Xgty( int N, DdArray *z, DdArray *x, DdArray *y) { DdNode* result = Cudd_Xgty(self,  N,  z->vec,  x->vec,  y->vec); Cudd_Ref(result); return result; }
%newobject Xeqy;  DdNode *  Xeqy( int N, DdArray *x, DdArray *y) { DdNode* result = Cudd_Xeqy(self,  N,  x->vec,  y->vec); Cudd_Ref(result); return result; }
%newobject Dxygtdxz;  DdNode *  Dxygtdxz( int N, DdArray *x, DdArray *y, DdArray *z) { DdNode* result = Cudd_Dxygtdxz(self,  N,  x->vec,  y->vec,  z->vec); Cudd_Ref(result); return result; }
%newobject Dxygtdyz;  DdNode *  Dxygtdyz( int N, DdArray *x, DdArray *y, DdArray *z) { DdNode* result = Cudd_Dxygtdyz(self,  N,  x->vec,  y->vec,  z->vec); Cudd_Ref(result); return result; }
  int SharingSize(DdArray *nodeArray, int n) { return Cudd_SharingSize(nodeArray->vec, n); }
  int ReadIndex(int i) { return Cudd_ReadPerm(self,  i); }

  /* add code */
%newobject addPlus;   DdNode *  addPlus(DdArray *f, DdArray *g) { DdNode* result = Cudd_addPlus(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addTimes;   DdNode *  addTimes(DdArray *f, DdArray *g) { DdNode* result = Cudd_addTimes(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addThreshold;   DdNode *  addThreshold(DdArray *f, DdArray *g) { DdNode* result = Cudd_addThreshold(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addSetNZ;   DdNode *  addSetNZ(DdArray *f, DdArray *g) { DdNode* result = Cudd_addSetNZ(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addDivide;   DdNode *  addDivide(DdArray *f, DdArray *g) { DdNode* result = Cudd_addDivide(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addMinus;   DdNode *  addMinus(DdArray *f, DdArray *g) { DdNode* result = Cudd_addMinus(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addMinimum;   DdNode *  addMinimum(DdArray *f, DdArray *g) { DdNode* result = Cudd_addMinimum(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addMaximum;   DdNode *  addMaximum(DdArray *f, DdArray *g) { DdNode* result = Cudd_addMaximum(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addOneZeroMaximum;   DdNode *  addOneZeroMaximum(DdArray *f, DdArray *g) { DdNode* result = Cudd_addOneZeroMaximum(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addDiff;   DdNode *  addDiff(DdArray *f, DdArray *g) { DdNode* result = Cudd_addDiff(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addAgreement;   DdNode *  addAgreement(DdArray *f, DdArray *g) { DdNode* result = Cudd_addAgreement(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addOr;   DdNode *  addOr(DdArray *f, DdArray *g) { DdNode* result = Cudd_addOr(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addNand;   DdNode *  addNand(DdArray *f, DdArray *g) { DdNode* result = Cudd_addNand(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addNor;   DdNode *  addNor(DdArray *f, DdArray *g) { DdNode* result = Cudd_addNor(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addXor;   DdNode *  addXor(DdArray *f, DdArray *g) { DdNode* result = Cudd_addXor(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addXnor;   DdNode *  addXnor(DdArray *f, DdArray *g) { DdNode* result = Cudd_addXnor(self, f->vec,  g->vec); Cudd_Ref(result); return result; }
%newobject addWalsh;   DdNode *  addWalsh(DdArray *x, DdArray *y, int n) { DdNode* result = Cudd_addWalsh(self, x->vec,  y->vec,  n); Cudd_Ref(result); return result; }
%newobject addHamming;   DdNode *  addHamming(DdArray *xVars, DdArray *yVars, int nVars) { DdNode* result = Cudd_addHamming(self, xVars->vec,  yVars->vec,  nVars); Cudd_Ref(result); return result; }
%newobject addComputeCube;   DdNode *  addComputeCube(DdArray *vars, IntArray *phase, int n) { DdNode* result = Cudd_addComputeCube(self, vars->vec,  phase->vec,  n); Cudd_Ref(result); return result; }
%newobject addResidue;   DdNode * addResidue(int n, int m, int options, int top) { DdNode* result = Cudd_addResidue(self, n, m, options, top); Cudd_Ref(result); return result; }
%newobject addXeqy;   DdNode * addXeqy(int N, DdArray *x, DdArray *y) { DdNode* result = Cudd_addXeqy(self, N, x->vec, y->vec); Cudd_Ref(result); return result; }

  /* apa specific */
  int ApaNumberOfDigits(int binaryDigits) { return Cudd_ApaNumberOfDigits(binaryDigits); }
  DdApaNumber NewApaNumber(int digits) { return Cudd_NewApaNumber(digits); }
  void ApaCopy(int digits, DdApaNumber source, DdApaNumber dest) { return Cudd_ApaCopy(digits, source, dest); }
  DdApaDigit ApaAdd(int digits, DdApaNumber a, DdApaNumber b, DdApaNumber sum) { return Cudd_ApaAdd(digits, a, b, sum); }
  DdApaDigit ApaSubtract(int digits, DdApaNumber a, DdApaNumber b, DdApaNumber diff) { return Cudd_ApaSubtract(digits, a, b, diff); }
  DdApaDigit ApaShortDivision(int digits, DdApaNumber dividend, DdApaDigit divisor, DdApaNumber quotient) { return Cudd_ApaShortDivision(digits, dividend, divisor, quotient); }
  unsigned int ApaIntDivision(int  digits, DdApaNumber dividend, unsigned int  divisor, DdApaNumber  quotient) { return  Cudd_ApaIntDivision(digits, dividend, divisor, quotient); }
  void ApaShiftRight(int digits, DdApaDigit in_, DdApaNumber a, DdApaNumber b) { Cudd_ApaShiftRight(digits, in_, a, b); }
  void ApaSetToLiteral(int digits, DdApaNumber number, DdApaDigit literal) { Cudd_ApaSetToLiteral(digits, number, literal); }
  void ApaPowerOfTwo(int digits, DdApaNumber number, int power) { Cudd_ApaPowerOfTwo(digits, number, power); }
  int ApaCompare(int digitsFirst, DdApaNumber  first, int digitsSecond, DdApaNumber  second) { return  Cudd_ApaCompare(digitsFirst, first, digitsSecond, second); }
  int ApaCompareRatios(int digitsFirst, DdApaNumber firstNum, unsigned int firstDen, int digitsSecond, DdApaNumber secondNum, unsigned int secondDen) { return Cudd_ApaCompareRatios(digitsFirst, firstNum, firstDen, digitsSecond, secondNum, secondDen); }
  int ApaPrintHex(FILE *fp, int digits, DdApaNumber number) { return Cudd_ApaPrintHex(fp, digits, number); }
  int ApaPrintDecimal(FILE *fp, int digits, DdApaNumber number) { return Cudd_ApaPrintDecimal(fp, digits, number); }
  int ApaPrintExponential(FILE * fp, int  digits, DdApaNumber  number, int precision) { return Cudd_ApaPrintExponential(fp, digits, number, precision); }

  /* Added to DdManager */
  DdNode* One() {
    DdNode *result = Cudd_ReadOne(self);
    Cudd_Ref(result);
    return result;
  }

  DdNode* Zero() {
    DdNode *result = Cudd_ReadLogicZero(self);
    Cudd_Ref(result);
    return result;
  }

  int Sort (DdNode* leftnd, DdNode* rightnd) {
    return (Cudd_ReadPerm(self,Cudd_NodeReadIndex(rightnd)) - Cudd_ReadPerm(self,Cudd_NodeReadIndex(leftnd)));
  }
  int  PrintStdOut() { return Cudd_PrintInfo(self, stdout); }

  DdNode* StateCube( char* cube, int base, int offset, int scale ) {
  	DdNode *tmp;
	int length;
	int i;
	DdNode *result = Cudd_ReadOne(self);
	Cudd_Ref(result);

	length = strlen(cube);

	for (i = length; i>=0; i--) {
	  if (cube[i]=='1') {
	    tmp = Cudd_bddAnd(self,result,Cudd_bddIthVar(self,((i*scale)+offset+base)));
	    Cudd_Ref(tmp);
	    Cudd_RecursiveDeref(self,result);
	    result = tmp;
	  } else if (cube[i]=='0') {
	    tmp = Cudd_bddAnd(self,result,Cudd_Not(Cudd_bddIthVar(self,((i*scale)+offset+base))));
	    Cudd_Ref(tmp);
	    Cudd_RecursiveDeref(self,result);
	    result = tmp;
	  }
	}
	return result;
  }


  // Re-entrant methods for DDNode

#if CUDDVER >= 0x020400
  %newobject AndAbstractLimit;  DdNode * AndAbstractLimit(DdNode *this_node, DdNode *g, DdNode *cube, unsigned int limit) { DdNode* result = Cudd_bddAndAbstractLimit(self, this_node,g,cube,limit); Cudd_Ref(result); return result; }
  %newobject AndLimit;  DdNode * AndLimit(DdNode *this_node, DdNode *g, unsigned int limit) { DdNode* result = Cudd_bddAndLimit(self, this_node, g, limit); Cudd_Ref(result); return result; }
  %newobject NPAnd;  DdNode * NPAnd(DdNode *this_node, DdNode *c) { DdNode* result =  Cudd_bddNPAnd(self, this_node, c); Cudd_Ref(result); return result; }
  DdTlcInfo * FindTwoLiteralClauses(DdNode *this_node) { DdTlcInfo * result = Cudd_FindTwoLiteralClauses(self, this_node); return result; }
#endif

  int EpdCountMinterm(DdNode *this_node, int nvars, EpDouble *epd) { return Cudd_EpdCountMinterm(self,this_node,nvars,epd); }
  // Added in this version of pycudd -- various decomposition techniques and other odds and ends
  int ApproxConjDecomp(DdNode *this_node, DdNode ***dum_juncts) { return Cudd_bddApproxConjDecomp(self, this_node, dum_juncts); }
  int ApproxDisjDecomp(DdNode *this_node, DdNode ***dum_juncts) { return Cudd_bddApproxDisjDecomp(self, this_node, dum_juncts); }
  int IterConjDecomp(DdNode *this_node, DdNode ***dum_juncts) { return Cudd_bddIterConjDecomp(self, this_node, dum_juncts); }
  int IterDisjDecomp(DdNode *this_node, DdNode ***dum_juncts) { return Cudd_bddIterDisjDecomp(self, this_node, dum_juncts); }
  int GenConjDecomp(DdNode *this_node, DdNode ***dum_juncts) { return Cudd_bddGenConjDecomp(self, this_node, dum_juncts); }
  int GenDisjDecomp(DdNode *this_node, DdNode ***dum_juncts) { return Cudd_bddGenDisjDecomp(self, this_node, dum_juncts); }
  int VarConjDecomp(DdNode *this_node, DdNode ***dum_juncts) { return Cudd_bddVarConjDecomp(self, this_node, dum_juncts); }
  int VarDisjDecomp(DdNode *this_node, DdNode ***dum_juncts) { return Cudd_bddVarDisjDecomp(self, this_node, dum_juncts); }
  %apply int * OUTPUT { int * dum_distance };
%newobject ClosestCube;  DdNode * ClosestCube (DdNode *this_node, DdNode *g, int *dum_distance) { DdNode* result = Cudd_bddClosestCube(self,this_node,g,dum_distance); Cudd_Ref(result); return result; }
  int LeqUnless (DdNode *this_node, DdNode *g, DdNode *D) { return Cudd_bddLeqUnless (self,this_node,g,D); }
%newobject MakePrime;  DdNode * MakePrime (DdNode *this_node, DdNode *f) { DdNode *result = Cudd_bddMakePrime (self,this_node,f); Cudd_Ref(result); return result; }

  int SupportIndex(DdNode *this_node, int **dum_sup) {
    *dum_sup = Cudd_SupportIndex(self,this_node);
    if (*dum_sup == NULL) return 0;
    else return 1;
  }

  // Existing pycudd wrappers
%newobject ExistAbstract;  DdNode *  ExistAbstract(DdNode *this_node,  DdNode *cube) { DdNode* result = Cudd_bddExistAbstract(self, this_node,  cube); Cudd_Ref(result); return result; }
%newobject XorExistAbstract;  DdNode *  XorExistAbstract(DdNode *this_node,  DdNode *g, DdNode *cube) { DdNode* result = Cudd_bddXorExistAbstract(self, this_node,  g,  cube); Cudd_Ref(result); return result; }
%newobject UnivAbstract;  DdNode *  UnivAbstract(DdNode *this_node,  DdNode *cube) { DdNode* result = Cudd_bddUnivAbstract(self, this_node,  cube); Cudd_Ref(result); return result; }
%newobject BooleanDiff;  DdNode *  BooleanDiff(DdNode *this_node,  int x) { DdNode* result = Cudd_bddBooleanDiff(self, this_node,  x); Cudd_Ref(result); return result; }
%newobject AndAbstract;  DdNode *  AndAbstract(DdNode *this_node,  DdNode *g, DdNode *cube) { DdNode* result = Cudd_bddAndAbstract(self, this_node,  g,  cube); Cudd_Ref(result); return result; }
  int  VarIsDependent(DdNode *this_node,  DdNode *var) { return Cudd_bddVarIsDependent(self, this_node,  var); }
  double  Correlation(DdNode *this_node,  DdNode *g) { return Cudd_bddCorrelation(self, this_node,  g); }
  double  CorrelationWeights(DdNode *this_node,  DdNode *g, DoubleArray *prob) { return Cudd_bddCorrelationWeights(self, this_node,  g,  prob->vec); }
%newobject Ite;  DdNode *  Ite(DdNode *this_node,  DdNode *g, DdNode *h) { DdNode* result = Cudd_bddIte(self, this_node,  g,  h); Cudd_Ref(result); return result; }
%newobject IteConstant; DdNode *  IteConstant(DdNode *this_node,  DdNode *g, DdNode *h) { DdNode* result = Cudd_bddIteConstant(self, this_node,  g,  h); Cudd_Ref(result); return result; }
%newobject Intersect;  DdNode *  Intersect(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_bddIntersect(self, this_node,  g); Cudd_Ref(result); return result; }
  int  FIntersect(DdNode *this_node,  DdNode *g) { int result = Cudd_bddLeq( self, this_node, Cudd_Not(g)) ? 0:1; return result; }

%newobject And;  DdNode *  And(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_bddAnd(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject Or;  DdNode *  Or(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_bddOr(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject Nand;  DdNode *  Nand(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_bddNand(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject Nor;  DdNode *  Nor(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_bddNor(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject Xor;  DdNode *  Xor(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_bddXor(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject Xnor;  DdNode *  Xnor(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_bddXnor(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject ClippingAnd;  DdNode *  ClippingAnd(DdNode *this_node,  DdNode *g, int maxDepth, int direction) { DdNode* result = Cudd_bddClippingAnd(self, this_node,  g,  maxDepth,  direction); Cudd_Ref(result); return result; }
%newobject ClippingAndAbstract;   DdNode *  ClippingAndAbstract(DdNode *this_node,  DdNode *g, DdNode *cube, int maxDepth, int direction) { DdNode* result = Cudd_bddClippingAndAbstract(self, this_node,  g,  cube,  maxDepth,  direction); Cudd_Ref(result); return result; }
%newobject LICompaction;   DdNode *  LICompaction(DdNode *this_node,  DdNode *c) { DdNode* result = Cudd_bddLICompaction(self, this_node,  c); Cudd_Ref(result); return result; }
%newobject Squeeze;   DdNode *  Squeeze(DdNode *this_node,  DdNode *u) { DdNode* result = Cudd_bddSqueeze(self, this_node,  u); Cudd_Ref(result); return result; }
%newobject Minimize;   DdNode *  Minimize(DdNode *this_node,  DdNode *c) { DdNode* result = Cudd_bddMinimize(self, this_node,  c); Cudd_Ref(result); return result; }
%newobject Constrain;   DdNode *  Constrain(DdNode *this_node,  DdNode *c) { DdNode* result = Cudd_bddConstrain(self, this_node,  c); Cudd_Ref(result); return result; }
%newobject Restrict;   DdNode *  Restrict(DdNode *this_node,  DdNode *c) { DdNode* result = Cudd_bddRestrict(self, this_node,  c); Cudd_Ref(result); return result; }
  int  PickOneCube(DdNode *this_node,  char *string) { return Cudd_bddPickOneCube(self, this_node, string); }
%newobject PickOneMinterm;  DdNode *  PickOneMinterm(DdNode *this_node,  DdArray *vars, int n) { DdNode* result = Cudd_bddPickOneMinterm(self, this_node,  vars->vec,  n); Cudd_Ref(result); return result; }
  DdArray *  PickArbitraryMinterms(DdNode *this_node,  DdArray *vars, int n, int k) { DdNode** tresult = Cudd_bddPickArbitraryMinterms(self, this_node,  vars->vec,  n,  k); DdArray* result = new DdArray(self,k); result->Assign(tresult, k); return result; }
%newobject Compose;  DdNode *  Compose(DdNode *this_node,  DdNode *g, int v) { DdNode* result = Cudd_bddCompose(self, this_node,  g,  v); Cudd_Ref(result); return result; }
%newobject Permute;   DdNode *  Permute(DdNode *this_node,  IntArray *permut) { DdNode* result = Cudd_bddPermute(self, this_node,  permut->vec); Cudd_Ref(result); return result; }
%newobject VarMap;   DdNode *  VarMap(DdNode *this_node) { DdNode* result = Cudd_bddVarMap(self, this_node); Cudd_Ref(result); return result; }
  %newobject LiteralSetIntersection;   DdNode *  LiteralSetIntersection(DdNode *this_node, DdNode *g) { DdNode* result = Cudd_bddLiteralSetIntersection(self, this_node,  g); Cudd_Ref(result); return result; }
  int  IsVarEssential(DdNode *this_node,  int id, int phase) { return Cudd_bddIsVarEssential(self, this_node,  id,  phase); }
  bool  Leq(DdNode *this_node,  DdNode *g) { return Cudd_bddLeq(self, this_node,  g) ? TRUE : FALSE; }
  DdArray *  CharToVect(DdNode *this_node) { DdNode** tresult = Cudd_bddCharToVect(self, this_node); int size = Cudd_ReadSize(self); DdArray* result = new DdArray(self, size); result->Assign(tresult,size); return result; }
  DdArray *  ConstrainDecomp(DdNode *this_node) { DdNode** tresult = Cudd_bddConstrainDecomp(self, this_node); int size = Cudd_ReadSize(self); DdArray* result = new DdArray(self, size); result->Assign(tresult,size); return result; }
%newobject Isop;   DdNode *  Isop(DdNode *this_node,  DdNode *U) { DdNode* result = Cudd_bddIsop(self, this_node,  U); Cudd_Ref(result); return result; }
%newobject SwapVariables;   DdNode *  SwapVariables(DdNode *this_node,  DdArray *x, DdArray *y, int n) { DdNode* result = Cudd_bddSwapVariables(self, this_node,  x->vec,  y->vec,  n); Cudd_Ref(result); return result; }
%newobject AdjPermuteX;   DdNode *  AdjPermuteX(DdNode *this_node,  DdArray *x, int n) { DdNode* result = Cudd_bddAdjPermuteX(self, this_node,  x->vec,  n); Cudd_Ref(result); return result; }
%newobject VectorCompose;   DdNode *  VectorCompose(DdNode *this_node,  DdArray *vector) { DdNode* result = Cudd_bddVectorCompose(self, this_node,  vector->vec); Cudd_Ref(result); return result; }
  void  SetBackground(DdNode *this_node) { Cudd_SetBackground(self, this_node); }
%newobject UnderApprox;   DdNode *  UnderApprox(DdNode *this_node,  int numVars, int threshold, int safe, double quality) { DdNode* result = Cudd_UnderApprox(self, this_node,  numVars,  threshold,  safe,  quality); Cudd_Ref(result); return result; }
%newobject OverApprox;   DdNode *  OverApprox(DdNode *this_node,  int numVars, int threshold, int safe, double quality) { DdNode* result = Cudd_OverApprox(self, this_node,  numVars,  threshold,  safe,  quality); Cudd_Ref(result); return result; }
%newobject RemapUnderApprox;   DdNode *  RemapUnderApprox(DdNode *this_node,  int numVars, int threshold, double quality) { DdNode* result = Cudd_RemapUnderApprox(self, this_node,  numVars,  threshold,  quality); Cudd_Ref(result); return result; }
%newobject RemapOverApprox;   DdNode *  RemapOverApprox(DdNode *this_node,  int numVars, int threshold, double quality) { DdNode* result = Cudd_RemapOverApprox(self, this_node,  numVars,  threshold,  quality); Cudd_Ref(result); return result; }
%newobject BiasedUnderApprox;   DdNode *  BiasedUnderApprox(DdNode *this_node,  DdNode *b, int numVars, int threshold, double quality1, double quality0) { DdNode* result = Cudd_BiasedUnderApprox(self, this_node,  b,  numVars,  threshold,  quality1,  quality0); Cudd_Ref(result); return result; }
%newobject BiasedOverApprox;   DdNode *  BiasedOverApprox(DdNode *this_node,  DdNode *b, int numVars, int threshold, double quality1, double quality0) { DdNode* result = Cudd_BiasedOverApprox(self, this_node,  b,  numVars,  threshold,  quality1,  quality0); Cudd_Ref(result); return result; }
%newobject Cofactor;  DdNode *  Cofactor(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_Cofactor(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject FindEssential;   DdNode *  FindEssential(DdNode *this_node) { DdNode* result = Cudd_FindEssential(self, this_node); Cudd_Ref(result); return result; }
%newobject SubsetCompress;   DdNode *  SubsetCompress(DdNode *this_node,  int nvars, int threshold) { DdNode* result = Cudd_SubsetCompress(self, this_node,  nvars,  threshold); Cudd_Ref(result); return result; }
%newobject SupersetCompress;   DdNode *  SupersetCompress(DdNode *this_node,  int nvars, int threshold) { DdNode* result = Cudd_SupersetCompress(self, this_node,  nvars,  threshold); Cudd_Ref(result); return result; }
%newobject CProjection;   DdNode *  CProjection(DdNode *this_node,  DdNode *Y) { DdNode* result = Cudd_CProjection(self, this_node,  Y); Cudd_Ref(result); return result; }
  int  MinHammingDist(DdNode *this_node,  IntArray *minterm, int upperBound) { return Cudd_MinHammingDist(self, this_node,  minterm->vec,  upperBound); }
%newobject Eval;   DdNode *  Eval(DdNode *this_node,  IntArray *inputs) { DdNode* result = Cudd_Eval(self, this_node,  inputs->vec); Cudd_Ref(result); return result; }
%newobject ShortestPath;   DdNode *  ShortestPath(DdNode *this_node,  IntArray *weight, IntArray *support, IntArray *length) { DdNode* result = Cudd_ShortestPath(self, this_node,  weight->vec,  support->vec,  length->vec); Cudd_Ref(result); return result; }
%newobject LargestCube;   DdNode *  LargestCube(DdNode *this_node,  IntArray *length) { DdNode* result = Cudd_LargestCube(self, this_node,  length->vec); Cudd_Ref(result); return result; }
  int  ShortestLength(DdNode *this_node,  IntArray *weight) { return Cudd_ShortestLength(self, this_node,  weight->vec); }
%newobject Decreasing;   DdNode *  Decreasing( DdNode *this_node, int i) { DdNode* result = Cudd_Decreasing(self, this_node,  i); Cudd_Ref(result); return result; }
%newobject Increasing;   DdNode *  Increasing(DdNode *this_node,  int i) { DdNode* result = Cudd_Increasing(self, this_node,  i); Cudd_Ref(result); return result; }
  int  EquivDC(DdNode *this_node,  DdNode *G, DdNode *D) { return Cudd_EquivDC(self, this_node,  G,  D); }
  int  EqualSupNorm(DdNode *this_node,  DdNode *g, CUDD_VALUE_TYPE tolerance, int pr) { return Cudd_EqualSupNorm(self, this_node,  g, tolerance,  pr); }
  DoubleArray*  CofMinterm(DdNode *this_node) { double* tresult = Cudd_CofMinterm(self, this_node); int size = Cudd_ReadSize(self)+1; DoubleArray* result = new DoubleArray(size); result->Assign( tresult, size); return result; }
%newobject SolveEqn;   /* DdNode *  SolveEqn( DdNode *Y, DdArray *G, int **yIndex, int n) { DdNode* result = Cudd_SolveEqn(self, this_node,  Y,  G->vec,  yIndex,  n); Cudd_Ref(result); return result; } */
%newobject VerifySol;   DdNode *  VerifySol(DdNode *this_node,  DdArray *G, IntArray *yIndex, int n) { DdNode* result = Cudd_VerifySol(self, this_node,  G->vec,  yIndex->vec,  n); Cudd_Ref(result); return result; }
%newobject SplitSet;   DdNode *  SplitSet(DdNode *this_node,  DdArray *xVars, int n, double m) { DdNode* result = Cudd_SplitSet(self, this_node,  xVars->vec,  n,  m); Cudd_Ref(result); return result; }
%newobject SubsetHeavyBranch;   DdNode *  SubsetHeavyBranch(DdNode *this_node,  int numVars, int threshold) { DdNode* result = Cudd_SubsetHeavyBranch(self, this_node,  numVars,  threshold); Cudd_Ref(result); return result; }
%newobject SupersetHeavyBranch;   DdNode *  SupersetHeavyBranch(DdNode *this_node,  int numVars, int threshold) { DdNode* result = Cudd_SupersetHeavyBranch(self, this_node,  numVars,  threshold); Cudd_Ref(result); return result; }
%newobject SubsetShortPaths;   DdNode *  SubsetShortPaths(DdNode *this_node,  int numVars, int threshold, int hardlimit) { DdNode* result = Cudd_SubsetShortPaths(self, this_node,  numVars,  threshold,  hardlimit); Cudd_Ref(result); return result; }
%newobject SupersetShortPaths;   DdNode *  SupersetShortPaths(DdNode *this_node,  int numVars, int threshold, int hardlimit) { DdNode* result = Cudd_SupersetShortPaths(self, this_node,  numVars,  threshold,  hardlimit); Cudd_Ref(result); return result; }
  int  BddToCubeArray(DdNode *this_node,  IntArray *y) { return Cudd_BddToCubeArray( self, this_node, y->vec); }
  int  PrintMinterm(DdNode *this_node) { return Cudd_PrintMinterm(self, this_node); }
  int  PrintDebug(DdNode *this_node, int n, int pr) { return Cudd_PrintDebug(self, this_node,  n,  pr); }
  int  EstimateCofactor(DdNode *this_node,  int i, int phase) { return Cudd_EstimateCofactor(self, this_node,  i,  phase); }
  double  CountMinterm(DdNode *this_node,  int nvars) { return Cudd_CountMinterm(self, this_node,  nvars); }
%newobject Support;   DdNode *  Support(DdNode *this_node) { DdNode* result = Cudd_Support(self, this_node); Cudd_Ref(result); return result; }
  int  SupportSize(DdNode *this_node) { return Cudd_SupportSize(self, this_node); }
  double  Density( DdNode *this_node, int nvars) { return Cudd_Density(self, this_node,  nvars); }

  int BddStore(DdNode *this_node, char *ddname, char **varnames, IntArray *auxids, int mode, int varinfo, char *fname, FILE *fp) { return Dddmp_cuddBddStore( self, ddname, this_node, varnames, (int *) (auxids ? auxids->vec : NULL), mode, (Dddmp_VarInfoType) varinfo, fname, fp); }

  /* Risky - originally #Defines, not sure about referencing here */
  int IsConstant(DdNode *this_node) { return Cudd_IsConstant(this_node); }
%newobject Not;   DdNode * Not(DdNode *this_node) { DdNode* result = Cudd_Not(this_node); Cudd_Ref(result); return result;}
%newobject NotCond;   DdNode * NotCond(DdNode *this_node, int c) { DdNode* result = Cudd_NotCond(this_node, c); Cudd_Ref(result); return result;}
%newobject Regular;   DdNode * Regular(DdNode *this_node) { DdNode* result = Cudd_Regular(this_node); Cudd_Ref(result); return result;}
%newobject Complement;   DdNode * Complement(DdNode *this_node) { DdNode* result = Cudd_Complement(this_node); Cudd_Ref(result); return result;}
  int IsComplement(DdNode *this_node) { return Cudd_IsComplement(this_node); }
%newobject T;   DdNode * T(DdNode *this_node) { DdNode* result = Cudd_T(this_node); Cudd_Ref(result); return result;}
%newobject E;   DdNode * E(DdNode *this_node) { DdNode* result = Cudd_E(this_node); Cudd_Ref(result); return result;}
  double V(DdNode *this_node) { return Cudd_V(this_node); }
  int ReadIndex(DdNode *this_node, int index) { return Cudd_ReadPerm(self, index); }

  /* add specific */
%newobject addExistAbstract;   DdNode *  addExistAbstract(DdNode *this_node,  DdNode *cube) { DdNode* result = Cudd_addExistAbstract(self, this_node,  cube); Cudd_Ref(result); return result; }
%newobject addUnivAbstract;   DdNode *  addUnivAbstract(DdNode *this_node,  DdNode *cube) { DdNode* result = Cudd_addUnivAbstract(self, this_node,  cube); Cudd_Ref(result); return result; }
%newobject addOrAbstract;   DdNode *  addOrAbstract(DdNode *this_node,  DdNode *cube) { DdNode* result = Cudd_addOrAbstract(self, this_node,  cube); Cudd_Ref(result); return result; }
%newobject addFindMax;   DdNode *  addFindMax(DdNode *this_node) { DdNode* result = Cudd_addFindMax(self, this_node); Cudd_Ref(result); return result; }
%newobject addFindMin;   DdNode *  addFindMin(DdNode *this_node) { DdNode* result = Cudd_addFindMin(self, this_node); Cudd_Ref(result); return result; }
%newobject addIthBit;   DdNode *  addIthBit(DdNode *this_node,  int bit) { DdNode* result = Cudd_addIthBit(self, this_node,  bit); Cudd_Ref(result); return result; }
%newobject addScalarInverse;   DdNode *  addScalarInverse(DdNode *this_node,  DdNode *epsilon) { DdNode* result = Cudd_addScalarInverse(self, this_node,  epsilon); Cudd_Ref(result); return result; }
%newobject addIte;   DdNode *  addIte( DdNode *this_node, DdNode *g, DdNode *h) { DdNode* result = Cudd_addIte(self, this_node,  g,  h); Cudd_Ref(result); return result; }
%newobject addIteConstant;   DdNode *  addIteConstant(DdNode *this_node,  DdNode *g, DdNode *h) { DdNode* result = Cudd_addIteConstant(self, this_node,  g,  h); Cudd_Ref(result); return result; }
%newobject addEvalConst;   DdNode *  addEvalConst(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_addEvalConst(self, this_node,  g); Cudd_Ref(result); return result; }
  int  addLeq(DdNode *this_node, DdNode * g) { return Cudd_addLeq(self, this_node,   g); }
%newobject addCmpl;   DdNode *  addCmpl(DdNode *this_node) { DdNode* result = Cudd_addCmpl(self, this_node); Cudd_Ref(result); return result; }
%newobject addNegate;   DdNode *  addNegate(DdNode *this_node) { DdNode* result = Cudd_addNegate(self, this_node); Cudd_Ref(result); return result; }
%newobject addRoundOff;   DdNode *  addRoundOff(DdNode *this_node,  int N) { DdNode* result = Cudd_addRoundOff(self, this_node,  N); Cudd_Ref(result); return result; }
%newobject addCompose;   DdNode *  addCompose(DdNode *this_node,  DdNode *g, int v) { DdNode* result = Cudd_addCompose(self, this_node,  g,  v); Cudd_Ref(result); return result; }
%newobject addPermute;   DdNode *  addPermute(DdNode *this_node,  IntArray *permut) { DdNode* result = Cudd_addPermute(self, this_node,  permut->vec); Cudd_Ref(result); return result; }
%newobject addConstrain;   DdNode *  addConstrain(DdNode *this_node,  DdNode *c) { DdNode* result = Cudd_addConstrain(self, this_node,  c); Cudd_Ref(result); return result; }
%newobject addRestrict;   DdNode *  addRestrict(DdNode *this_node,  DdNode *c) { DdNode* result = Cudd_addRestrict(self, this_node,  c); Cudd_Ref(result); return result; }
%newobject addMatrixMultiply;   DdNode *  addMatrixMultiply(DdNode *this_node,  DdNode *B, DdArray *z, int nz) { DdNode* result = Cudd_addMatrixMultiply(self, this_node,  B,  z->vec,  nz); Cudd_Ref(result); return result; }
%newobject addTimesPlus;   DdNode *  addTimesPlus(DdNode *this_node,  DdNode *B, DdArray *z, int nz) { DdNode* result = Cudd_addTimesPlus(self, this_node,  B,  z->vec,  nz); Cudd_Ref(result); return result; }
%newobject addTriangle;   DdNode *  addTriangle(DdNode *this_node,  DdNode *g, DdArray *z, int nz) { DdNode* result = Cudd_addTriangle(self, this_node,  g,  z->vec,  nz); Cudd_Ref(result); return result; }
%newobject addVectorCompose;   DdNode *  addVectorCompose(DdNode *this_node,  DdArray *vector) { DdNode* result = Cudd_addVectorCompose(self, this_node,  vector->vec); Cudd_Ref(result); return result; }
%newobject addNonSimCompose;   DdNode *  addNonSimCompose(DdNode *this_node,  DdArray *vector) { DdNode* result = Cudd_addNonSimCompose(self, this_node,  vector->vec); Cudd_Ref(result); return result; }
%newobject addSwapVariables;   DdNode *  addSwapVariables(DdNode *this_node,  DdArray *x, DdArray *y, int n) { DdNode* result = Cudd_addSwapVariables(self, this_node,  x->vec,  y->vec,  n); Cudd_Ref(result); return result; }

  /* zbdd specific */
%newobject zddProduct;   DdNode *  zddProduct(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_zddProduct(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject zddUnateProduct;   DdNode *  zddUnateProduct(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_zddUnateProduct(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject zddWeakDiv;   DdNode *  zddWeakDiv(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_zddWeakDiv(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject zddDivide;   DdNode *  zddDivide(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_zddDivide(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject zddWeakDivF;   DdNode *  zddWeakDivF(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_zddWeakDivF(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject zddDivideF;   DdNode *  zddDivideF(DdNode *this_node,  DdNode *g) { DdNode* result = Cudd_zddDivideF(self, this_node,  g); Cudd_Ref(result); return result; }
%newobject zddComplement;   DdNode *  zddComplement(DdNode *this_node) { DdNode* result = Cudd_zddComplement(self, this_node); Cudd_Ref(result); return result; }
%newobject zddIte;   DdNode *  zddIte(DdNode *this_node,  DdNode *g, DdNode *h) { DdNode* result = Cudd_zddIte(self, this_node,  g,  h); Cudd_Ref(result); return result; }
%newobject zddUnion;   DdNode *  zddUnion(DdNode *this_node,  DdNode *Q) { DdNode* result = Cudd_zddUnion(self, this_node,  Q); Cudd_Ref(result); return result; }
%newobject zddIntersect;   DdNode *  zddIntersect(DdNode *this_node,  DdNode *Q) { DdNode* result = Cudd_zddIntersect(self, this_node,  Q); Cudd_Ref(result); return result; }
%newobject zddDiff;   DdNode *  zddDiff(DdNode *this_node,  DdNode *Q) { DdNode* result = Cudd_zddDiff(self, this_node,  Q); Cudd_Ref(result); return result; }
%newobject zddDiffConst;   DdNode *  zddDiffConst(DdNode *this_node,  DdNode *Q) { DdNode* result = Cudd_zddDiffConst(self, this_node,  Q); Cudd_Ref(result); return result; }
%newobject zddSubset1;   DdNode *  zddSubset1(DdNode *this_node,  int var) { DdNode* result = Cudd_zddSubset1(self, this_node,  var); Cudd_Ref(result); return result; }
%newobject zddSubset0;   DdNode *  zddSubset0(DdNode *this_node,  int var) { DdNode* result = Cudd_zddSubset0(self, this_node,  var); Cudd_Ref(result); return result; }
%newobject zddChange;   DdNode *  zddChange(DdNode *this_node,  int var) { DdNode* result = Cudd_zddChange(self, this_node,  var); Cudd_Ref(result); return result; }
  int  zddCount(DdNode *this_node) { return Cudd_zddCount(self, this_node); }
  double  zddCountDouble(DdNode *this_node) { return Cudd_zddCountDouble(self, this_node); }
  int  zddPrintMinterm(DdNode *this_node) { return Cudd_zddPrintMinterm(self, this_node); }
  int  zddPrintCover(DdNode *this_node) { return Cudd_zddPrintCover(self, this_node); }
  int  zddPrintDebug( DdNode *this_node, int n, int pr) { return Cudd_zddPrintDebug(self, this_node,  n,  pr); }
  double  zddCountMinterm(DdNode *this_node,  int path) { return Cudd_zddCountMinterm(self, this_node,  path); }
%newobject zddIsop;   DdNode *  zddIsop(DdNode *this_node,  DdNode *U, DdArray *zdd_I) { DdNode* result = Cudd_zddIsop(self, this_node,  U,  zdd_I->vec); Cudd_Ref(result); return result; }


  /* apa specific */
  int ApaPrintMinterm(DdNode *this_node, FILE *fp, int nvars) { return Cudd_ApaPrintMinterm(fp, self, this_node, nvars); }
  int ApaPrintMintermExp(DdNode *this_node, FILE *fp, int nvars, int precision) { return Cudd_ApaPrintMintermExp(fp, self, this_node, nvars, precision); }
  int ApaPrintDensity(DdNode *this_node, FILE *fp, int nvars) { return Cudd_ApaPrintDensity(fp, self, this_node, nvars); }
  DdApaNumber ApaCountMinterm(DdNode *this_node, int nvars, IntArray *digits) {  return Cudd_ApaCountMinterm(self, this_node, nvars, digits->vec); }



  int DumpDot(DdNode *this_node) {

    FILE *dfp = NULL;
    DdNode *dfunc[1];
    int retval;

    dfunc[0] = this_node;
    dfp = fopen("out.dot", "w");

    retval = Cudd_DumpDot(self,1,dfunc,NULL,NULL,dfp);

    fclose(dfp);
    return retval;
  }

  int DumpBlif(DdNode *this_node) {

    FILE *dfp = NULL;
    DdNode *dfunc[1];
    int retval;

    dfunc[0] = this_node;
    dfp = fopen("out.blif", "w");

    retval = Cudd_DumpBlif(self,1,dfunc,NULL,NULL,NULL,dfp,0);

    fclose(dfp);
    return retval;
  }

  DdArray* Vector(DdNode *this_node) {

    DdArray* result;
    DdNode *front, *f1, *f0;
    int index;
    int size = Cudd_DagSize(this_node);
    size = size-1;

    if (size > Cudd_ReadSize(self)) {
      cerr << "Minterm contains more nodes than manager!\n";
      return NULL;
    }

    result = new DdArray(self,size);
    if (!size) return result;

    front = this_node;

    index = Cudd_NodeReadIndex(front);

    result->__setitem__(0,Cudd_bddIthVar(self,index));

    for (int i=1; i< size; i++) {
      f1 = Cudd_T(front);
      f0 = Cudd_E(front);

      if ( (f1 != Cudd_ReadLogicZero(self)) && (f1 != Cudd_ReadOne(self)) ) {
        if (!( (f0 == Cudd_ReadLogicZero(self)) || (f0 == Cudd_ReadOne(self)) )) {
          cerr << "Not a minterm\n";
          delete result;
          return NULL;
        }
        front = f1;
      } else if ( (f0 != Cudd_ReadLogicZero(self)) && (f0 != Cudd_ReadOne(self)) ) {
        if (!( (f1 == Cudd_ReadLogicZero(self)) || (f1 == Cudd_ReadOne(self)) )) {
          cerr << "Not a minterm\n";
          delete result;
          return NULL;
        }
        front = f0;
      } else {
        cerr << "Not enough nodes in minterm\n";
        delete result;
        return NULL;
      }
      index = Cudd_NodeReadIndex(front);
      result->__setitem__(i,Cudd_bddIthVar(self,index));
    }

    return result;

  }

};
