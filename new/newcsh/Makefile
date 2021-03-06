#	@(#)Makefile	1.5	85/11/25
#
# C Shell with process control; VM/UNIX VAX Makefile
# Bill Joy UC Berkeley; Jim Kulp IIASA, Austria
#
# Modification History
# ~~~~~~~~~~~~~~~~~~~~
# 01 	19-Jan-84, Greg Tarsa
#	Added tenex.o
#
# 02	20-Nov-85, Greg Tarsa
#	Fixed problem with man pages not being included in the kit.
# 
#
CFLAGS=	-O -DTELL -DVMUNIX -DVFORK
XSTR=	/usr/ucb/xstr
ED=	-ed
AS=	-as
RM=	-rm
CXREF=	cref
VGRIND=	csh /usr/ucb/vgrind
CTAGS=	/usr/ucb/ctags
LIBES=
SCCS=	/usr/local/sccs
DESTROOT=

# strings.o must be last in OBJS since it can change when previous files compile
OBJS=	alloc.o doprnt.o printf.o sh.o sh.dir.o sh.dol.o sh.err.o sh.exec.o \
	sh.exp.o sh.func.o sh.glob.o sh.hist.o sh.init.o sh.lex.o sh.misc.o \
	sh.parse.o sh.print.o sh.proc.o sh.sem.o sh.set.o sh.sig.o sh.time.o \
	tenex.o strings.o

# Special massaging of C files for sharing of strings
.c.o:
	${CC} -E ${CFLAGS} $*.c | ${XSTR} -c -
	${CC} -c ${CFLAGS} x.c 
	mv x.o $*.o

csh: ${OBJS} sh.local.h
	rm -f csh
	cc ${OBJS} -o csh ${LIBES}

csh.prof: ${OBJS} sh.prof.o sh.local.h mcrt0.o
	rm -f csh.prof
	ld -X mcrt0.o ${OBJS} -o csh.prof ${LIBES} -lc

sh.o.prof:
	cp sh.c sh.prof.c
	cc -c ${CFLAGS} -DPROF sh.prof.c

.DEFAULT:
	${SCCS} get $<

# need an old doprnt, whose output we can trap
doprnt.o: doprnt.c
	cc -E doprnt.c > doprnt.s
	as -o doprnt.o doprnt.s
	rm -f doprnt.s

# strings.o and sh.init.o are specially processed to be shared
strings.o: strings
	${XSTR}
	${CC} -c -R xs.c
	mv xs.o strings.o

sh.init.o:
	${CC} -E ${CFLAGS} sh.init.c | ${XSTR} -c -
	${CC} ${CFLAGS} -c -R x.c
	mv x.o sh.init.o
	
# Special tenex debugging version
tenexd:
	${CC} -g -c tenex.c
	rm -f csh
	cc -g ${OBJS} -o csh ${LIBES}

# Special rule for tenex.o to avoid xstr stuff.
tenex.o:
	${CC} -c ${CFLAGS} $*.c

lint:
	lint ${CFLAGS} sh*.c

print:
	pr READ_ME | lpr -J "README"
	pr makefile makefile.* | lpr -J "MAKEFILES"
	(size -l a.out; size *.o) | pr -h SIZES | lpr -J "SIZES"
	ctags -x sh*.c | lpr -J "CSH_TOC"
	${CXREF} sh*.h [a-rt-z]*.h sh*.c alloc.c | lpr -J "CSH-XREF"
	ls -l | pr -h "    Directory of csh sources    "

vprint:
	@pr -l84 READ_ME TODO
	@pr -l84 makefile makefile.*
	@(size -l a.out; size *.o) | pr -l84 -h SIZES
	@${CXREF} sh*.c | pr -l84 -h XREF
	@ls -l | pr -l84
	@${CXREF} sh*.c | pr -l84 -h XREF
	@pr -l84 sh*.h [a-rt-z]*.h sh*.c alloc.c

vgrind:
	@cp /dev/null index
	@for i in *.h; do vgrind -t -h "C Shell" $$i >/crp/bill/csh/$$i.t; done
	@for i in *.c; do vgrind -t -h "C Shell" $$i >/crp/bill/csh/$$i.t; done
	@vgrind -t -x -h Index index >/crp/bill/csh/index.t

install: csh sh.local.h
	@install -s -c csh ${DESTROOT}/usr/new/csh
	@install -c doc/Readme.newcsh ${DESTROOT}/usr/new/Readme.newcsh
	-@nroff -man doc/newshell.1 > doc/newshell.man1
	@install -c doc/newshell.man1 ${DESTROOT}/usr/new/doc/newcsh.1

clean:
	${RM} -f a.out strings x.c xs.c csh errs
	${RM} -f *.o sh.prof.c

clobber: clean
	@${RM} -f *.[ch] M*
	@${RM} -f doc/R* doc/n*

sccsinfo:
	@echo -n ../new/newcsh:
	@sccs info
	@echo -n ./newcsh/doc:
	@(cd doc; sccs info)

sccsget:
	@sccs get -s SCCS
	@(cd doc; sccs get -s SCCS)

tags:	/tmp
	${CTAGS} sh*.c

cref:
	cref sh*.h sh*.c alloc.c > csh.xrf


