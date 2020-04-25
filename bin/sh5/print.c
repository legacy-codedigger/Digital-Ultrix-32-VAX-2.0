
#ifndef lint
static	char	*sccsid = "@(#)print.c	1.1	(ULTRIX)	3/20/86";
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
/*
 *
 *   Modification History:
 *
 *
 */

/*
 * UNIX shell
 *
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"
#include	<sys/param.h>

#define		BUFLEN		256

static char	buffer[BUFLEN];
static int	index = 0;
char		numbuf[12];

extern void	prc_buff();
extern void	prs_buff();
extern void	prn_buff();
extern void	prs_cntl();
extern void	prn_buff();

/*
 * printing and io conversion
 */
prp()
{
	if ((flags & prompt) == 0 && cmdadr)
	{
		prs_cntl(cmdadr);
		prs(colon);
	}
}

prs(as)
char	*as;
{
	register char	*s;

	if (s = as)
		write(output, s, length(s) - 1);
}

prc(c)
char	c;
{
	if (c)
		write(output, &c, 1);
}

#define HZ 60	/* sysV assumed HZ was always 60, hence this kludge */
prt(t)
long	t;
{
	register int hr, min, sec;

	t += HZ / 2;
	t /= HZ;
	sec = t % HZ;
	t /= HZ;
	min = t % HZ;

	if (hr = t / HZ)
	{
		prn_buff(hr);
		prc_buff('h');
	}

	prn_buff(min);
	prc_buff('m');
	prn_buff(sec);
	prc_buff('s');
}

prn(n)
	int	n;
{
	itos(n);

	prs(numbuf);
}

itos(n)
{
	register char *abuf;
	register unsigned a, i;
	int pr, d;

	abuf = numbuf;

	pr = FALSE;
	a = n;
	for (i = 10000; i != 1; i /= 10)
	{
		if ((pr |= (d = a / i)))
			*abuf++ = d + '0';
		a %= i;
	}
	*abuf++ = a + '0';
	*abuf++ = 0;
}

stoi(icp)
char	*icp;
{
	register char	*cp = icp;
	register int	r = 0;
	register char	c;

	while ((c = *cp, digit(c)) && c && r >= 0)
	{
		r = r * 10 + c - '0';
		cp++;
	}
	if (r < 0 || cp == icp)
		failed(icp, badnum);
	else
		return(r);
}

prl(n)
long n;
{
	int i;

	i = 11;
	while (n > 0 && --i >= 0)
	{
		numbuf[i] = n % 10 + '0';
		n /= 10;
	}
	numbuf[11] = '\0';
	prs_buff(&numbuf[i]);
}

void
flushb()
{
	if (index)
	{
		buffer[index] = '\0';
		write(1, buffer, length(buffer) - 1);
		index = 0;
	}
}

void
prc_buff(c)
	char c;
{
	if (c)
	{
		if (index + 1 >= BUFLEN)
			flushb();

		buffer[index++] = c;
	}
	else
	{
		flushb();
		write(1, &c, 1);
	}
}

void
prs_buff(s)
	char *s;
{
	register int len = length(s) - 1;

	if (index + len >= BUFLEN)
		flushb();

	if (len >= BUFLEN)
		write(1, s, len);
	else
	{
		movstr(s, &buffer[index]);
		index += len;
	}
}


clear_buff()
{
	index = 0;
}


void
prs_cntl(s)
	char *s;
{
	register char *ptr = buffer;
	register char c;

	while (*s != '\0') 
	{
		c = (*s & 0177) ;
		
		/* translate a control character into a printable sequence */

		if (c < '\040') 
		{	/* assumes ASCII char */
			*ptr++ = '^';
			*ptr++ = (c + 0100);	/* assumes ASCII char */
		}
		else if (c == 0177) 
		{	/* '\0177' does not work */
			*ptr++ = '^';
			*ptr++ = '?';
		}
		else 
		{	/* printable character */
			*ptr++ = c;
		}

		++s;
	}

	*ptr = '\0';
	prs(buffer);
}


void
prn_buff(n)
	int	n;
{
	itos(n);

	prs_buff(numbuf);
}
