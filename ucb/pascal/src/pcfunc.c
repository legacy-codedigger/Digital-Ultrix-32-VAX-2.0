#ifndef lint
static char	*sccsid = "@(#)pcfunc.c	1.2	(ULTRIX)	1/27/86";
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
*	Based on:	pcfunc.c	5.1		6/5/85
*
*************************************************************************/

#include "whoami.h"
#ifdef PC
    /*
     *	and to the end of the file
     */
#include "0.h"
#include "tree.h"
#include "objfmt.h"
#include "opcode.h"
#include "pc.h"
#include "../../../usr.bin/f77/include/pcc.h"
#include "tmps.h"
#include "tree_ty.h"

/*
 * Funccod generates code for
 * built in function calls and calls
 * call to generate calls to user
 * defined functions and procedures.
 */
struct nl *
pcfunccod( r )
	struct tnode	 *r; /* T_FCALL */
{
	struct nl *p;
	register struct nl *p1;
	register struct tnode *al;
	register op;
	int argc;
	struct tnode *argv;
	struct tnode tr, tr2;
	char		*funcname;
	struct nl	*tempnlp;
	long		temptype;
	struct nl	*rettype;

	/*
	 * Verify that the given name
	 * is defined and the name of
	 * a function.
	 */
	p = lookup(r->pcall_node.proc_id);
	if (p == NLNIL) {
		rvlist(r->pcall_node.arg);
		return (NLNIL);
	}
	if (p->class != FUNC && p->class != FFUNC) {
		error("%s is not a function", p->symbol);
		rvlist(r->pcall_node.arg);
		return (NLNIL);
	}
	argv = r->pcall_node.arg;
	/*
	 * Call handles user defined
	 * procedures and functions
	 */
	if (bn != 0)
		return (call(p, argv, FUNC, bn));
	/*
	 * Count the arguments
	 */
	argc = 0;
	for (al = argv; al != TR_NIL; al = al->list_node.next)
		argc++;
	/*
	 * Built-in functions have
	 * their interpreter opcode
	 * associated with them.
	 */
	op = p->value[0] &~ NSTAND;
	if (opt('s') && (p->value[0] & NSTAND)) {
		standard();
		error("%s is a nonstandard function", p->symbol);
	}
	if ( op == O_ARGC ) {
	    putleaf( PCC_NAME , 0 , 0 , PCCT_INT , "__argc" );
	    return nl + T4INT;
	}
	switch (op) {
		/*
		 * Parameterless functions
		 */
		case O_CLCK:
			funcname = "_CLCK";
			goto noargs;
		case O_SCLCK:
			funcname = "_SCLCK";
			goto noargs;
noargs:
			if (argc != 0) {
				error("%s takes no arguments", p->symbol);
				rvlist(argv);
				return (NLNIL);
			}
			putleaf( PCC_ICON , 0 , 0
				, PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR )
				, funcname );
			putop( PCCOM_UNARY PCC_CALL , PCCT_INT );
			return (nl+T4INT);
		case O_WCLCK:
			if (argc != 0) {
				error("%s takes no arguments", p->symbol);
				rvlist(argv);
				return (NLNIL);
			}
			putleaf( PCC_ICON , 0 , 0
				, PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR )
				, "_time" );
			putleaf( PCC_ICON , 0 , 0 , PCCT_INT , (char *) 0 );
			putop( PCC_CALL , PCCT_INT );
			return (nl+T4INT);
		case O_EOF:
		case O_EOLN:
			if (argc == 0) {
				argv = &(tr);
				tr.list_node.list = &(tr2);
				tr2.tag = T_VAR;
				tr2.var_node.cptr = input->symbol;
				tr2.var_node.line_no = NIL;
				tr2.var_node.qual = TR_NIL;
				argc = 1;
			} else if (argc != 1) {
				error("%s takes either zero or one argument", p->symbol);
				rvlist(argv);
				return (NLNIL);
			}
		}
	/*
	 * All other functions take
	 * exactly one argument.
	 */
	if (argc != 1) {
		error("%s takes exactly one argument", p->symbol);
		rvlist(argv);
		return (NLNIL);
	}
	/*
	 * find out the type of the argument
	 */
	codeoff();
	p1 = stkrval( argv->list_node.list, NLNIL , (long) RREQ );
	codeon();
	if (p1 == NLNIL)
		return (NLNIL);
	/*
	 * figure out the return type and the funtion name
	 */
	switch (op) {
	    case 0:
			error("%s is an unimplemented 6000-3.4 extension", p->symbol);
	    default:
			panic("func1");
	    case O_EXP:
		    funcname = opt('t') ? "_EXP" : "_exp";
		    goto mathfunc;
	    case O_SIN:
		    funcname = opt('t') ? "_SIN" : "_sin";
		    goto mathfunc;
	    case O_COS:
		    funcname = opt('t') ? "_COS" : "_cos";
		    goto mathfunc;
	    case O_ATAN:
		    funcname = opt('t') ? "_ATAN" : "_atan";
		    goto mathfunc;
	    case O_LN:
		    funcname = opt('t') ? "_LN" : "_log";
		    goto mathfunc;
	    case O_SQRT:
		    funcname = opt('t') ? "_SQRT" : "_sqrt";
		    goto mathfunc;
	    case O_RANDOM:
		    funcname = "_RANDOM";
		    goto mathfunc;
mathfunc:
		    if (isnta(p1, "id")) {
			    error("%s's argument must be integer or real, not %s", p->symbol, nameof(p1));
			    return (NLNIL);
		    }
		    putleaf( PCC_ICON , 0 , 0
			    , PCCM_ADDTYPE( PCCTM_FTN | PCCT_DOUBLE , PCCTM_PTR ) , funcname );
		    p1 = stkrval(  argv->list_node.list , NLNIL , (long) RREQ );
		    sconv(p2type(p1), PCCT_DOUBLE);
		    putop( PCC_CALL , PCCT_DOUBLE );
		    return nl + TDOUBLE;
	    case O_EXPO:
		    if (isnta( p1 , "id" ) ) {
			    error("%s's argument must be integer or real, not %s", p->symbol, nameof(p1));
			    return NIL;
		    }
		    putleaf( PCC_ICON , 0 , 0
			    , PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR ) , "_EXPO" );
		    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
		    sconv(p2type(p1), PCCT_DOUBLE);
		    putop( PCC_CALL , PCCT_INT );
		    return ( nl + T4INT );
	    case O_UNDEF:
		    if ( isnta( p1 , "id" ) ) {
			    error("%s's argument must be integer or real, not %s", p->symbol, nameof(p1));
			    return NLNIL;
		    }
		    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
		    putleaf( PCC_ICON , 0 , 0 , PCCT_CHAR , (char *) 0 );
		    putop( PCC_COMOP , PCCT_CHAR );
		    return ( nl + TBOOL );
	    case O_SEED:
		    if (isnta(p1, "i")) {
			    error("seed's argument must be an integer, not %s", nameof(p1));
			    return (NLNIL);
		    }
		    putleaf( PCC_ICON , 0 , 0
			    , PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR ) , "_SEED" );
		    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
		    putop( PCC_CALL , PCCT_INT );
		    return nl + T4INT;
	    case O_ROUND:
	    case O_TRUNC:
		    if ( isnta( p1 , "d" ) ) {
			    error("%s's argument must be a real, not %s", p->symbol, nameof(p1));
			    return (NLNIL);
		    }
		    putleaf( PCC_ICON , 0 , 0
			    , PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR )
			    , op == O_ROUND ? "_ROUND" : "_TRUNC" );
		    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
		    putop( PCC_CALL , PCCT_INT );
		    return nl + T4INT;
	    case O_ABS2:
			if ( isa( p1 , "d" ) ) {
			    putleaf( PCC_ICON , 0 , 0
				, PCCM_ADDTYPE( PCCTM_FTN | PCCT_DOUBLE , PCCTM_PTR )
				, "_fabs" );
			    p1 = stkrval( argv->list_node.list , NLNIL ,(long) RREQ );
			    putop( PCC_CALL , PCCT_DOUBLE );
			    return nl + TDOUBLE;
			}
			if ( isa( p1 , "i" ) ) {
			    putleaf( PCC_ICON , 0 , 0
				, PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR ) , "_abs" );
			    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
			    putop( PCC_CALL , PCCT_INT );
			    return nl + T4INT;
			}
			error("%s's argument must be an integer or real, not %s", p->symbol, nameof(p1));
			return NLNIL;
	    case O_SQR2:
			if ( isa( p1 , "d" ) ) {
			    temptype = PCCT_DOUBLE;
			    rettype = nl + TDOUBLE;
			    tempnlp = tmpalloc((long) (sizeof(double)), rettype, REGOK);
			} else if ( isa( p1 , "i" ) ) {
			    temptype = PCCT_INT;
			    rettype = nl + T4INT;
			    tempnlp = tmpalloc((long) (sizeof(long)), rettype, REGOK);
			} else {
			    error("%s's argument must be an integer or real, not %s", p->symbol, nameof(p1));
			    return NLNIL;
			}
			putRV( (char *) 0 , cbn , tempnlp -> value[ NL_OFFS ] ,
				tempnlp -> extra_flags , (char) temptype  );
			p1 = rvalue( argv->list_node.list , NLNIL , RREQ );
			sconv(p2type(p1), (int) temptype);
			putop( PCC_ASSIGN , (int) temptype );
			putRV((char *) 0 , cbn , tempnlp -> value[ NL_OFFS ] ,
				tempnlp -> extra_flags , (char) temptype );
			putRV((char *) 0 , cbn , tempnlp -> value[ NL_OFFS ] ,
				tempnlp -> extra_flags , (char) temptype );
			putop( PCC_MUL , (int) temptype );
			putop( PCC_COMOP , (int) temptype );
			return rettype;
	    case O_ORD2:
			p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
			if (isa(p1, "bcis")) {
				return (nl+T4INT);
			}
			if (classify(p1) == TPTR) {
			    if (!opt('s')) {
				return (nl+T4INT);
			    }
			    standard();
			}
			error("ord's argument must be of scalar type, not %s",
				nameof(p1));
			return (NLNIL);
	    case O_SUCC2:
	    case O_PRED2:
			if (isa(p1, "d")) {
				error("%s is forbidden for reals", p->symbol);
				return (NLNIL);
			}
			if ( isnta( p1 , "bcsi" ) ) {
			    error("%s's argument must be of scalar type, not %s", p->symbol, nameof(p1));
			    return NLNIL;
			}
			if ( opt( 't' ) ) {
			    putleaf( PCC_ICON , 0 , 0
				    , PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR )
				    , op == O_SUCC2 ? "_SUCC" : "_PRED" );
			    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
			    tempnlp = p1 -> class == TYPE ? p1 -> type : p1;
			    putleaf( PCC_ICON, (int) tempnlp -> range[0], 0, PCCT_INT, (char *) 0 );
			    putop( PCC_CM , PCCT_INT );
			    putleaf( PCC_ICON, (int) tempnlp -> range[1], 0, PCCT_INT, (char *) 0 );
			    putop( PCC_CM , PCCT_INT );
			    putop( PCC_CALL , PCCT_INT );
			    sconv(PCCT_INT, p2type(p1));
			} else {
			    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
			    putleaf( PCC_ICON , 1 , 0 , PCCT_INT , (char *) 0 );
			    putop( op == O_SUCC2 ? PCC_PLUS : PCC_MINUS , PCCT_INT );
			    sconv(PCCT_INT, p2type(p1));
			}
			if ( isa( p1 , "bcs" ) ) {
			    return p1;
			} else {
			    return nl + T4INT;
			}
	    case O_ODD2:
			if (isnta(p1, "i")) {
				error("odd's argument must be an integer, not %s", nameof(p1));
				return (NLNIL);
			}
			p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
			    /*
			     *	THIS IS MACHINE-DEPENDENT!!!
			     */
			putleaf( PCC_ICON , 1 , 0 , PCCT_INT , (char *) 0 );
			putop( PCC_AND , PCCT_INT );
			sconv(PCCT_INT, PCCT_CHAR);
			return nl + TBOOL;
	    case O_CHR2:
			if (isnta(p1, "i")) {
				error("chr's argument must be an integer, not %s", nameof(p1));
				return (NLNIL);
			}
			if (opt('t')) {
			    putleaf( PCC_ICON , 0 , 0
				, PCCM_ADDTYPE( PCCTM_FTN | PCCT_CHAR , PCCTM_PTR ) , "_CHR" );
			    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
			    putop( PCC_CALL , PCCT_CHAR );
			} else {
			    p1 = stkrval( argv->list_node.list , NLNIL , (long) RREQ );
			    sconv(PCCT_INT, PCCT_CHAR);
			}
			return nl + TCHAR;
	    case O_CARD:
			if (isnta(p1, "t")) {
			    error("Argument to card must be a set, not %s", nameof(p1));
			    return (NLNIL);
			}
			putleaf( PCC_ICON , 0 , 0
			    , PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR ) , "_CARD" );
			p1 = stkrval( argv->list_node.list , NLNIL , (long) LREQ );
			putleaf( PCC_ICON , (int) lwidth( p1 ) , 0 , PCCT_INT , (char *) 0 );
			putop( PCC_CM , PCCT_INT );
			putop( PCC_CALL , PCCT_INT );
			return nl + T4INT;
	    case O_EOLN:
			if (!text(p1)) {
				error("Argument to eoln must be a text file, not %s", nameof(p1));
				return (NLNIL);
			}
			putleaf( PCC_ICON , 0 , 0
			    , PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR ) , "_TEOLN" );
			p1 = stklval( argv->list_node.list , NOFLAGS );
			putop( PCC_CALL , PCCT_INT );
			sconv(PCCT_INT, PCCT_CHAR);
			return nl + TBOOL;
	    case O_EOF:
			if (p1->class != FILET) {
				error("Argument to eof must be file, not %s", nameof(p1));
				return (NLNIL);
			}
			putleaf( PCC_ICON , 0 , 0
			    , PCCM_ADDTYPE( PCCTM_FTN | PCCT_INT , PCCTM_PTR ) , "_TEOF" );
			p1 = stklval( argv->list_node.list , NOFLAGS );
			putop( PCC_CALL , PCCT_INT );
			sconv(PCCT_INT, PCCT_CHAR);
			return nl + TBOOL;
	}
}
#endif PC
