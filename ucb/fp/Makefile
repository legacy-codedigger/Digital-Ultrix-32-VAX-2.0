# @(#)Makefile	1.3	ULTRIX	12/4/84
#
#	@(#)Makefile	4.1	(Berkeley)	83/02/24
#
#  FP interpreter/compiler, written by Scott B. Baden
#  Copyright, Regents of the University of California, 1982
#  Berkeley, California

DESTROOT =

FP_SYS = 	runFp.l fpMain.l\
		scanner.l parser.l codeGen.l\
		primFp.l utils.l fpPP.l handlers.l fpMeasures.l

FP_SYSO = 	runFp.o fpMain.o\
		scanner.o parser.o codeGen.o\
		primFp.o utils.o  fpPP.o handlers.o fpMeasures.o

.SUFFIXES:
.SUFFIXES:	.l .o
.l.o:
		liszt -axq $<


fp:		${FP_SYSO}
		/bin/rm -f fp
		echo "(progn (load 'runFp)\
			     (dumplisp fp))" | lisp > junk.fp
		chmod 755 fp

${FP_SYSO}:	specials.l fpMacs.o


install:	fp
		install -c fp ${DESTROOT}/usr/ucb/fp

clean:		
		rm -f core *.[ox] junk.fp

clobber: clean
	rm -f *.l dft.fp Makefile

sccsinfo:
	sccs info

sccsget:
	sccs get SCCS

listings:	${FP_SYS}
		print runFp.l fpMain.l scanner.l parser.l codeGen.l \
		primFp.l utils.l fpPP.l handlers.l fpMeasures.l \
		specials.l fpMacs.l  &
