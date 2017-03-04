all: simple-term

simple-term: *.vala
	valac --pkg vte-2.91 --pkg gtk+-3.0 --pkg posix simple-term.vala
