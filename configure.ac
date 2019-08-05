AC_INIT([simple-term],
	[0.1],
	[mh21@mh21.de],
	[simple-term],
	[https://github.com/mh21/simple-term/])

AM_INIT_AUTOMAKE([foreign dist-xz no-dist-gzip tar-pax])

AC_CONFIG_SRCDIR([simple-term.vala])
AC_PROG_CC

AM_SILENT_RULES([yes])
AM_PROG_VALAC([0.14.0])
AM_PROG_CC_C_O

PKG_CHECK_MODULES(TERMDEPS, [gtk+-3.0 vte-2.91 >= 0.54.4])

AC_CONFIG_FILES([Makefile])

AC_OUTPUT

AC_MSG_RESULT([
  ------------------------
  $PACKAGE_NAME $VERSION
  ------------------------
  CPPFLAGS: ${CPPFLAGS}
  CFLAGS:   ${CFLAGS}
  LDFLAGS:  ${LDFLAGS}
  ------------------------
])
