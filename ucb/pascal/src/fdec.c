#ifndef lint
static char	*sccsid = "@(#)fdec.c	1.2	(ULTRIX)	1/27/86";
#endif lint

/************************************************************************
 *									*
 *			Copyright (c) 1986 by				*
 *		Digital Equipment Corporation, Maynard, MA		*
 *			All rights reserved.				*
 *									*
 *   This software is furnished under a license and may be used and	*
 *   copied  only  in accordance with the terms of such license and	*
 *   with the  inclusion  of  the  above  copyright  notice.   This	*
 *   software  or  any  other copies thereof may not be provided or	*
 *   otherwise made available to any other person.  No title to and	*
 *   ownership of the software is hereby transferred.			*
 *									*
 *   This software is  derived  from  software  received  from  the	*
 *   University    of   California,   Berkeley,   and   from   Bell	*
 *   Laboratories.  Use, duplication, or disclosure is  subject  to	*
 *   restrictions  under  license  agreements  with  University  of	*
 *   California and with AT&T.						*
 *									*
 *   The information in this software is subject to change  without	*
 *   notice  and should not be construed as a commitment by Digital	*
 *   Equipment Corporation.						*
 *									*
 *   Digital assumes no responsibility for the use  or  reliability	*
 *   of its software on equipment which is not supplied by Digital.	*
 *									*
 ************************************************************************/

/************************************************************************
*
*			Modification History
*
*		David Metsky,	20-Jan-86
*
* 001	Replaced old version with BSD 4.3 version as part of upgrade
*
*	Based on:	fdec.c		5.1		6.5.85
*
*************************************************************************/

#include "whoami.h"
#include "0.h"
#include "tree.h"
#include "opcode.h"
#include "objfmt.h"
#include "align.h"
#include "tmps.h"

/*
 * this array keeps the pxp counters associated with
 * functions and procedures, so that they can be output
 * when their bodies are encountered
 */
int	bodycnts[ DSPLYSZ ];

#ifdef PC
#   include "pc.h"
#   include "../../../usr.bin/f77/include/pcc.h"
#endif PC

#ifdef OBJ
int	cntpatch;
int	nfppatch;
#endif OBJ

funcfwd(fp)
	struct nl *fp;
{

	    /*
	     *	save the counter for this function
	     */
	if ( monflg ) {
	    fp -> value[ NL_CNTR ] = bodycnts[ cbn ];
	}
}

/*
 * Funcext marks the procedure or
 * function external in the symbol
 * table. Funcext should only be
 * called if PC, and is an error
 * otherwise.
 */

struct nl *
funcext(fp)
	struct nl *fp;
{

#ifdef OBJ
	error("Procedures or functions cannot be declared external.");
#endif OBJ

#ifdef PC
	    /*
	     *	save the counter for this function
	     */
	if ( monflg ) {
	    fp -> value[ NL_CNTR ] = bodycnts[ cbn ];
	}
 	if (opt('s')) {
		standard();
		error("External procedures and functions are not standard");
	} else {
		if (cbn == 1) {
			fp->extra_flags |= NEXTERN;
			stabefunc( fp -> symbol , fp -> class , line );
		}
		else
			error("External procedures and functions can only be declared at the outermost level.");
	}
#endif PC

	return(fp);
}

/*
 * Funcbody is called
 * when the actual (resolved)
 * declaration of a procedure is
 * encountered. It puts the names
 * of the (function) and parameters
 * into the symbol table.
 */
struct nl *
funcbody(fp)
	struct nl *fp;
{
	register struct nl *q;

