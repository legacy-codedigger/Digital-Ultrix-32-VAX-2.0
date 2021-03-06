#ifndef lint
static char *sccsid = "@(#)kern_xxx.c	1.5	ULTRIX	10/3/86";
#endif

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
 * Modification history:
 *
 * 11 June 86 -- Chase
 * 	Added system calls setdomainname and getdomainname.
 *
 * 24 May 85 -- depp
 *	Added "uname" system call
 *
 */

/*	kern_xxx.c	6.1	83/07/29	*/

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/kernel.h"
#include "../h/proc.h"
#include "../h/reboot.h"
#include <limits.h>
#include "../h/utsname.h"

gethostid()
{

	u.u_r.r_val1 = hostid;
}

sethostid()
{
	struct a {
		int	hostid;
	} *uap = (struct a *)u.u_ap;

	if (suser())
		hostid = uap->hostid;
}

gethostname()
{
	register struct a {
		char	*hostname;
		int	len;
	} *uap = (struct a *)u.u_ap;
	register u_int len;

	len = uap->len;
	if (len > hostnamelen + 1)
		len = hostnamelen + 1;
	u.u_error = copyout((caddr_t)hostname, (caddr_t)uap->hostname, len);
}

sethostname()
{
	register struct a {
		char	*hostname;
		u_int	len;
	} *uap = (struct a *)u.u_ap;

	if (!suser())
		return;
	if (uap->len > sizeof (hostname) - 1) {
		u.u_error = EINVAL;
		return;
	}
	hostnamelen = uap->len;
	u.u_error = copyin((caddr_t)uap->hostname, hostname, uap->len);
	hostname[hostnamelen] = 0;
}

getdomainname()
{
	register struct a {
		char	*domainname;
		int	len;
	} *uap = (struct a *)u.u_ap;
	register u_int len;

	len = uap->len;
	if (len > domainnamelen + 1)
		len = domainnamelen + 1;
	u.u_error = copyout((caddr_t)domainname,(caddr_t)uap->domainname,len);
}

setdomainname()
{
	register struct a {
		char	*domainname;
		u_int	len;
	} *uap = (struct a *)u.u_ap;

	if (!suser())
		return;
	if (uap->len > sizeof (domainname) - 1) {
		u.u_error = EINVAL;
		return;
	}
	domainnamelen = uap->len;
	u.u_error = copyin((caddr_t)uap->domainname, domainname, uap->len);
	domainname[domainnamelen] = 0;
}

/*
 *	UNAME -- This system call will fill a user supplied structure
 *		 with the data contained in the structure "utsname" from
 *		 the header file <sys/utsname.h>
 */
#ifndef RELEASE
#define RELEASE ""
#endif
#ifndef VERSION
#define VERSION ""
#endif
struct utsname utsname = {
	"ULTRIX-32",
	"",
	RELEASE,
	VERSION,
	"VAX",
};
int init = 0;

uname () {
	register struct a {
		char	*cbuf;		/* user supplied buffer */
	} *uap = (struct a *) u.u_ap;

	/* if not done, initialize utsname */
	if (!init) {
		register char *fp = hostname;
		register char *tp = utsname.nodename;
		register int i = 0;

		for( ; i < SYS_NMLN - 1 && *fp; i++)
			*tp++ = *fp++;
		*tp = NULL;

		init = 1;
	}

	if (copyout(&utsname, uap->cbuf, sizeof(struct utsname)))
		u.u_error = EFAULT;
	return;
}

reboot()
{
	register struct a {
		int	opt;
	};

	if (suser())
		boot(RB_BOOT, ((struct a *)u.u_ap)->opt);
}

#ifdef COMPAT
#include "../h/quota.h"

