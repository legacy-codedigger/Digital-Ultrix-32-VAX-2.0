# @(#)Makefile	1.6	ULTRIX	4/28/86
#
#	@(#)Makefile	4.1	12/18/82

CFLAGS=-O
h = tp.h tp_defs.h
o  = tp0.o tp1.o tp2.o tp3.o

tp :	$o
	$(CC) -o tp ${CFLAGS} $o

$o :	$h

install : tp
	install -c -s tp ${DESTROOT}/bin

clean : 
	rm -f *.o

clobber : clean
	rm -f Makefile *.[ch] tp

sccsinfo :
	sccs info

sccsget :
	sccs get SCCS

.DEFAULT:
	sccs get $<
