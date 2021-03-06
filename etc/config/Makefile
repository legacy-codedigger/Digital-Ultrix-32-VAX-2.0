# @(#)Makefile	1.6	ULTRIX	12/4/84
#
#	Makefile	1.10	83/05/18
#
CFILES=	y.tab.c main.c lex.yy.c mkioconf.c mkmakefile.c \
	mkubglue.c mkheaders.c mkswapconf.c
OBJS=	y.tab.o main.o lex.yy.o mkioconf.o mkmakefile.o \
	mkubglue.o mkheaders.o mkswapconf.o

CFLAGS=-O
LDFLAGS=-ll
DESTROOT=

config: ${OBJS}
	${CC} ${OBJS} -o config ${LDFLAGS}

lex.yy.c: config.l
	lex config.l

y.tab.h: 
	yacc -d config.y

y.tab.c: config.y
	yacc config.y

clean:
	rm -f ${OBJS} lex.yy.c y.tab.c y.tab.h config errs

clobber: clean
	rm -f *.[hylco] Makefile 

sccsinfo:
	sccs info

sccsget:
	sccs get SCCS

.DEFAULT:
	sccs get $<

install: config
	install -c -s config ${DESTROOT}/etc/config

lint: ${CFILES}
	lint ${CFILES}

depend:
	grep '^#include' ${CFILES} | grep -v '<' | \
	sed -e 's/:[^"]*"\([^"]*\)".*/: \1/' \
	    -e 's/\.c/.o/' \
	    -e 's,../[a-zA-Z]*/,,' | \
	awk ' { if ($$1 != prev) { print rec; rec = $$0; prev = $$1; } \
		else { if (length(rec $$2) > 78) { print rec; rec = $$0; } \
		       else rec = rec " " $$2 } } \
	      END { print rec } ' > makedep
	echo '$$r makedep' >>eddep
	echo '/^# DO NOT DELETE THIS LINE/+1,$$d' >eddep
	echo '$$r makedep' >>eddep
	echo 'w' >>eddep
	cp Makefile Makefile.bak
	ed - Makefile < eddep
	rm eddep makedep

# DO NOT DELETE THIS LINE -- make depend uses it

y.tab.o: config.h
main.o: y.tab.h config.h
lex.yy.o: y.tab.h config.h
mkioconf.o: y.tab.h config.h
mkmakefile.o: y.tab.h config.h
mkubglue.o: config.h y.tab.h
mkheaders.o: config.h y.tab.h
mkswapconf.o: config.h
