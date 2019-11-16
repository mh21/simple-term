# general stuff

AM_CPPFLAGS = $(TERMDEPS_CFLAGS)

AM_CFLAGS = -Wall -Wno-discarded-qualifiers -Wno-pointer-sign -Wno-unused-but-set-variable -Wno-unused-variable

VALAFLAGS = --pkg=gtk+-3.0 --pkg=vte-2.91 --pkg=pango --pkg=posix --enable-checking

# the terminal

bin_PROGRAMS = simple-term

simple_term_VALASOURCES = simple-term.vala

simple_term_SOURCES = $(simple_term_VALASOURCES)

simple_term_LDFLAGS = -Wl,--export-dynamic -Wl,--as-needed

simple_term_LDADD = $(TERMDEPS_LIBS) -lm

# documentation

simpletermdocdir = ${datadir}/doc/simple-term
simpletermdoc_DATA = LICENSE README.md

# clean and dist

DISTCLEANFILES = $(simple_term_VALASOURCES:.vala=.c) simple_term_vala.stamp

EXTRA_DIST = $(simpletermdoc_DATA) autogen.sh

uninstall-hook:
	-rmdir $(DESTDIR)$(simpletermdocdir)
