# @(#)Makefile	1.3	ULTRIX	10/1/84
#
# make file for cribbage
#
# @(#)Makefile	1.3 (Berkeley) 9/6/83
#
HDRS=	cribbage.h deck.h cribcur.h
OBJS=	extern.o crib.o support.o cards.o score.o io.o
CFILES=	extern.c crib.c support.c cards.c score.c io.c
TOBJS=	test.o cards.o score.o io.o extern.o
CFLAGS=	-O
DESTROOT=

cribbage:	${OBJS}
	${CC} ${CFLAGS} -o cribbage ${OBJS} -lcurses -ltermlib

all: cribbage crib.instr

crib.o io.o support.o: cribcur.h

test:		${TOBJS}
	${CC} ${CFLAGS} -o test ${TOBJS} -lcurses -ltermlib

crib.instr: cribbage.n macro
	nroff cribbage.n > crib.instr

tags: ${HDRS} ${CFILES}
	ctags -u $?
	ed - tags < :ctfix
	sort tags -o tags

clean:
	rm -f ${OBJS} ? a.out core crib.instr cribbage

crib.o:		deck.h	cribbage.h	cribcur.h
support.o:	deck.h	cribbage.h	cribcur.h
test.o:		deck.h
cards.o:	deck.h
score.o:	deck.h
io.o:		deck.h			cribcur.h

clobber: clean
	rm -f *.[coh] Makefile :ctfix

sccsinfo:
	sccs info

sccsget:
	sccs get SCCS

.DEFAULT:
	sccs get $<

install: cribbage crib.instr
	install -c -s cribbage ${DESTROOT}/usr/games/
	install -c crib.instr ${DESTROOT}/usr/games/lib/
