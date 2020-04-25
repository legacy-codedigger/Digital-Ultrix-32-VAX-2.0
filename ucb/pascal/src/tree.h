/*
*	@(#)tree.h	1.2	(ULTRIX)	1/27/86
*/

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
*	Based on:	tree.h		5.2		6/5/85
*
*************************************************************************/

#define T_MINUS 1
#define T_MOD 2
#define T_DIV 3
#define T_DIVD 4
#define T_MULT 5
#define T_ADD 6
#define T_SUB 7
#define T_EQ 8
#define T_NE 9
#define T_LT 10
#define T_GT 11
#define T_LE 12
#define T_GE 13
#define T_NOT 14
#define T_AND 15
#define T_OR 16
#define T_ASGN 17
#define T_PLUS 18
#define T_IN 19
#define T_LISTPP 20
#define T_PDEC 21
#define T_FDEC 22
#define T_PVAL 23
#define T_PVAR 24
#define T_PFUNC 25
#define T_PPROC 26
#define T_NIL 27
#define T_STRNG 28
#define T_CSTRNG 29
#define T_PLUSC 30
#define T_MINUSC 31
#define T_ID 32
#define T_INT 33
#define T_FINT 34
#define T_CINT 35
#define T_CFINT 36
#define T_TYPTR 37
#define T_TYPACK 38
#define T_TYSCAL 39
#define T_TYRANG 40
#define T_TYARY 41
#define T_TYFILE 42
#define T_TYSET 43
#define T_TYREC 44
#define T_TYFIELD 45
#define T_TYVARPT 46
#define T_TYVARNT 47
#define T_CSTAT 48
#define T_BLOCK 49
#define T_BSTL 50
#define T_LABEL 51
#define T_PCALL 52
#define T_FCALL 53
#define T_CASE 54
#define T_WITH 55
#define T_WHILE 56
#define T_REPEAT 57
#define T_FORU 58
#define T_FORD 59
#define T_GOTO 60
#define T_IF 61
#define T_CSET 63
#define T_RANG 64
#define T_VAR 65
#define T_ARGL 66
#define T_ARY 67
#define T_FIELD 68
#define T_PTR 69
#define T_WEXP 70
#define T_PROG 71
#define T_BINT 72
#define T_CBINT 73
#define T_IFEL 74
#define T_IFX 75
#define T_TYID 76
#define T_COPSTR 77
#define T_BOTTLE 78
#define T_RFIELD 79
#define T_FLDLST 80
#define T_LAST 81
#define T_TYCRANG 82
#define T_TYCARY 83