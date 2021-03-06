/*
*	 @(#)fiodefs.h	1.3	(ULTRIX)	1/16/86
*/#

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
*	David Metsky		10-Jan-86
*
* 001	Replaced old version with BSD 4.3 version as part of upgrade.
*
*	Based on:	fiodefs.h	5.2		7/30/85
*
*
*	David Metsky		13-Jan-86
*
* 002	Changed uint to int_union to avoid conflict in <sys/type.h>
*
*************************************************************************/
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 *
 *	@(#)fiodefs.h	5.2 (Berkeley) 7/30/85
 */

/*
 * fortran file i/o type definitions
 */

#include <stdio.h>
#include "f_errno.h"

/* Logical Unit Table Size */
#define MXUNIT 100

#define GLITCH '\2'	/* special quote for Stu, generated in f77pass1 */

#define NAMELIST      -2
#define LISTDIRECTED  -1
#define FORMATTED      1

#define ERROR	1
#define OK	0
#define YES	1
#define NO	0

#define STDERR	0
#define STDIN	5
#define STDOUT	6

#define WRITE	1
#define READ	2
#define SEQ	3
#define DIR	4
#define FMT	5
#define UNF	6
#define EXT	7
#define INT	8

typedef char ioflag;
typedef long ftnint;
typedef ftnint flag;
typedef long ftnlen;

typedef struct		/*external read, write*/
{	flag cierr;
	ftnint ciunit;
	flag ciend;
	char *cifmt;
	ftnint cirec;
} cilist;

typedef struct		/*internal read, write*/
{	flag icierr;
	char *iciunit;
	flag iciend;
	char *icifmt;
	ftnint icirlen;
	ftnint icirnum;
	ftnint icirec;
} icilist;

typedef struct		/*open*/
{	flag oerr;
	ftnint ounit;
	char *ofnm;
	ftnlen ofnmlen;
	char *osta;
	char *oacc;
	char *ofm;
	ftnint orl;
	char *oblnk;
} olist;

typedef struct		/*close*/
{	flag cerr;
	ftnint cunit;
	char *csta;
} cllist;

typedef struct		/*rewind, backspace, endfile*/
{	flag aerr;
	ftnint aunit;
} alist;

typedef struct		/*units*/
{	FILE *ufd;	/*0=unconnected*/
	char *ufnm;
	long uinode;
	int url;	/*0=sequential*/
	flag useek;	/*true=can backspace, use dir, ...*/
	flag ufmt;
	flag uprnt;
	flag ublnk;
	flag uend;
	flag uwrt;	/*last io was write*/
	flag uscrtch;
} unit;

typedef struct		/* inquire */
{	flag inerr;
	ftnint inunit;
	char *infile;
	ftnlen infilen;
	ftnint	*inex;	/*parameters in standard's order*/
	ftnint	*inopen;
	ftnint	*innum;
	ftnint	*innamed;
	char	*inname;
	ftnlen	innamlen;
	char	*inacc;
	ftnlen	inacclen;
	char	*inseq;
	ftnlen	inseqlen;
	char 	*indir;
	ftnlen	indirlen;
	char	*inform;
	ftnlen	informlen;
	char	*infmt;
	ftnint	infmtlen;
	char	*inunf;
	ftnlen	inunflen;
	ftnint	*inrecl;
	ftnint	*innrec;
	char	*inblank;
	ftnlen	inblanklen;
} inlist;

typedef union
{	float pf;
	double pd;
} ufloat;

typedef union
{	short is;
	char ic;
	long il;
} int_union;

struct ioiflg {
	short if_oeof;
	short if_ctrl;
	short if_bzro;
};
#define	opneof	ioiflg_.if_oeof
#define	ccntrl	ioiflg_.if_ctrl
#define	blzero	ioiflg_.if_bzro
