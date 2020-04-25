#ifndef lint
static char *sccsid = "@(#)generic.c	1.7	ULTRIX	1/29/87";
#endif lint

/************************************************************************
 *                                                                      *
 *                      Copyright (c) 1985 by                           *
 *              Digital Equipment Corporation, Maynard, MA              *
 *                      All rights reserved.                            *
 *                                                                      *
 *   This software is furnished under a license and may be used and     *
 *   copied  only  in accordance with the terms of such license and     *
 *   with the  inclusion  of  the  above  copyright  notice.   This     *
 *   software  or  any  other copies thereof may not be provided or     *
 *   otherwise made available to any other person.  No title to and     *
 *   ownership of the software is hereby transferred.                   *
 *                                                                      *
 *   This software is  derived  from  software  received  from  the     *
 *   University    of   California,   Berkeley,   and   from   Bell     *
 *   Laboratories.  Use, duplication, or disclosure is  subject  to     *
 *   restrictions  under  license  agreements  with  University  of     *
 *   California and with AT&T.                                          *
 *                                                                      *
 *   The information in this software is subject to change  without     *
 *   notice  and should not be construed as a commitment by Digital     *
 *   Equipment Corporation.                                             *
 *                                                                      *
 *   Digital assumes no responsibility for the use  or  reliability     *
 *   of its software on equipment which is not supplied by Digital.     *
 *                                                                      *
 ************************************************************************/



/*
 * 28-Jan-1987 - Marc Teitelbaum
 *		Fix to only TIOCFLUSH the input queue. Previously
 *		it was flushing the output queue before all the
 *		dial characters got out to the modem.  This is why
 *		short delays between characters didn't work - not
 *		because the modems couldn't handle the speed - but
 *		rather because the last few dial chars were sweeped 
 *		off the tty output queue and never got to the modem.
 *		Also, check the return code of writes in output(),
 *		and if debug is set, report unsuccessful writes.
 * 14-Jan-1987 - Marc Teitelbaum
 *		Add TIOCMODEM ioctl.  Uucp generic forgot to, and its
 *		better done here anyway.  Add ability to imbed one
 *		second delays in the strings (\d).  These are a must
 *		for getting the most out of (really) smart modems
 *		like the hayes.  Change the delay sent on the abort
 *		and disconnect strings to dialdel.  It was set to "1",
 *		which, if lsleep is set, is ridiculousely small.
 * 12-Sep-1986 - Marc Teitelbaum
 *		Fix dialer hang.  If the acucap entry specified a
 *		disconnect or abort string, and the dial failed, then
 *		the write would hang waiting for carrier (but WITHOUT
 *		a timeout).  The fix is to again set TIOCNCAR to ignore
 *		carrier while writing the abort or disconnect string.
 * 11-05-85	Bugfix. Reset timedout to 0 else uucp can get into
 *		a state where it hangs up on people (thinks an 
 *		error has happened even though it has not).
 * 10-14-85     Changed input debug messages. Added replacestr to account
 *		for uucp's use of '-' to mean delay. This string 
 *		allows a characters worth of substitution whenever the
 *		characters '-' OR '=' are seen in the phone number.	
 * 10-10-85	Changed how response strings come back. Now will
 *		only eat up to a match. Otherwise, will eat everything
 *		in typeahead looking for respstr. Also added new
 *		string 'os' as what is seen when we really get a 
 *		carrier. Finally added 'si' boolean for modem
 *		attached to stupid interfaces such as dmf32 which
 *		only passes chars back after carrier/CTS/DCD are
 *		present. lp@decvax 
 * Routines for calling up on any modem.
 *              by lp@decvax  3/12/85
 */

#include <sys/time.h>
#include <sgtty.h>
#include <signal.h>
#include <stdio.h>
#include <setjmp.h>
#include <errno.h>
#include <sys/file.h>

#define NOSYNC 1
#define BADDIAL 2
#define NOCAR 3
#define GENBUF 512
#define DEFDELAY 1

static  int genALRM();
static  int timerALRM();
static int timedout;
static  jmp_buf timeoutbuf, alrmbuf;
char *syncstr, *respstr, *dialstr, *respdial, *abostr, *onlstr,
		*disconstr, charup, *compstr, hangup, dtr, stupidi,
		*respsync, *dialterm, lsleep, debugn, *replacestr;
int syncdel, dialdel, cdelay, compdel, dialack;
int FDD;
int generrno;

