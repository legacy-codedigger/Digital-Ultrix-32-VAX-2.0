#ifndef lint
static	char	*sccsid = "@(#)utime.c	1.1	(ULTRIX)	3/31/85";
#endif lint

/************************************************************************
 *									*
 *			Copyright (c) 1985 by				*
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
 *			Modification History				*
 *									*
 *	David L Ballenger, 29-Mar-1985					*
 * 0001	Use definitions from <sys/time.h> and real interface for 	*
 *	utimes().			*
 *									*
 ************************************************************************/

/*
	utime -- system call emulation for 4.2BSD

	last edit:	14-Dec-1983	D A Gwyn
*/

#include	<sys/types.h>
#include	<sys/time.h>

extern int	utimes();
extern long	time();

#define NULL	0

typedef struct
	{
	time_t	actime;
	time_t	modtime;
	}	utimbuf;

int
utime( path, times )
	char	*path;			/* file to be updated */
	utimbuf *times; 		/* -> new access/mod times */
	{
	struct timeval	tv[2];
	utimbuf mybuf;			/* contains current time */

	if ( times == NULL )
		{
		mybuf.actime = time( &mybuf.modtime );
		times = &mybuf;
		}

	tv[0].tv_sec = times->actime;
	tv[0].tv_usec = 0L;
	tv[1].tv_sec = times->modtime;
	tv[1].tv_usec = 0L;

	return utimes( path, tv );
	}
