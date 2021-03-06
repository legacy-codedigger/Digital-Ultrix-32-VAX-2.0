#ifndef lint
static char	*sccsid = " @(#)inquire.c	1.2	(ULTRIX)	1/16/86";
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
*	Based on:	inquire.c	5.2		7/30/85
*
*************************************************************************/

/*
 * inquire.c - f77 i/o inquire statement routine
 */

#include "fio.h"

f_inqu(a) inlist *a;
{	char *byfile;
	int i;
	int exist;
	unit *p;
	char buf[256], *s;
	long x_inode;

	elist = NO;
	lfname = a->infile;
	lunit = a->inunit;
	external = YES;
	p = NULL;
	if(byfile=a->infile)
	{
		g_char(a->infile,a->infilen,buf);
		if((x_inode=inode(buf))==-1)
		{	exist = NO;  /* file doesn't exist */
		}
		else
		{	exist = YES;  /* file does exist */
			for(i=0;i<MXUNIT;i++)
				if(units[i].ufd && (units[i].uinode==x_inode))
				{
					p = &units[i];
					break;
				}
		}
	}
	else
	{
		if (not_legal(lunit))
		{	exist = NO;  /* unit doesn't exist */
		}
		else
		{	exist = YES;
			if (units[lunit].ufd)
			{	p= &units[lunit];
				lfname = p->ufnm;
			}
		}
	}
	if(a->inex) *a->inex = exist;
	if(a->inopen) *a->inopen=(p!=NULL);
	if(a->innum) *a->innum = byfile?(p?(p-units):-1):lunit;
	if(a->innamed) *a->innamed= (byfile || (p && p->ufnm));
	if(a->inname)
	{
		if(byfile) s = buf;
		else if(p && p->ufnm) s = p->ufnm;
		else s="";
		b_char(s,a->inname,a->innamlen);
	}
	if(a->inacc)
	{
		if(!p) s = "unknown";
		else if(p->url) s = "direct";
		else	s = "sequential";
		b_char(s,a->inacc,a->inacclen);
	}
	if(a->inseq)
	{
		if(!p) s = "unknown";
		else s = (p && !p->url)? "yes" : "no";
		b_char(s,a->inseq,a->inseqlen);
	}
	if(a->indir)
	{
		if(!p) s = "unknown";
		else s = (p && p->useek && p->url)? "yes" : "no";
		b_char(s,a->indir,a->indirlen);
	}
	if(a->inform)
	{	if(p)
		{
#ifndef KOSHER
			if(p->uprnt) s = "print"; /*** NOT STANDARD FORTRAN ***/
			else
#endif
				s = p->ufmt?"formatted":"unformatted";
		}
		else s = "unknown";
		b_char(s,a->inform,a->informlen);
	}
	if(a->infmt)
	{
		if (p) s= p->ufmt? "yes" : "no";
		else s= "unknown";
		b_char(s,a->infmt,a->infmtlen);
	}
	if(a->inunf)
	{
		if (p) s= p->ufmt? "no" : "yes";
		else s= "unknown";
		b_char(s,a->inunf,a->inunflen);
	}
	if(a->inrecl) *a->inrecl = p ? p->url : -1;
	if(a->innrec) {
		if(p && p->url)
			*a->innrec = ((ftell(p->ufd) + p->url - 1)/p->url) + 1;
		else
			*a->innrec = -1;
	}
	if(a->inblank)
	{
		if( p && p->ufmt)
			s = p->ublnk ? "zero" : "null" ;
		else
			s = "unknown";
		b_char(s,a->inblank,a->inblanklen);
	}
	return(OK);
}