gen_dialer(num, acu)
	register char *num;
	char *acu;
{
	char junk[GENBUF];
	char errd = 0;
	int fread = FREAD;
	int zero = 0;

	generrno = timedout = 0;

	if(debugn) {
	fprintf(stderr,"Entering generic dialer routine for %s\n", acu);
	fprintf(stderr,"num = %s\n", num);
	fprintf(stderr,"syncs = %s\ndialstr = %s\n", syncstr, dialstr);
	fprintf(stderr,"respsync = %s\n", respsync);
	fprintf(stderr,"compstr = %s\n", compstr);
	fprintf(stderr,"charup %d\nhangup %d\ndtr %d\n", charup, hangup, dtr);
	fprintf(stderr,"lsleep %d stupidi %d\n", lsleep, stupidi);
	fprintf(stderr,"dialdel = %d\ncdelay = %d\n", dialdel, cdelay);
	fprintf(stderr,"dialterm = %s\n", dialterm);
	}

	/* 
	 * The TIOCNCAR is to temporarily ignore carrier so we can
	 * dial the modem.  It was probably already done earlier on by
	 * tip or uucp, but we shouldn't be at their mercy and it belongs 
	 * here anyway.  
	 * ---
	 * The TIOCMODEM turns on modem control for the line. It was accidently
	 * left out of the uucp routine in condevs.c which calls this driver.
	 * I conclude - as stated above - that the modem control ioctls are
	 * better done here to catch all cases.  So, instead of fixing it
	 * in condevs.c i do it here.  This makes sure also, if we ever choose
	 * to make this driver part of a user available library, that there is
	 * a better chance of getting things right.
	 */
	ioctl(FDD, TIOCMODEM, &zero);	
	ioctl(FDD, TIOCNCAR);	
			
	/*
	 * Get in sync
	 */
		if (!gensync()) {
			errd = NOSYNC;
		}

	/*
	 * If boolean hangup then we will hangup on any problems
	 */

	if (hangup) {
		ioctl(FDD, TIOCHPCL, 0);
	} else {
		/* don't have any way to undo it yet... */
	}
		
	/*
	 * All generic dialers have to do some type of dialing!
	 */

	if (!errd) {
		if (!gendial(num)) {
			gen_disconnect();
			errd = BADDIAL;
		}
		/* Flush the input queue (not the output queue!) */
		ioctl(FDD, TIOCFLUSH, &fread);
	}

	/*
	 * online waits some defined time for the carrier
	 * to come up. If it doesnt the remote system might be down
	 */

	if (!errd) {
	   if (!online()) {
		gen_disconnect();
		errd = NOCAR;
	   }
	}

	/*
	 * Finish up sequence (if any) 
	 */

	if (!errd) {
	   if (*compstr != 0) { 
		output(compstr,compdel);
	   }
	}
	   
	if (timedout || errd) {
		gen_disconnect();       /* insurance */
		generrno = errd;
		return (0);
	}

	generrno = 0;
	return (1);
}

gen_disconnect()
{
	if(debugn)
		fprintf(stderr,"gendisconnect\n");

	if(*disconstr)  {
		ioctl(FDD, TIOCNCAR);  /* insure we don't hang */
		sleep(DEFDELAY);
		output(disconstr,dialdel);
		sleep(DEFDELAY);
	}
	close(FDD);
}

gen_abort()
{

	if(*abostr) {
		ioctl(FDD, TIOCNCAR);	/* insure we don't hang */
		output(abostr,dialdel);
	}
	close(FDD);
}

static int
genALRM()
{

	timedout = 1;
	longjmp(timeoutbuf, 1);
}

gendial(num)
char *num;
{
	char obuf[GENBUF];
	char respbuf[GENBUF];
	char junk[GENBUF];

	if(debugn)
		fprintf(stderr,"gendial\n");
	if (*dialstr) {
		if(*replacestr) {
			char *p1 = num;
			while(*p1) {
				if(*p1 == '=' || *p1 == '-')
					*p1 = *replacestr;
				p1++;
			}
		}
		obuf[0]='\0';
		strcat(obuf, dialstr);
		strcat(obuf, num);
		if (*dialterm)
			strcat(obuf, dialterm);
		if(debugn)
			fprintf(stderr,"dials = %s\n", obuf);
		output(obuf, dialdel);
	}

	if (*respdial) {
		if(lsleep)
			usleep(dialack);
		else
			sleep(dialack);
		if(!input(&respbuf[0],respdial)) {
			if(debugn)
				fprintf(stderr,"gendial failed %s\n", &respbuf[0]);
			return(0);
		}
		if(debugn)
			fprintf(stderr,"gendial success: respbuf = %s\n", &respbuf[0]);
	}
	return (1);
}

