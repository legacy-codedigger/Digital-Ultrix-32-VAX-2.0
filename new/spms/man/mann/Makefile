DEST	      = $(DESTDIR)/usr/man/mann

MAKEFILE      = Makefile

PRINT	      = vtroff -man

SRCS	      = chproject.n \
		mkmf.n \
		mkproject.n \
		pcp.n \
		pd.n \
		pdiff.n \
		pexec.n \
		pfind.n \
		pgrep.n \
		phelp.n \
		plog.n \
		pman.n \
		pmkdir.n \
		pmv.n \
		ppd.n \
		prmdir.n \
		ptest.n \
		pwp.n \
		rmproject.n \
		spmsintro.n

SUFFIX	      = .n:s

VERSION	      = V4BSD

all:;

clean:;

co:;

depend:;

diff:;

index:;

install:;	@echo Installing $(SRCS) in $(DEST)
		@cp $(SRCS) $(DEST)

lint:;

print:		$(SRCS)
		@$(PRINT) $?
		@touch print

tags:;

update:		$(SRCS)
		@echo Installing $? in $(DEST)
		@cp $? $(DEST)
sccsget:
		sccs get SCCS

sccsinfo:
		sccs info
###
