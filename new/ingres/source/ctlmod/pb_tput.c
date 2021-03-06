#ifndef lint
static	char	*sccsid = "@(#)pb_tput.c	1.1	(ULTRIX)	1/8/85";
#endif lint

/************************************************************************
 *									*
 *			Copyright (c) 1984 by				*
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

# include	"ctlmod.h"
# include	"pipes.h"


/*
**  PB_TPUT -- tagged put
**
**	Puts the symbol out to the pipe with the tag.
**
**	Parameters:
**		tag -- the type of this symbol.
**		dp -- the pointer to the data.
**		len -- the length of the data.
**		ppb -- the pipe buffer to write it on.
**
**	Returns:
**		none
**
**	Side Effects:
**		none
**
**	Trace Flags:
**		none
*/

pb_tput(tag, dp, len, ppb)
int		tag;
char		*dp;
int		len;
register pb_t	*ppb;
{
	auto char	xt;
	auto short	xlen;

	xt = tag;
	pb_put(&xt, 1, ppb);
	xlen = len;
	pb_put((char *) &xlen, 2, ppb);
	pb_put(dp, len, ppb);
}
