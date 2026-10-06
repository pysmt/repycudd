/* Hand-written stand-in for the autotools config.h; repycudd builds CUDD
   from setup.py without running configure. SIZEOF_VOID_P and SIZEOF_INT
   come from setup.py because they depend on the target ABI. */
#ifndef CUDD_CONFIG_H_
#define CUDD_CONFIG_H_

#define PACKAGE_VERSION "3.0.0"
#define HAVE_IEEE_754 1
#define HAVE_ASSERT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_STDDEF_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_POWL 1

#ifndef _WIN32
#define HAVE_UNISTD_H 1
#define HAVE_SYSCONF 1
#define HAVE_SYS_RESOURCE_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TIMES_H 1
#define HAVE_GETRLIMIT 1
#define HAVE_GETRUSAGE 1
#endif

#endif