osetuid()
{
	register uid;
	register struct a {
		int	uid;
	} *uap;

	uap = (struct a *)u.u_ap;
	uid = uap->uid;
	if (u.u_ruid == uid || u.u_uid == uid || suser()) {
#ifdef QUOTA
		if (u.u_quota->q_uid != uid) {
			qclean();
			qstart(getquota(uid, 0, 0));
		}
#endif
		u.u_cred = crcopy(u.u_cred);
		u.u_uid = uid;
		u.u_procp->p_uid = uid;
		u.u_ruid = uid;
	}
}

osetgid()
{
	register gid;
	register struct a {
		int	gid;
	} *uap;

	uap = (struct a *)u.u_ap;
	gid = uap->gid;
	if (u.u_rgid == gid || u.u_gid == gid || suser()) {
		u.u_cred = crcopy(u.u_cred);
		leavegroup(u.u_rgid);
		(void) entergroup(gid);
		u.u_gid = gid;
		u.u_rgid = gid;
	}
}

/*
 * Pid of zero implies current process.
 * Pgrp -1 is getpgrp system call returning
 * current process group.
 */
osetpgrp()
{
	register struct proc *p;
	register struct a {
		int	pid;
		int	pgrp;
	} *uap;

	uap = (struct a *)u.u_ap;
	if (uap->pid == 0)
		p = u.u_procp;
	else {
		p = pfind(uap->pid);
		if (p == 0) {
			u.u_error = ESRCH;
			return;
		}
	}
	if (uap->pgrp <= 0) {
		u.u_r.r_val1 = p->p_pgrp;
		return;
	}
	if (p->p_uid != u.u_uid && u.u_uid && !inferior(p)) {
		u.u_error = EPERM;
		return;
	}
	p->p_pgrp = uap->pgrp;
}

otime()
{

	u.u_r.r_time = time.tv_sec;
}

ostime()
{
	register struct a {
		int	time;
	} *uap = (struct a *)u.u_ap;
	struct timeval tv;

	tv.tv_sec = uap->time;
	tv.tv_usec = 0;
	setthetime(&tv);
}

/* from old timeb.h */
struct timeb {
	time_t	time;
	u_short	millitm;
	short	timezone;
	short	dstflag;
};

oftime()
{
	register struct a {
		struct	timeb	*tp;
	} *uap;
	struct timeb tb;

	uap = (struct a *)u.u_ap;
	(void) spl7();
	tb.time = time.tv_sec;
	tb.millitm = time.tv_usec / 1000;
	(void) spl0();
	tb.timezone = tz.tz_minuteswest;
	tb.dstflag = tz.tz_dsttime;
	u.u_error = copyout((caddr_t)&tb, (caddr_t)uap->tp, sizeof (tb));
}

oalarm()
{
	register struct a {
		int	deltat;
	} *uap = (struct a *)u.u_ap;
	register struct proc *p = u.u_procp;
	int s = spl7();

	untimeout(realitexpire, (caddr_t)p);
	timerclear(&p->p_realtimer.it_interval);
	u.u_r.r_val1 = 0;
	if (timerisset(&p->p_realtimer.it_value) &&
	    timercmp(&p->p_realtimer.it_value, &time, >))
		u.u_r.r_val1 = p->p_realtimer.it_value.tv_sec - time.tv_sec;
	if (uap->deltat == 0) {
		timerclear(&p->p_realtimer.it_value);
		splx(s);
		return;
	}
	p->p_realtimer.it_value = time;
	p->p_realtimer.it_value.tv_sec += uap->deltat;
	timeout(realitexpire, (caddr_t)p, hzto(&p->p_realtimer.it_value));
	splx(s);
}

onice()
{
	register struct a {
		int	niceness;
	} *uap = (struct a *)u.u_ap;
	register struct proc *p = u.u_procp;

	donice(p, (p->p_nice-NZERO)+uap->niceness);
}

#include "../h/times.h"

