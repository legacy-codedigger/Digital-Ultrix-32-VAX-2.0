#ifndef lint
static char	*sccsid = "@(#)const.c	1.3	(ULTRIX)	3/14/86";
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
* 002	David L Ballenger, 14-Mar-1986
*	Change use of "const" as an identifier, since it is now a keyword.
*
*
*		David Metsky,	20-Jan-86
*
* 001	Replaced old version with BSD 4.3 version as part of upgrade
*
*	Based on:	const.c		5.2		6/21/85
*
*************************************************************************/

#include "whoami.h"
#include "0.h"
#include "tree.h"
#include "tree_ty.h"

/*
 * Const enters the definitions
 * of the constant declaration
 * part into the namelist.
 */
#ifndef PI1
constbeg( lineofyconst )
    int	lineofyconst;
{
    static bool	const_order = FALSE;
    static bool	const_seen = FALSE;

/*
 * this allows for multiple declaration
 * parts, unless the "standard" option
 * has been specified.
 * If a routine segment is being compiled,
 * do level one processing.
 */

	if (!progseen)
		level1();
	line = lineofyconst;
	if (parts[ cbn ] & (TPRT|VPRT|RPRT)) {
	    if ( opt( 's' ) ) {
		standard();
		error("Constant declarations should precede type, var and routine declarations");
	    } else {
		if ( !const_order ) {
		    const_order = TRUE;
		    warning();
		    error("Constant declarations should precede type, var and routine declarations");
		}
	    }
	}
	if (parts[ cbn ] & CPRT) {
	    if ( opt( 's' ) ) {
		standard();
		error("All constants should be declared in one const part");
	    } else {
		if ( !const_seen ) {
		    const_seen = TRUE;
		    warning();
		    error("All constants should be declared in one const part");
		}
	    }
	}
	parts[ cbn ] |= CPRT;
}
#endif PI1

const_setup(cline, cid, cdecl)
	int cline;
	register char *cid;
	register struct tnode *cdecl;
{
	register struct nl *np;

#ifdef PI0
	send(REVCNST, cline, cid, cdecl);
#endif
	line = cline;
	gconst(cdecl);
	np = enter(defnl(cid, CONST, con.ctype, con.cival));
#ifndef PI0
	np->nl_flags |= NMOD;
#endif

#ifdef PC
	if (cbn == 1) {
	    stabgconst( cid , line );
	}
#endif PC

#	ifdef PTREE
	    {
		pPointer	Const = ConstDecl( cid , cdecl );
		pPointer	*Consts;

		pSeize( PorFHeader[ nesting ] );
		Consts = &( pDEF( PorFHeader[ nesting ] ).PorFConsts );
		*Consts = ListAppend( *Consts , Const );
		pRelease( PorFHeader[ nesting ] );
	    }
#	endif
	if (con.ctype == NIL)
		return;
	if ( con.ctype == nl + TSTR )
		np->ptr[0] = (struct nl *) con.cpval;
	if (isa(con.ctype, "i"))
		np->range[0] = con.crval;
	else if (isa(con.ctype, "d"))
		np->real = con.crval;
#       ifdef PC
	    if (cbn == 1 && con.ctype != NIL) {
		    stabconst(np);
	    }
#       endif
}

#ifndef PI0
#ifndef PI1
constend()
{

}
#endif
#endif

/*
 * Gconst extracts
 * a constant declaration
 * from the tree for it.
 * only types of constants
 * are integer, reals, strings
 * and scalars, the first two
 * being possibly signed.
 */
gconst(c_node)
	struct tnode *c_node;
{
	register struct nl *np;
	register struct tnode *cn;
	char *cp;
	int negd, sgnd;
	long ci;

	con.ctype = NIL;
	cn = c_node;
	negd = sgnd = 0;
loop:
	if (cn == TR_NIL || cn->sign_const.number == TR_NIL)
		return;
	switch (cn->tag) {
		default:
			panic("gconst");
		case T_MINUSC:
			negd = 1 - negd;
		case T_PLUSC:
			sgnd++;
			cn = cn->sign_const.number;
			goto loop;
		case T_ID:
			np = lookup(cn->char_const.cptr);
			if (np == NLNIL)
				return;
			if (np->class != CONST) {
				derror("%s is a %s, not a constant as required", cn->char_const.cptr, classes[np->class]);
				return;
			}
			con.ctype = np->type;
			switch (classify(np->type)) {
				case TINT:
					con.crval = np->range[0];
					break;
				case TDOUBLE:
					con.crval = np->real;
					break;
				case TBOOL:
				case TCHAR:
				case TSCAL:
					con.cival = np->value[0];
					con.crval = con.cival;
					break;
				case TSTR:
					con.cpval = (char *) np->ptr[0];
					break;
				case NIL:
					con.ctype = NIL;
					return;
				default:
					panic("gconst2");
			}
			break;
		case T_CBINT:
			con.crval = a8tol(cn->char_const.cptr);
			goto restcon;
		case T_CINT:
			con.crval = atof(cn->char_const.cptr);
			if (con.crval > MAXINT || con.crval < MININT) {
				derror("Constant too large for this implementation");
				con.crval = 0;
			}
restcon:
			ci = con.crval;
#ifndef PI0
			if (bytes(ci, ci) <= 2)
				con.ctype = nl+T2INT;
			else	
#endif
				con.ctype = nl+T4INT;
			break;
		case T_CFINT:
			con.ctype = nl+TDOUBLE;
			con.crval = atof(cn->char_const.cptr);
			break;
		case T_CSTRNG:
			cp = cn->char_const.cptr;
			if (cp[1] == 0) {
				con.ctype = nl+T1CHAR;
				con.cival = cp[0];
				con.crval = con.cival;
				break;
			}
			con.ctype = nl+TSTR;
			con.cpval = savestr(cp);
			break;
	}
	if (sgnd) {
		if (isnta((struct nl *) con.ctype, "id"))
			derror("%s constants cannot be signed",
				nameof((struct nl *) con.ctype));
		else {
			if (negd)
				con.crval = -con.crval;
			ci = con.crval;
		}
	}
}

#ifndef PI0
isconst(cn)
	register struct tnode *cn;
{

	if (cn == TR_NIL)
		return (1);
	switch (cn->tag) {
		case T_MINUS:
			cn->tag = T_MINUSC;
			cn->sign_const.number = 
					 cn->un_expr.expr;
			return (isconst(cn->sign_const.number));
		case T_PLUS:
			cn->tag = T_PLUSC;
			cn->sign_const.number = 
					 cn->un_expr.expr;
			return (isconst(cn->sign_const.number));
		case T_VAR:
			if (cn->var_node.qual != TR_NIL)
				return (0);
			cn->tag = T_ID;
			cn->char_const.cptr = 
					cn->var_node.cptr;
			return (1);
		case T_BINT:
			cn->tag = T_CBINT;
			cn->char_const.cptr = 
				cn->const_node.cptr;
			return (1);
		case T_INT:
			cn->tag = T_CINT;
			cn->char_const.cptr = 
				cn->const_node.cptr;
			return (1);
		case T_FINT:
			cn->tag = T_CFINT;
			cn->char_const.cptr = 
				cn->const_node.cptr;
			return (1);
		case T_STRNG:
			cn->tag = T_CSTRNG;
			cn->char_const.cptr = 
				cn->const_node.cptr;
			return (1);
	}
	return (0);
}
#endif
