#ifndef lint
static char	*sccsid = " @(#)util.c	1.2	(ULTRIX)	1/16/86";
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
*	David Metsky		10-Jan-86
*
* 001	Replaced old version with BSD 4.3 version as part of upgrade.
*
*	Based on:	util.c		5.1		6/7/85
*
*************************************************************************/

/*
 * utility routines
 */

#include "fio.h"

extern short	ccntrl_, blzero_;

nowreading(x) unit *x;
{
	return(now_acc(x,"r"));
}

nowwriting(x) unit *x;
{
	return(now_acc(x,"a"));
}

LOCAL now_acc(x,mode)
unit *x; char *mode;
{
	long loc;

	if (!x->ufnm)
	{
		errno = EBADF;
		return(NO);
	}
	if (x->useek)
		loc=ftell(x->ufd);
	if (freopen(x->ufnm,mode,x->ufd))
	{
		if (x->useek)
			fseek(x->ufd,loc,0);
		x->uwrt = (*mode=='a');
		return(YES);
	}
	if (x->ufd = fopen(x->ufnm, (*mode=='a')? "r":"a"))
		if (x->useek)
			fseek(x->ufd,loc,0);
	return(NO);
}

g_char(a,alen,b) char *a,*b; ftnlen alen;
{	char *x=a+alen-1, *y=b+alen-1;
	while (x >= a  &&  *x == ' ') {x--; y--;}
	*(y+1) = '\0';
	while (x >= a) *y-- = *x--;
}

b_char(from, to, tolen) char *from, *to; ftnlen tolen;
{	int i=0;
	while (*from && i < tolen) {
		*to++ = *from++;
		i++;
	}
	while (i++ < tolen)
		*to++ = ' ';
}

char
last_char(f) FILE *f;
{
	fseek(f,-2L,1);
	if(ftell(f)) return(getc(f));
	else return('\n');
}
