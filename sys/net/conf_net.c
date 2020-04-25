#ifndef lint
static	char	*sccsid = "@(#)conf_net.c	1.6		3/18/86";
#endif lint

/************************************************************************
 *									*
 *			Copyright (c) 1983 by				*
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
 *	Larry Cohen  -	01/17/86					*
 * 		Add boolean net_conservative.				*
 *		 If set then different subnet is not local.		*
 *	U. Sinkewicz - 03/18/86						*
 *		Added support for BSC 2780/3780			        *
 *								        *
 ************************************************************************/


/* resolve INET and ARP routines if not configured in to a binary system */

#include "../h/param.h"
#include "../h/mbuf.h"
#include "../h/protosw.h"
#include "../h/socket.h"
#include "../h/socketvar.h"
#include "../h/errno.h"
#include "../h/domain.h"
#include "../netinet/in_systm.h"
#include "../net/af.h"
#include "../net/if.h"
#include "../netinet/in.h"
#include "../netinet/if_ether.h"


#include "inet.h"
#include "ether.h"
#include "decnet.h"
#include "lat.h"
#include "dli.h"
#include "bsc.h"



#if (NETHER==0 || NINET==0)
	int arpioctl(a,b)
char *b;
{
	return(EOPNOTSUPP);
}
arpresolve(ac,m,destip,desten)
	struct arpcom *ac;
	struct mbuf *m;
	struct in_addr *destip;
	struct ether_addr *desten;
{
	return(0);
}

arpwhohas(ac, addr)
	register struct arpcom *ac;
	struct in_addr *addr;
{
	return(0);
}

arpinput(ac, m)
	register struct arpcom *ac;
	struct mbuf *m;
{
	return(0);
}

#endif

#if NINET==0

int nINET =0;
struct domain inetdomain;
int icmpstat, tcb, tcpstat, udb, udpstat, ipstat;

if_rtinit(ifp, i)
	struct ifnet *ifp;
int i;
{
	return(0);
}


in_netof(sin)
	struct sockaddr_in *sin;
{
return(0);
}

in_lnaof(sin)
	struct sockaddr_in *sin;
{
return(0);
}


int ipintr() 
{
	return(0);
}

int loattach() 
{
	printf("NO LOOPBACK\n");
	return(0);
}

struct in_addr 
if_makeaddr() 
{
	return;
}
#else
int nINET = 1;
#endif
#if NETHER == 0
int nETHER = 0;
#else 
int nETHER = 1;
#endif

#if NDECNET == 0
int nDECNET = 0;
dnetintr()
{
	return(0);
}
#else
int nDECNET = 1;
#endif

#if NLAT == 0
int nLAT = 0;
latintr()
{
	return(0);
}
#else
int nLAT = 1;
#endif

#if NBSC == 0
int nBSC = 0;
struct domain bscdomain;
bscintr()
{
	return(0);
}
#else
int nBSC = 1;
#endif


#if NDLI == 0
int nDLI = 0;
dliintr()
{
    return (0);
}
#else
int nDLI = 1;
#endif

#include "../net/netisr.h" 
/*
 * table of interrupt vectors - scanned in locore when sofware 
 * interrupt is posted.
 */

struct isrent {
	int isrvalue;
	int (*function)();
};


extern int rawintr(), ipintr(), nsintr(), dnetintr(), dliintr(), latintr(), bscintr();

struct isrent netisr_tab[] = {
	{NETISR_RAW,rawintr},
#ifdef INET
	{NETISR_IP,ipintr},
#endif INET
#ifdef NS
	{NETISR_NS,nsintr},
#endif NS
#ifdef DECNET
	{NETISR_DN,dnetintr},
#endif DECNET
#ifdef DLI
	{NETISR_DLI,dliintr},
#endif DLI
#ifdef BSC
	{NETISR_BSC,bscintr},
#endif BSC
#ifdef LAT
	{NETISR_LAT,latintr},
#endif LAT
	{-1	,0}
};

#ifdef NETCONSERVE
int net_conservative = 1;
#else
int net_conservative = 0;
#endif