online() {

	if (setjmp(timeoutbuf)) {
		if(debugn)
			fprintf(stderr,"online failed\n");
		return(0);
	}

	signal(SIGALRM, genALRM);
	ioctl(FDD, TIOCCAR);
	if (charup) {                   /* Conditionally wait for carrier */
		if(debugn)
			fprintf(stderr,"waiting for carrier\n");
		alarm(cdelay);
		ioctl(FDD, TIOCWONLINE); /* suspend, waiting for CD */
		alarm(0);
		if(debugn)
		fprintf(stderr,"carrier detected\n");
	}
	signal(SIGALRM, SIG_DFL);
	if(*onlstr) {
		char junk[GENBUF];
		if(!input(&junk[0], onlstr)) {
		  if(debugn)
			fprintf(stderr,"online failed\n");
		  return(0);
		}
	}
	if(debugn)
		fprintf(stderr,"online succeeded\n");
	return(1);
}

static int
gensync()
{
	char respbuf[GENBUF];

	if(debugn)
		fprintf(stderr,"gensync\n");
	if (dtr) {
	ioctl(FDD, TIOCCDTR, 0);
	sleep(2);
	ioctl(FDD, TIOCSDTR, 0);
	}
	if(*syncstr) {
		output(syncstr,syncdel);
	}
	if(*respsync) {
		if(!input(&respbuf[0], respsync))
			return(0);
	}
	return (1);
}

output(str, delay)
char *str;
int delay;
{
       char c;
       int ret;

	if(debugn)
		fprintf(stderr,"output: %s ", str);
	while (c = *str++) {
		/* a 'd' with the high bit set means sleep one sec (\d) */
		if ((c&0xff) == (('d'|0x80)&0xff)) { 
			if(debugn)
				fprintf(stderr," DELAY");
			sleep(1);
			continue;
		}
		c = (c & 0x7f);
		if(debugn)
			fprintf(stderr," %x", c);
		ret = write(FDD, &c, 1);
		if (ret != 1 && debugn) {
			fprintf(stderr,"write failed: %d errno: %d\n",ret, errno);
		}
		if(lsleep)
			usleep(0, delay);
		else
			sleep(delay);
	}
	if(debugn)
		fprintf(stderr,"\n");
}

/* Input eats things in typeahead upto & including the rspstr */
input(str, rspstr)
char *str, *rspstr;
{
	char c, *strb = str;
	int tp, k;
/* Calling an interface stupid brings us back in a hurry */
	if(stupidi)
		return(1);
	tp = typeahead((1<<FDD), 1, 0);
	while (tp) {          /* Eats everything in typeahead */
		(void) read(FDD, &c, 1);
		*str++ = c&0177;
		*str = '\0';
		if(cindex(strb, rspstr) >= 0) {
			if(debugn)
				fprintf(stderr,"input: %s\n", strb);
			return(1);
		}
		tp = typeahead((1<<FDD), 1, 0);
	}
	if(debugn)
		fprintf(stderr,"input (failed): %s\n", strb);
	return(0);
}

cindex(s, t)
char *s, *t;
{
	int i, j, k;

	for (i=0; s[i] != '\0'; i++) {
		for (j=i, k=0; t[k] != '\0' && s[j] == t[k]; j++, k++)
			;
		if(t[k] == '\0')
			return(i);
	}
	return(-1);
}

static int
timerALRM()
{
	longjmp(alrmbuf, 1);
}

usleep(secdelay, usecdelay)
int secdelay, usecdelay;
{
	struct itimerval val, oval;

	if(setjmp(alrmbuf)) {
		signal(SIGALRM, SIG_DFL);
		return(1);
	}
	oval.it_interval.tv_sec = 0;
	oval.it_interval.tv_usec = 0;
	oval.it_value.tv_sec = 0;
	oval.it_value.tv_usec = 0;
	val.it_interval.tv_sec = 0;
	val.it_interval.tv_usec = 0;
	val.it_value.tv_sec = secdelay;
	val.it_value.tv_usec = usecdelay;
	signal(SIGALRM, timerALRM);
	setitimer(ITIMER_REAL, &val, &oval);
	pause();
	return(0);
}