	cbn++;
	if (cbn >= DSPLYSZ) {
		error("Too many levels of function/procedure nesting");
		pexit(ERRS);
	}
	tmpinit(cbn);
	gotos[cbn] = NIL;
	errcnt[cbn] = syneflg;
	parts[ cbn ] = NIL;
	dfiles[ cbn ] = FALSE;
	if (fp == NIL)
		return (NIL);
	/*
	 * Save the virtual name
	 * list stack pointer so
	 * the space can be freed
	 * later (funcend).
	 */
	fp->ptr[2] = nlp;
	if (fp->class != PROG) {
		for (q = fp->chain; q != NIL; q = q->chain) {
			(void) enter(q);
#			ifdef PC
			    q -> extra_flags |= NPARAM;
#			endif PC
		}
	}
	if (fp->class == FUNC) {
		/*
		 * For functions, enter the fvar
		 */
		(void) enter(fp->ptr[NL_FVAR]);
#		ifdef PC
		    q = fp -> ptr[ NL_FVAR ];
		    if (q -> type != NIL ) {
			sizes[cbn].curtmps.om_off = q -> value[NL_OFFS];
			sizes[cbn].om_max = q -> value[NL_OFFS];
		    }
#		endif PC
	}
#	ifdef PTREE
		/*
		 *	pick up the pointer to porf declaration
		 */
	    PorFHeader[ ++nesting ] = fp -> inTree;
#	endif PTREE
	return (fp);
}

/*
 * Segend is called to check for
 * unresolved variables, funcs and
 * procs, and deliver unresolved and
 * baduse error diagnostics at the
 * end of a routine segment (a separately
 * compiled segment that is not the 
 * main program) for PC. This
 * routine should only be called
 * by PC (not standard).
 */
 segend()
 {
#ifdef PC
	register struct nl *p;
	register int i,b;
	char *cp;

	if ( monflg ) {
	    error("Only the module containing the \"program\" statement");
	    cerror("can be profiled with ``pxp''.\n");
	}
	if (opt('s')) {
		standard();
		error("Separately compiled routine segments are not standard.");
	} else {
		b = cbn;
		for (i=0; i<077; i++) {
			for (p = disptab[i]; p != NIL && (p->nl_block & 037) == b; p = p->nl_next) {
			switch (p->class) {
				case BADUSE:
					cp = "s";
					if (((struct udinfo *) (p->chain))->ud_next == NIL)
						cp++;
					eholdnl();
					if (p->value[NL_KINDS] & ISUNDEF)
						nerror("%s undefined on line%s", p->symbol, cp);
					else
						nerror("%s improperly used on line%s", p->symbol, cp);
					pnumcnt = 10;
					pnums((struct udinfo *) (p->chain));
					pchr('\n');
					break;
				
				case FUNC:
				case PROC:
					if ((p->nl_flags & NFORWD) &&
					    ((p->extra_flags & NEXTERN) == 0))
						nerror("Unresolved forward declaration of %s %s", classes[p->class], p->symbol);
					break;

				case FVAR:
					if (((p->nl_flags & NMOD) == 0) &&
					    ((p->chain->extra_flags & NEXTERN) == 0))
						nerror("No assignment to the function variable");
					break;
			    }
			   }
			   disptab[i] = p;
		    }
	}
#endif PC
#ifdef OBJ
	error("Missing program statement and program body");
#endif OBJ

}


/*
 * Level1 does level one processing for
 * separately compiled routine segments
 */
level1()
{

#	ifdef OBJ
	    error("Missing program statement");
#	endif OBJ
#	ifdef PC
	    if (opt('s')) {
		    standard();
		    error("Missing program statement");
	    }
#	endif PC

	cbn++;
	tmpinit(cbn);
	gotos[cbn] = NIL;
	errcnt[cbn] = syneflg;
	parts[ cbn ] = NIL;
	dfiles[ cbn ] = FALSE;
	progseen = TRUE;
}



pnums(p)
	struct udinfo *p;
{

	if (p->ud_next != NIL)
		pnums(p->ud_next);
	if (pnumcnt == 0) {
		printf("\n\t");
		pnumcnt = 20;
	}
	pnumcnt--;
	printf(" %d", p->ud_line);
}

/*VARARGS*/
nerror(a1, a2, a3)
    char *a1,*a2,*a3;
{

	if (Fp != NIL) {
		yySsync();
#ifndef PI1
		if (opt('l'))
			yyoutline();
#endif
		yysetfile(filename);
		printf("In %s %s:\n", classes[Fp->class], Fp->symbol);
		Fp = NIL;
		elineoff();
	}
	error(a1, a2, a3);
}
