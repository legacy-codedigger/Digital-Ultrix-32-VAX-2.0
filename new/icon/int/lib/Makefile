#	1.3	Makefile	84/10/11
DESTROOT=
CFLAGS = -O -w

Lib:		bscan.o create.o \
		escan.o field.o keywd.o \
		limit.o llist.o mkrec.o 
	ar r Lib $?
	ranlib Lib

bscan.o:	../h/rt.h
coact.o:	../h/defs.s
cofail.o:	../h/defs.s
coret.o:	../h/defs.s
create.o:	../h/rt.h
efail.o:	../h/defs.s
escan.o:	../h/rt.h
esusp.o:	../h/defs.s
field.o:	../h/rt.h ../h/record.h
invoke.o:	../h/defs.s
keywd.o:	../h/rt.h ../tran/keyword.h ../h/config.h
limit.o:	../h/rt.h
llist.o:	../h/rt.h
lsusp.o:	../h/defs.s
mkrec.o:	../h/rt.h ../h/record.h
pfail.o:	../h/defs.s
pret.o:		../h/defs.s
psusp.o:	../h/defs.s

Listall:
	@pr *.[cs]
	@date >List

List:		bscan.c coact.s cofail.s coret.s create.c \
		efail.s escan.c esusp.s field.c invoke.s keywd.c \
		limit.c llist.c lsusp.s mkrec.c pfail.s pret.s psusp.s
	@pr $?
	@date >List

.s.o:
	cat ../h/defs.s $< >t.c
	cc -E t.c | grep -v "^#" >t.s
	as -o $@ t.s
	rm -f t.c t.s
clean:
	@rm -f *.o
clobber: clean
	@rm -f *.c Makefile
sccsinfo:
	@sccs info
sccsget:
	@sccs get -s SCCS
all:
install: all

dist-clean: clean
	rm -f `gcomp Makefile *.c *.s`
