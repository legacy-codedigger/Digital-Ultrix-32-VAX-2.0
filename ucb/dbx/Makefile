#@(#)Makefile	1.4	Ultrix	5/2/86

#
# make file for debugger "dbx"
#
# The file "defs.h" is included by all.
#
.SUFFIXES:
.SUFFIXES: .h .c .s .o

DESTROOT=
DESTDIR = .
AOUT	= tdbx
DEST	= ${DESTROOT}/usr/ucb/dbx

LIBRARIES =

CC	= cc
CFLAGS	=
LDFLAGS	=

OBJ = \
    y.tab.o \
    asm.o \
    events.o \
    c.o \
    cerror.o \
    check.o \
    coredump.o \
    debug.o \
    eval.o \
    fortran.o \
    keywords.o \
    languages.o \
    library.o \
    lists.o \
    machine.o \
    main.o \
    mappings.o \
    modula-2.o \
    names.o \
    object.o \
    operators.o \
    pascal.o \
    printsym.o \
    process.o \
    runtime.o \
    scanner.o \
    source.o \
    stabstring.o \
    symbols.o \
    tree.o \
    ops.o

HDR = \
    asm.h \
    events.h \
    c.h \
    check.h \
    coredump.h \
    debug.h \
    eval.h \
    fortran.h \
    keywords.h \
    languages.h \
    lists.h \
    machine.h \
    main.h \
    mappings.h \
    modula-2.h \
    names.h \
    object.h \
    operators.h \
    pascal.h \
    printsym.h \
    process.h \
    runtime.h \
    scanner.h \
    source.h \
    stabstring.h \
    symbols.h \
    tree.h \
    ops.h

SRC = \
    defs.h \
    commands.y \
    asm.c \
    events.c \
    c.c \
    cerror.s \
    check.c \
    coredump.c \
    debug.c \
    eval.c \
    fortran.c \
    keywords.c \
    languages.c \
    library.c \
    lists.c \
    machine.c \
    main.c \
    mappings.c \
    modula-2.c \
    names.c \
    object.c \
    operators.c \
    pascal.c \
    printsym.c \
    process.c \
    runtime.c \
    scanner.c \
    source.c \
    symbols.c \
    tree.c \
    ops.c

.c.o:
	@echo "compiling $*.c"
	@${CC} ${CFLAGS} -c $*.c

.s.o:
	@echo "assembling $*.s"
	@${CC}  -c $*.s

.c.h:
	./makedefs -f $*.c $*.h

${AOUT}: makedefs mkdate ${HDR} ${OBJ}
	@rm -f date.c
	@./mkdate > date.c
	@echo "linking"
	@${CC} ${LDFLAGS} date.c ${OBJ} ${LIBRARIES} -o ${DESTDIR}/${AOUT}

sdbx:
	@cp ${DESTDIR}/${AOUT} ${DESTDIR}/$@
	@strip ${DESTDIR}/$@

profile: ${HDR} ${OBJ}
	@rm -f date.c
	@./mkdate > date.c
	@echo "linking with -p"
	@${CC} ${LDFLAGS} -p date.c ${OBJ} ${LIBRARIES} -o ${DESTDIR}/${AOUT}

y.tab.c: commands.y
	@echo "expect 2 shift/reduce conflicts"
	yacc -d commands.y

makedefs: makedefs.c library.o cerror.o
	${CC} -g makedefs.c library.o cerror.o -o makedefs

mkdate: mkdate.c
	${CC} -g mkdate.c -o mkdate

print:
	@echo "don't print it, it's too long"

#
# Don't worry about the removal of header files, they're created from
# the source files.
#

clean:
	rm -f ${HDR} ${OBJ} LOGFILE y.tab.c y.tab.h ${DESTDIR}/${AOUT} \
	    mkdate mkdate.o makedefs makedefs.o date.c core mon.out prof.out

clobber: clean
	rm -f *.[hcoys] TO_DO READ_ME LOGFILE Makefile

sccsinfo:
	sccs info

sccsget:
	sccs get SCCS

install: ${AOUT}
	install -c ${AOUT} ${DEST}

testinstall: ${DESTDIR}/${AOUT} test install

test:
	@chdir ${TESTDIR}; rtest ${AOUT}

all: ${DESTDIR}/${AOUT}

#
# Create a tar file called "tape" containing relevant files.
#

TAPE = tape

tape:
	tar cfv ${TAPE} \
	    Makefile ${SRC} makedefs.c mkdate.c tests/ pchanges ptests

#
# Header dependencies are purposely incomplete since header files
# are "written" every time the accompanying source file changes even if
# the resulting contents of the header don't change.  The alternative is
# to force a "makedefs" to be invoked for every header file each time dbx
# is made.
#
# Also, there should be a dependency of scanner.o and keywords.o on y.tab.h
# but misfortunately silly make does a "makedefs y.tab.c y.tab.h" which
# destroys y.tab.h.
#

symbols.o tree.o check.o eval.o events.o: operators.h