otimes()
{
	register struct a {
		struct	tms *tmsb;
	} *uap = (struct a *)u.u_ap;
	struct tms atms;

	atms.tms_utime = scale60(&u.u_ru.ru_utime);
	atms.tms_stime = scale60(&u.u_ru.ru_stime);
	atms.tms_cutime = scale60(&u.u_cru.ru_utime);
	atms.tms_cstime = scale60(&u.u_cru.ru_stime);
	u.u_error = copyout((caddr_t)&atms, (caddr_t)uap->tmsb, sizeof (atms));
}

scale60(tvp)
	register struct timeval *tvp;
{

	return (tvp->tv_sec * 60 + tvp->tv_usec / 16667);
}

#include "../h/vtimes.h"

ovtimes()
{
	register struct a {
		struct	vtimes *par;
		struct	vtimes *chi;
	} *uap = (struct a *)u.u_ap;
	struct vtimes avt;

	if (uap->par) {
		getvtimes(&u.u_ru, &avt);
		u.u_error = copyout((caddr_t)&avt, (caddr_t)uap->par,
			sizeof (avt));
		if (u.u_error)
			return;
	}
	if (uap->chi) {
		getvtimes(&u.u_cru, &avt);
		u.u_error = copyout((caddr_t)&avt, (caddr_t)uap->chi,
			sizeof (avt));
		if (u.u_error)
			return;
	}
}

#include "../machine/psl.h"
#include "../machine/reg.h"

owait()
{
	struct rusage ru;
	struct vtimes *vtp, avt;

	if ((u.u_ar0[PS] & PSL_ALLCC) != PSL_ALLCC) {
		u.u_error = wait1(0, (struct rusage *)0);
		return;
	}
	vtp = (struct vtimes *)u.u_ar0[R1];
	u.u_error = wait1(u.u_ar0[R0], &ru);
	if (u.u_error)
		return;
	getvtimes(&ru, &avt);
	(void) copyout((caddr_t)&avt, (caddr_t)vtp, sizeof (struct vtimes));
}

getvtimes(aru, avt)
	register struct rusage *aru;
	register struct vtimes *avt;
{

	avt->vm_utime = scale60(&aru->ru_utime);
	avt->vm_stime = scale60(&aru->ru_stime);
	avt->vm_idsrss = ((aru->ru_idrss+aru->ru_isrss) / hz) * 60;
	avt->vm_ixrss = aru->ru_ixrss / hz * 60;
	avt->vm_maxrss = aru->ru_maxrss;
	avt->vm_majflt = aru->ru_majflt;
	avt->vm_minflt = aru->ru_minflt;
	avt->vm_nswap = aru->ru_nswap;
	avt->vm_inblk = aru->ru_inblock;
	avt->vm_oublk = aru->ru_oublock;
}

ovlimit()
{

	u.u_error = EACCES;
}

ossig()
{
	struct a {
		int	signo;
		int	(*fun)();
	} *uap = (struct a *)u.u_ap;
	register int a;
	struct sigvec vec;
	register struct sigvec *sv = &vec;
	struct proc *p = u.u_procp;

	a = uap->signo;
	sv->sv_handler = uap->fun;
	/*
	 * Kill processes trying to use job control facilities
	 * (this'll help us find any vestiges of the old stuff).
	 */
	if ((a &~ 0377) ||
	    (sv->sv_handler != SIG_DFL && sv->sv_handler != SIG_IGN &&
	     ((int)sv->sv_handler) & 1)) {
		psignal(p, SIGSYS);
		return;
	}
	if (a <= 0 || a >= NSIG || a == SIGKILL || a == SIGSTOP ||
	    a == SIGCONT && sv->sv_handler == SIG_IGN) {
		u.u_error = EINVAL;
		return;
	}
	sv->sv_mask = 0;
	sv->sv_onstack = 0;
	u.u_r.r_val1 = (int)u.u_signal[a];
	setsigvec(a, sv);
	p->p_flag |= SOUSIG;		/* mark as simulating old stuff */
}
#endif
