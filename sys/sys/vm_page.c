#ifndef lint
static	char	*sccsid = "@(#)vm_page.c	1.28	(ULTRIX)	3/3/87";
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
 *   Modification history:
 *
 * 20 Feb 87 -- depp
 *	Added check for GTRC flag in gnode.  If set, the pagein() routine
 * 	will not hash the page or look for the page in the hash lists.
 *
 * 21 Jan 87 -- jaw
 *	performance fixes to syscall.
 *
 * 15 Jan 87 -- depp
 *	Fixed SM bug in pagein().
 *
 * 15 Dec 86 -- depp
 *	Fixed problem with PG_M not properly propagating to all attached
 *	text PTEs (pagein()).
 *
 * 09 Oct 86 -- depp
 *	Changed checkpage() to remove from the hash lists any pages that
 *	are from a remote file on pageout.  Also, fixed problem in shared
 *	memory - on pagein, if a SM page is intrans, it was sleeping on an
 *	address in the proc structure, rather than a global address.
 *
 * 11 Sep 86 -- koehler
 *	a few mount ops became macros, gnode name change
 *
 * 18 Jun 86 -- depp
 *      Added shared memory ZFOD support.
 *
 * 29 Apr 86 -- depp
 *	converted to lock macros from calls routines.
 *
 * 02-Apr-86 -- jrs
 *	Add set of runrun so that halt of slaves will really take
 *	effect when we want it to
 *
 * 02 Apr 86 -- depp
 *	Added in performance enhancements from 4.3UCB.  The first is the
 *	2 hand clock algorithm for large memory configurations.  The second
 *	is klustering of reads from a gnode.
 *
 * 18-Mar-86 -- jrs
 *	Clean up cpu premption to use new intrcpu instead of intrslave
 *
 * 11 Mar 86 -- depp
 *	Added conditional call to "vcleanu" (vm_mem.c) to "pagein" routine
 *	to remove any "u" areas found on the "u" list to the freelist.
 *
 * 24 Feb 86 -- depp
 *	Moved the setting of the PG_M bit in the routine "pagein" until
 *	just after the page has be read in.  This move was necessary because
 *	the SRM considers the PG_M bit set and the PG_V reset as an invalid
 *	combination.
 *
 * 13 Nov 85 -- depp
 *	Added "cm" parameter to distsmpte call.  This parameter indicates that
 *	the "pg_m" bit is to be cleared in the processes PTEs that are sharing
 *	a data segment.  This replaces the "pg_cm" definition of "pg_alloc"
 *	which could cause a conflict.
 *
 * 11 Nov 85 -- depp
 *	Removed all conditional compiles for System V IPC.
 *
 * 30 Sep 85 -- depp
 *	Added checks for page locking into "pageout"
 *
 * 19 Jul 85 -- depp
 *	Added the setting of pg_cm (for shared memory only) if the 
 *	page is to be pushed, so that in distsmpte, the attached process
 *	pte's will have their pg_m field properly cleared.
 *
 * 001 - March 11 1985 - Larry Cohen
 *     disable mapped in files so NOFILE can be larger than 32
 *
 *
 * 11 Mar 85 -- depp
 *	Added in System V shared memory.
 *
 */

#include "../machine/reg.h"
#include "../machine/pte.h"

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/mount.h"
#include "../h/gnode.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/buf.h"
#include "../h/text.h"
#include "../h/cmap.h"
#include "../h/vm.h"
#include "../h/file.h"
#include "../h/trace.h"
#include "../h/ipc.h"
#include "../h/shm.h"
#include "../h/cpudata.h"
extern struct smem smem[];
extern struct sminfo sminfo;
extern int extracpu;

#ifdef GFSDEBUG
extern short GFS[];
#endif

int	nohash = 0;
/*
 * Handle a page fault.
 *
 * Basic outline
 *	If page is allocated, but just not valid:
 *		Wait if intransit, else just revalidate
 *		Done
 *	Compute <dev,bn> from which page operation would take place
 *	If page is text page, and filling from file system or swap space:
 *		If in free list cache, reattach it and then done
 *	Allocate memory for page in
 *		If block here, restart because we could have swapped, etc.
 *	Lock process from swapping for duration
 *	Update pte's to reflect that page is intransit.
 *	If page is zero fill on demand:
 *		Clear pages and flush free list cache of stale cacheing
 *		for this swap page (e.g. before initializing again due
 *		to 407/410 exec).
 *	If page is fill from file and in buffer cache:
 *		Copy the page from the buffer cache.
 *	If not a fill on demand:
 *		Determine swap address and cluster to page in
 *	Do the swap to bring the page in
 *	Instrument the pagein
 *	After swap validate the required new page
 *	Leave prepaged pages reclaimable (not valid)
 *	Update shared copies of text page tables
 *	Complete bookkeeping on pages brought in:
 *		No longer intransit
 *		Hash text pages into core hash structure
 *		Unlock pages (modulo raw i/o requirements)
 *		Flush translation buffer
 *	Process pagein is done
 */
#ifdef TRACE
#define	pgtrace(e)	trace(e,v,u.u_procp->p_pid)
#else
#define	pgtrace(e)
#endif

int	preptofree = 1;		/* send pre-paged pages to free list */


pagein(virtaddr, dlyu)
	unsigned virtaddr;
	int dlyu;
{
	register struct proc *p;
	register struct pte *pte;
	register u_int v;
	register int i, j;
	register struct cmap *c;
	unsigned pf;
	int type, fileno;
	struct pte opte;
	dev_t dev;
	int klsize;
	unsigned vsave;
	int smindex;		/* SHMEM */
	struct smem *sp;	/* SHMEM */
	daddr_t bn, bncache, bnswap;
	int si, sk;
#ifdef PGINPROF
#include "../vax/mtpr.h"
	int otime, olbolt, oicr, a, s;

	s = spl6();
	otime = time, olbolt = lbolt, oicr = mfpr(ICR);
#endif
#ifdef GFSDEBUG
	if (GFS[18]) {
		cprintf("pagein: fault virtaddr 0x%x dlyu %d\n",virtaddr,dlyu);
	}
#endif GFSDEBUG
#ifdef GFSDEBUG
	if (GFS[18]) {
		static int once = 1;
		/* dump pag table of first remote exec */
		if (once && !(ISLOCAL(u.u_procp->p_textp->x_gptr->g_mp))) {
			struct pte *i;
			int j;
			once = 0;
			cprintf("pagein: pagetable p0br 0x%x p0lr %d\n",
				u.u_pcb.pcb_p0br,u.u_pcb.pcb_p0lr & ~AST_CLR);
			for(i=u.u_pcb.pcb_p0br,j=0;
					j < (u.u_pcb.pcb_p0lr & ~AST_CLR);
								i++,j++) {
				cprintf("pte 0x%x *pte 0x%x\n",i,*(int *)(i));
			}
			cprintf("\n");
		}
	}
#endif GFSDEBUG
	cnt.v_faults++;
	/*
	 * Classify faulted page into a segment and get a pte
	 * for the faulted page.
	 */
	vsave = v = clbase(btop(virtaddr));
	p = u.u_procp;
	if (isatsv(p, v)) {
		type = CTEXT;
		pte = tptopte(p, vtotp(p, v));
	} else if (isadsv(p, v)) {
		type = CDATA;
		pte = dptopte(p, vtodp(p, v));

		/* begin SHMEM */
		if(vtodp(p, v) >= p->p_dsize){
			register int xp;

			type = CSMEM;

			/* translate the process data-space PTE	*/
			/* to the non-swapped shared memory PTE	*/

			xp = vtotp(p, v);
			for(i=0; i < sminfo.smseg; i++){
				if(p->p_sm[i].sm_p == NULL)
					continue;
				if(xp >= p->p_sm[i].sm_spte  &&
					xp < p->p_sm[i].sm_spte +
					btoc(p->p_sm[i].sm_p->sm_size))

					break;
			}
			if(i >= sminfo.smseg)
				panic("pagein SMEM");
			sp = p->p_sm[i].sm_p;
			pte = sp->sm_ptaddr +
				(xp - p->p_sm[i].sm_spte);
			smindex = i;
		}
		/* end SHMEM */

	} else {
		type = CSTACK;
		pte = sptopte(p, vtosp(p, v));
	}
#ifdef GFSDEBUG
	if (GFS[18]) {
		if (p && p->p_textp && p->p_textp->x_gptr &&
		    !(ISLOCAL(p->p_textp->x_gptr->g_mp))) {
			if (pte->pg_fod == 0 && pte->pg_pfnum) {
				cprintf("pagein:pte 0x%x fod %d v %d\n",
				pte,pte->pg_fod,pte->pg_v);
			}
			else if (pte->pg_fod == 1) {
				struct fpte *fpte = (struct fpte *)pte;
				cprintf("pagein:fpte 0x%x blkno %d fileno %d fod %d prot %d v %d\n",
					fpte,fpte->pg_blkno,fpte->pg_fileno,fpte->pg_fod,fpte->pg_prot,fpte->pg_v);
			}
			else {
				cprintf("pagein: pte 0x%x\n",pte);
			}
		}
	}
#endif GFSDEBUG
	if (pte->pg_v)
		return;
#ifdef notdef
		panic("pagein");
#endif notdef

	/*
	 * If page is reclaimable, reclaim it.
	 * If page is text and intransit, sleep while it is intransit,
	 * If it is valid after the sleep, we are done.
	 * Otherwise we have to start checking again, since page could
	 * even be reclaimable now (we may have swapped for a long time).
	 */
restart:

	/* if any free "u" pages to be placed on free list, do it now */
	if (nucmap)
		vcleanu();

	if (pte->pg_fod == 0 && pte->pg_pfnum) {
		if (type == CTEXT && cmap[pgtocm(pte->pg_pfnum)].c_intrans) {
			pgtrace(TR_INTRANS);
			sleep((caddr_t)p->p_textp, PSWP+1);
			pgtrace(TR_EINTRANS);
			pte = vtopte(p, v);
			if (pte->pg_v) {
valid:
				if (dlyu) {
					c = &cmap[pgtocm(pte->pg_pfnum)];
					if (c->c_lock) {
						c->c_want = 1;
						sleep((caddr_t)c, PSWP+1);
						goto restart;
					}
					c->c_lock = 1;
				}
				newptes(pte, v, CLSIZE);
				cnt.v_intrans++;
				return;
			}
			goto restart;
		}

		/* begin SHMEM */
		if (type == CSMEM  &&
				cmap[pgtocm(pte->pg_pfnum)].c_intrans) {
			pgtrace(TR_INTRANS);
			sleep((caddr_t)&sp->sm_flag, PSWP+1);
			pgtrace(TR_EINTRANS);

			/* recalculating the PTE is currently	*/
			/* not necessary because the SMEM page	*/
			/* tables are "wired-down". When (if)	*/
			/* the SMEM is generalized to allow the	*/
			/* page table to be swapped then 	*/
			/* recalculation will be necessary.	*/

			if (pte->pg_v) {
				if (dlyu) {
					c= &cmap[pgtocm(pte->pg_pfnum)];
					if (c->c_lock) {
						c->c_want = 1;
						sleep((caddr_t)c,
								PSWP+1);
						goto restart;
					}
					c->c_lock = 1;
				}
				newptes(pte, v, CLSIZE);
				cnt.v_intrans++;
				return;
			}
			goto restart;
		}
		/* end SHMEM */

		/*
		 * If page is in the free list, then take
		 * it back into the resident set, updating
		 * the size recorded for the resident set.
		 */
		si = splimp();
		if (cmap[pgtocm(pte->pg_pfnum)].c_free) {
			pgtrace(TR_FRECLAIM);
			munlink(pte->pg_pfnum);
			cnt.v_pgfrec++;
			if (type == CTEXT) {
				p->p_textp->x_rssize += CLSIZE;
			/*  SHMEM */
			} else if (type == CSMEM)
				sp->sm_rssize
							+= CLSIZE;
			else
				p->p_rssize += CLSIZE;
		} else
			pgtrace(TR_RECLAIM);
		splx(si);
		pte->pg_v = 1;
		if (anycl(pte, pg_m))
			pte->pg_m = 1;
		distcl(pte);
		if (type == CTEXT)
			distpte(p->p_textp, vtotp(p, v), pte);
		else if (type == CSMEM)		/* SHMEM */
			distsmpte(sp,
					vtotp(p, v) -
					p->p_sm[smindex].sm_spte,
					pte, PG_NOCLRM);
		u.u_ru.ru_minflt++;
		cnt.v_pgrec++;
		if (dlyu) {
			c = &cmap[pgtocm(pte->pg_pfnum)];
			if (c->c_lock) {
				c->c_want = 1;
				sleep((caddr_t)c, PSWP+1);
				goto restart;
			}
			c->c_lock = 1;
		}
		newptes(pte, v, CLSIZE);
#ifdef PGINPROF
		a = vmtime(otime, olbolt, oicr);
		rectime += a;
		if (a >= 0)
			vmfltmon(rmon, a, rmonmin, rres, NRMON);
		splx(s);
#endif
		return;
	}
#ifdef PGINPROF
	splx(s);
#endif

	/*
	 * <dev,bn> is where data comes from/goes to.
	 * <dev,bncache> is where data is cached from/to.
	 * <swapdev,bnswap> is where data will eventually go.
	 */
	if (pte->pg_fod == 0) {
		fileno = -1;
		bnswap = bncache = bn = vtod(p, v, &u.u_dmap, &u.u_smap);
		dev = swapdev;
	} else {
		fileno = ((struct fpte *)pte)->pg_fileno;
		bn = ((struct fpte *)pte)->pg_blkno;
		bnswap = vtod(p, v, &u.u_dmap, &u.u_smap);
		if (fileno > PG_FMAX)
			panic("pagein pg_fileno");
		if (fileno == PG_FTEXT) {
			if (p->p_textp == 0)
				panic("pagein PG_FTEXT");
			dev = p->p_textp->x_gptr->g_dev;
			bncache = bn;
			
		} else if (fileno == PG_FZERO) {
			dev = swapdev;
			bncache = bnswap;
			
		}
#ifdef notdef /* 001 */
		else {
			register struct file *fp = u.u_ofile[fileno];

			if (fp == NULL || fp->f_type != DTYPE_INODE)
				panic("pagein u.u_ofile");
			gp = (struct gnode *)fp->f_data;
			dev = gp->g_dev;
		}
#endif
	}
	klsize = 1;
	opte = *pte;

	/*
	 * Check for text detached but in free list.
	 * This can happen only if the page is filling
	 * from a gnode or from the swap device, (e.g. not when reading
	 * in 407/410 execs to a zero fill page.)
	 */
	if (type == CTEXT && fileno != PG_FZERO && !nohash &&
				((p->p_textp->x_gptr->g_flag & GTRC) == 0)) {
		si = splimp();
 		while ((c = mfind(dev, bncache, p->p_textp->x_gptr)) != 0) {
 			if (c->c_lock == 0)
 				break;
			MWAIT(c);
 		}
		if (c) {
			if (c->c_type != CTEXT || c->c_gone == 0 ||
			    c->c_free == 0) 
				panic("pagein mfind");

			p->p_textp->x_rssize += CLSIZE;
			/*
			 * Following code mimics memall().
			 */
 			pf = cmtopg(c - cmap);	/* moved by rr from while loop*/
			munlink(pf);
			for (j = 0; j < CLSIZE; j++) {
				*(int *)pte = pf++;
				pte->pg_prot = opte.pg_prot;
				pte++;
			}
			pte -= CLSIZE;
			c->c_free = 0;
			c->c_gone = 0;
			if (c->c_intrans || c->c_want)
				panic("pagein intrans|want");
			c->c_lock = 1;
			if (c->c_page != vtotp(p, v))
				panic("pagein c_page chgd");
			c->c_ndx = p->p_textp - &text[0];
			if (dev == swapdev) {
				cnt.v_xsfrec++;
				pgtrace(TR_XSFREC);
			} else {
				cnt.v_xifrec++;
				pgtrace(TR_XIFREC);
			}
			cnt.v_pgrec++;
			u.u_ru.ru_minflt++;
			if (dev != swapdev) {
				c = mfind(swapdev, bnswap, p->p_textp->x_gptr);
				if(c)munhash(swapdev,bnswap,p->p_textp->x_gptr);
				pte->pg_m = 1;
			}
			splx(si);
			goto skipswap;
		}
		splx(si);
	}

	/*
	 * Wasn't reclaimable or reattachable.
	 * Have to prepare to bring the page in.
	 * We allocate the page before locking so we will
	 * be swappable if there is no free memory.
	 * If we block we have to start over, since anything
	 * could have happened.
	 */
	sk = splimp();			/* lock memalls until [fod]kluster */
	if (freemem < CLSIZE * KLMAX) {
		pgtrace(TR_WAITMEM);
		while (freemem < CLSIZE * KLMAX)
			sleep((caddr_t)&freemem, PSWP+2);
		pgtrace(TR_EWAITMEM);
		splx(sk);
		if (type != CSMEM)	/* SHMEM */
			pte = vtopte(p, v);
		if (pte->pg_v)
			goto valid;
		goto restart;
	}

	/*
	 * Now can get memory and committed to bringing in the page.
	 * Lock this process, get a page,
	 * construct the new pte, and increment
	 * the (process or text) resident set size.
	 */
	p->p_flag |= SPAGE;
	if(type == CSMEM) {	/* SHMEM */
		i = memall(pte, CLSIZE, sp, type);
		pte->pg_alloc = 1;
	}
	else
		i = memall(pte, CLSIZE, p, type);
	if (i == 0)
		panic("pagein: memall");
	pte->pg_prot = opte.pg_prot;
	pf = pte->pg_pfnum;
	cmap[pgtocm(pf)].c_intrans = 1;
	distcl(pte);
	if (type == CTEXT) {
		p->p_textp->x_rssize += CLSIZE;
		distpte(p->p_textp, vtotp(p, v), pte);
	}
	else if (type == CSMEM) {	/* SHMEM */
		sp->sm_rssize += CLSIZE;
		distsmpte(sp,
				vtotp(p, v) -
				p->p_sm[smindex].sm_spte, pte, PG_NOCLRM);
	} 
	else
		p->p_rssize += CLSIZE;

	/*
	 * Two cases: either fill on demand (zero, or from file or text)
	 * or from swap space.
	 */
	if (opte.pg_fod) {
		if (fileno == PG_FZERO || fileno == PG_FTEXT) {
			/*
			 * Flush any previous text page use of this
			 * swap device block.
			 */
			si = splimp();
			if (type == CTEXT) {
				c = mfind(swapdev, bnswap, p->p_textp->x_gptr);
				if(c)munhash(swapdev,bnswap,p->p_textp->x_gptr); 
			}
			splx(si);
			/*
			 * If zero fill, short-circuit hard work
			 * by just clearing pages.
			 */
			if (fileno == PG_FZERO) {
#ifdef GFSDEBUG
				if (GFS[18]) {
					cprintf("fodzero: pte 0x%x 0x%x\n",
							pte,*(int*)(pte));
				}
#endif GFSDEBUG
				pgtrace(TR_ZFOD);
				for (i = 0; i < CLSIZE; i++)
					clearseg(pf+i);
				if (type != CTEXT)
					cnt.v_zfod += CLSIZE;
				splx(sk);
				goto skipswap;
			}
			pgtrace(TR_EXFOD);
			cnt.v_exfod += CLSIZE;
		} else
			panic("pagein vread");

		/*
		 * Fill from gnode.  Try to find adjacent
		 * pages to bring in also.
		 */
		if (type == CSMEM)
			panic("pagein: SHMEM fodkluster");
		v = fodkluster(p, v, pte, &klsize, dev, &bn);
		bncache = bn;
		
		splx(sk);
		/*
		 * Blocks of an executable may still be in the buffer
		 * cache, so we explicitly flush them out to disk
		 * so that the proper data will be paged in.
		 */
#ifdef GFSDEBUG
		if (GFS[18]) {
			if (klsize > 1) {
				cprintf("pagein: blkflush klsize = %d\n",
					klsize);
			}
		}
#endif GFSDEBUG
		blkflush(dev, bn, (long)klsize*CLSIZE*NBPG, p->p_textp->x_gptr);
#ifdef TRACE
		if (type != CTEXT)
			trace(TR_XFODMISS, dev, bn);
#endif
	} else {
		if (opte.pg_pfnum)
			panic("pagein pfnum");
		pgtrace(TR_SWAPIN);
		/*
		 * Fill from swap area.  Try to find adjacent
		 * pages to bring in also.
		 */
		if(type != CSMEM)	/* SHMEM */
			v = kluster(p, v, pte, B_READ, &klsize,
		    		(type == CTEXT) ? kltxt :
		    		((p->p_flag & SSEQL) ? klseql : klin), bn);
		splx(sk);
		/* THIS COULD BE COMPUTED INCREMENTALLY... */
		bncache = bn = vtod(p, v, &u.u_dmap, &u.u_smap);
		
	}

	distcl(pte);

	if(type == CSMEM)	/* SHMEM */
		swap(sp, bn,
				ptob(vtotp(p, v) -
					p->p_sm[smindex].sm_spte),
				ctob(CLSIZE),
				B_READ, B_PGIN|B_SMEM, dev, 0); 
	else {
#ifdef GFSDEBUG
		if(GFS[18]) {
			char *name = "???";
			
			cprintf("pagein: starting swap on pid %d bn %d vaddr 0x%x\n",
			p->p_pid, bn, virtaddr);
			switch(type) {
				case CTEXT:
					name = "TEXT";
					break;
				case CDATA:
					name = "DATA";
					break;
				case CSTACK:
					name = "STACK";
					break;
				case CSMEM:
					name = "SHMEM";
					break;
				case CSYS:
					name = "SYS";
			}
			cprintf("pagein: pte 0x%x segment %s\n", pte, name);
		}
#endif
		swap(p, bn, ptob(v), klsize * ctob(CLSIZE),
	    		B_READ, B_PGIN, dev, 0); 
	}
#ifdef TRACE
	trace(TR_PGINDONE, vsave, u.u_procp->p_pid);
#endif
	/*
	 * Instrumentation.
	 */
	u.u_ru.ru_majflt++;
	cnt.v_pgin++;
	cnt.v_pgpgin += klsize * CLSIZE;
#ifdef PGINPROF
	a = vmtime(otime, olbolt, oicr) / 100;
	pgintime += a;
	if (a >= 0)
		vmfltmon(pmon, a, pmonmin, pres, NPMON);
#endif

skipswap:
	/*
	 * Fix page table entries.
	 *
	 * Only page requested in is validated, and rest of pages
	 * can be ``reclaimed''.  This allows system to reclaim prepaged pages
	 * quickly if they are not used and memory is tight.
	 */
	pte = vtopte(p, vsave);
	if (opte.pg_fod)
		pte->pg_m = 1;
	if (pte->pg_pfnum == 0)
		panic("pagein: pfnum = 0");
	pte->pg_v = 1;
	distcl(pte);
	if (type == CTEXT) {
		distpte(p->p_textp, vtotp(p, vsave), pte);
		if (opte.pg_fod)
			p->p_textp->x_flag |= XWRIT;
		wakeup((caddr_t)p->p_textp);
	}
	if (type == CSMEM) {	/* SHMEM */
		distsmpte(sp,
				vtotp(p, vsave) -
				p->p_sm[smindex].sm_spte, pte, PG_NOCLRM);
		wakeup((caddr_t)&sp->sm_flag);
	}

	/*
	 * Memall returned page(s) locked.  Unlock all
	 * pages in cluster.  If locking pages for raw i/o
	 * leave the page which was required to be paged in locked,
	 * but still unlock others.
	 * If text pages, hash into the cmap situation table.
	 */
	pte = vtopte(p, v);
	for (i = 0; i < klsize; i++) {
		c = &cmap[pgtocm(pte->pg_pfnum)];
		if (v != vsave && fileno == PG_FTEXT) {
			pte->pg_m = 1;
			distcl(pte);
			if (type == CTEXT)
				distpte(p->p_textp, vtotp(p, v), pte);
		}
		c->c_intrans = 0;
		if (type == CTEXT && c->c_blkno == 0 && bncache && !nohash &&
				((p->p_textp->x_gptr->g_flag & GTRC) == 0)) {
			mhash(c, dev, bncache);
			bncache += CLBYTES / DEV_BSIZE;
			
		}
		if (v != vsave || !dlyu)
			MUNLOCK(c);
		if (v != vsave && type != CTEXT && 
				type != CSMEM &&	/* SHMEM */
				preptofree &&
				opte.pg_fod == 0) {
			/*
			 * Throw pre-paged data/stack pages at the
			 * bottom of the free list.
			 */
			p->p_rssize -= CLSIZE;
			memfree(pte, CLSIZE, 0);
		}
		newptes(pte, v, CLSIZE);
		v += CLSIZE;
		pte += CLSIZE;
	}

	/*
	 * All done.
	 */
	p->p_flag &= ~SPAGE;

	/*
	 * If process is declared fifo, memory is tight,
	 * and this was a data page-in, free memory
	 * klsdist pagein clusters away from the current fault.
	 */
	if ((p->p_flag&SSEQL) && freemem < lotsfree && type == CDATA) {
		int k = (vtodp(p, vsave) / CLSIZE) / klseql;
#ifdef notdef
		if (vsave > u.u_vsave)
			k -= klsdist;
		else
			k += klsdist;
		dpageout(p, k * klseql * CLSIZE, klout*CLSIZE);
		u.u_vsave = vsave;
#else
		dpageout(p, (k - klsdist) * klseql * CLSIZE, klout*CLSIZE);
		dpageout(p, (k + klsdist) * klseql * CLSIZE, klout*CLSIZE);
#endif
	}
}

/*
 * Take away n pages of data space
 * starting at data page dp.
 * Used to take pages away from sequential processes.
 * Mimics pieces of code in pageout() below.
 */
dpageout(p, dp, n)
	struct proc *p;
	int dp, n;
{
	register struct cmap *c;
	int i, klsize;
	register struct pte *pte;
	unsigned v;
	daddr_t daddr;

	if (dp < 0) {
		n += dp;
		dp = 0;
	}
	if (dp + n > p->p_dsize)
		n = p->p_dsize - dp;
#if defined(BERT)
	if (++dcnt % dmod == 0)
		printf("dp %d, n %d\n", dp, n);
#endif
	for (i = 0; i < n; i += CLSIZE, dp += CLSIZE) {
		pte = dptopte(p, dp);
		if (pte->pg_fod || pte->pg_pfnum == 0)
			continue;
		c = &cmap[pgtocm(pte->pg_pfnum)];
		if (c->c_lock || c->c_free)
			continue;
		if (pte->pg_v) {
#ifdef GFSDEBUG
			if(GFS[18])
				cprintf("pagein: pte 0x%x marked INVALID\n", pte);
#endif
			pte->pg_v = 0;
			if (anycl(pte, pg_m))
				pte->pg_m = 1;
			distcl(pte);
		}
		if (dirtycl(pte)) {
			if (bswlist.av_forw == NULL)
				continue;
			MLOCK(c);
			pte->pg_m = 0;
			distcl(pte);
			p->p_poip++;
			v = kluster(p, dptov(p, dp), pte, B_WRITE,
				&klsize, klout, (daddr_t)0);
			/* THIS ASSUMES THAT p == u.u_procp */
			daddr = vtod(p, v, &u.u_dmap, &u.u_smap);
			swap(p, daddr, ptob(v), klsize * ctob(CLSIZE),
			    B_WRITE, B_DIRTY, swapdev, pte->pg_pfnum);
		} else {
			if (c->c_gone == 0)
				p->p_rssize -= CLSIZE;
			memfree(pte, CLSIZE, 0);
			cnt.v_seqfree += CLSIZE;
		}
	}
}
		    

int	pushes;

#define	FRONT	1
#define	BACK	2

/*
 * The page out daemon, which runs as process 2.
 *
 * As long as there are at least lotsfree pages,
 * this process is not run.  When the number of free
 * pages stays in the range desfree to lotsfree,
 * this daemon runs through the pages in the loop
 * at a rate determined in vmsched().  Pageout manages
 * two hands on the clock.  The front hand moves through
 * memory, clearing the valid bit (simulating a reference bit),
 * and stealing pages from procs that are over maxrss.
 * The back hand travels a distance behind the front hand,
 * freeing the pages that have not been referenced in the time
 * since the front hand passed.  If modified, they are pushed to
 * swap before being freed.
 */
pageout()
{
	register int count;
	register int maxhand = pgtocm(maxfree);
	register int fronthand, backhand;
	register int cpindex, cpident;

	/*
	 * Set the two clock hands to be separated by a reasonable amount,
	 * but no more than 360 degrees apart.
	 */
	backhand = 0 / CLBYTES;
	fronthand = HANDSPREAD / CLBYTES;
	if (fronthand >= maxhand)
		fronthand = maxhand - 1;

loop:
	/*
	 * Before sleeping, look to see if there are any swap I/O headers
	 * in the ``cleaned'' list that correspond to dirty
	 * pages that have been pushed asynchronously. If so,
	 * empty the list by calling cleanup().
	 *
	 * N.B.: We guarantee never to block while the cleaned list is nonempty.
	 */
	(void) splhigh();
  	if (bclnlist != NULL) {
 		(void) spl0();
  		cleanup();
 		goto loop;
  	}
	slavehold = 0;
  	sleep((caddr_t)&proc[2], PSWP+1);
	if (extracpu) {
		slavehold = 1;
		cpident = cpuindex();
		for (cpindex = 0; cpindex < activecpu; cpindex++) {
			if (cpindex != cpident) {
				cpudata[cpindex].c_runrun++;
				intrcpu(cpindex);
			}
		}
	}
	(void) spl0();
	count = 0;
	pushes = 0;

	while (nscan < desscan && freemem < lotsfree) {
		/*
		 * If checkpage manages to add a page to the free list,
		 * we give ourselves another couple of trips around the loop.
		 */
		if (checkpage(fronthand, FRONT))
			count = 0;
		if (checkpage(backhand, BACK))
			count = 0;
		cnt.v_scan++;
		nscan++;
		if (++fronthand >= maxhand) {
			fronthand = 0;
			cnt.v_rev++;
			if (count > 2) {
				/*
				 * Extremely unlikely, but we went around
				 * the loop twice and didn't get anywhere.
				 * Don't cycle, stop till the next clock tick.
				 */
				goto loop;
			}
			count++;
		}
		if (++backhand >= maxhand)
			backhand = 0;
	}
	goto loop;
}

/*
 * An iteration of the clock pointer (hand) around the loop.
 * Look at the page at hand.  If it is a
 * locked (for physical i/o e.g.), system (u., page table)
 * or free, then leave it alone.
 * Otherwise, if we are running the front hand,
 * invalidate the page for simulation of the reference bit.
 * If the proc is over maxrss, we take it.
 * If running the back hand, check whether the page
 * has been reclaimed.  If not, free the page,
 * pushing it to disk first if necessary.
 */
checkpage(hand, whichhand)
	int hand, whichhand;
{
	register struct proc *rp;
	register struct cmap *c;
	register struct cmap *c1, *c2;
	register struct pte *pte;
	struct text *xp;
	struct smem *sp;		/* SHMEM */
	swblk_t daddr;
	unsigned v;
	int klsize;
	int lock;			/* Is the segment locked ? */
	int j;
	struct gnode *gp;
	int pagedirty = 0;

top:
	/*
	 * Find a process and text pointer for the
	 * page, and a virtual page number in either the
	 * process or the text image.
	 */
	c = &cmap[hand];
	if (c->c_lock || c->c_free)
		return (0);
	switch (c->c_type) {

	case CSYS:
		return (0);

	case CTEXT:
		xp = &text[c->c_ndx];
		rp = xp->x_caddr;
		gp = xp->x_gptr;
		v = tptov(rp, c->c_page);
		pte = tptopte(rp, c->c_page);
		lock = xp->x_flag & (XNOSW|XLOCK);
		break;

	case CDATA:
	case CSTACK:
		rp = &proc[c->c_ndx];
		while (rp->p_flag & SNOVM)
			rp = rp->p_xlink;
		xp = rp->p_textp;
		if (c->c_type == CDATA) {
			v = dptov(rp, c->c_page);
			pte = dptopte(rp, c->c_page);
		} else {
			v = sptov(rp, c->c_page);
			pte = sptopte(rp, c->c_page);
		}
		lock = rp->p_flag & SULOCK;
		break;

	case CSMEM:	/* SHMEM */
		sp = &smem[c->c_ndx];
		v = c->c_page;
		pte = sp->sm_ptaddr + v;
		lock = sp->sm_flag & SMNOSW;
		break;
	}

	/* if segment locked, then not eligible for paging */
	if (lock)
		return(0);

	if (pte->pg_pfnum != cmtopg(hand)) {
#ifdef GFSDEBUG
		cprintf("pagein: p 0x%x pte 0x%x *pte 0x%x hand 0x%x cmtopg 0x%x\nc:\t%x %x %x %x %x\n",rp, pte, *(int *)pte, hand, cmtopg(hand), *(int *)c,*(int *)(c+1),*(int *)(c+2),*(int *)(c+3),*(int *)(c+4));
#endif GFSDEBUG
		panic("bad c_page");
	}

	/*
	 * If page is valid; make invalid but reclaimable.
	 * If this pte is not valid, then it must be reclaimable
	 * and we can add it to the free list.
	 */
	if (pte->pg_v) {
		if (whichhand == BACK)
			return(0);
#ifdef GFSDEBUG
		if(GFS[18])
			cprintf("pagein: pte 0x%x marked INVALID\n", pte);
#endif
		pte->pg_v = 0;
		if (pte->pg_pfnum == 0)
			panic("pageout: checkpage");
		if (anycl(pte, pg_m))
			pte->pg_m = 1;
		distcl(pte);
		if (c->c_type == CTEXT)
			distpte(xp, vtotp(rp, v), pte);
		if (c->c_type == CSMEM) {	/* SHMEM */
			distsmpte(sp, v, pte, PG_NOCLRM);
			return(0);
		}
		if ((rp->p_flag & (SSEQL|SUANOM)) == 0 &&
		    rp->p_rssize <= rp->p_maxrss)
			return (0);
	}
	if (c->c_type != CTEXT
			&&  c->c_type != CSMEM) { /* SHMEM */
		/*
		 * Guarantee a minimal investment in data
		 * space for jobs in balance set.
		 */
		if (rp->p_rssize < saferss - rp->p_slptime)
			return (0);
	}

	/*
	 * If the page is currently dirty, we
	 * have to arrange to have it cleaned before it
	 * can be freed.  We mark it clean immediately.
	 * If it is reclaimed while being pushed, then modified
	 * again, we are assured of the correct order of 
	 * writes because we lock the page during the write.  
	 * This guarantees that a swap() of this process (and
	 * thus this page), initiated in parallel, will,
	 * in fact, push the page after us.
	 *
	 * The most general worst case here would be for
	 * a reclaim, a modify and a swapout to occur
	 * all before the single page transfer completes.
	 */
	if (dirtycl(pte)
		|| (c->c_type == CSMEM && dirtysm(sp,v))) { /* SHMEM */
		/*
		 * If the process is being swapped out
		 * or about to exit, do not bother with its
		 * dirty pages
		 */
		if (c->c_type != CSMEM &&	/* SHMEM */
				rp->p_flag & (SLOCK|SWEXIT))
			return (0);
		/*
		 * Limit pushes to avoid saturating
		 * pageout device.
		 */
		if (pushes > maxpgio / 4)
			return (0);
		pushes++;

		/*
		 * Now carefully make sure that there will
		 * be a header available for the push so that
		 * we will not block waiting for a header in
		 * swap().  The reason this is important is
		 * that we (proc[2]) are the one who cleans
		 * dirty swap headers and we could otherwise
		 * deadlock waiting for ourselves to clean
		 * swap headers.  The sleep here on &proc[2]
		 * is actually (effectively) a sleep on both
		 * ourselves and &bswlist, and this is known
		 * to swdone and swap in vm_swp.c.  That is,
		 * &proc[2] will be awakened both when dirty
		 * headers show up and also to get the pageout
		 * daemon moving.
		 */
loop2:
		(void) spl6();
		if (bclnlist != NULL) {
			(void) spl0();
			cleanup();
			goto loop2;
		}
		if (bswlist.av_forw == NULL) {
			bswlist.b_flags |= B_WANTED;
			sleep((caddr_t)&proc[2], PSWP+2);
			(void) spl0();
			/*
			 * Page disposition may have changed
			 * since process may have exec'ed,
			 * forked, exited or just about
			 * anything else... try this page
			 * frame again, from the top.
			 */
			goto top;
		}
		(void) spl0();

		MLOCK(c); 
		if (c->c_type != CSMEM)	/* SHMEM */
			uaccess(rp, Pushmap, &pushutl);
		/*
		 * Now committed to pushing the page...
		 */
		pte->pg_m = 0;
		distcl(pte);
		if (c->c_type == CTEXT)  {
			xp->x_poip++;
			distpte(xp, vtotp(rp, v), pte);
		} else if (c->c_type == CSMEM) { /* SHMEM */
			sp->sm_poip++;
			distsmpte(sp, v, pte, PG_CLEARM);
		} else
			rp->p_poip++;
		if(c->c_type == CSMEM){		/* SHMEM */
			daddr = sp->sm_daddr[v/dmtext] +
					v%dmtext;
			swap(sp, daddr, ptob(v),
				ctob(CLSIZE), B_WRITE,
				B_DIRTY|B_SMEM, swapdev,
				pte->pg_pfnum);
		} 
		else {
			v = kluster(rp, v, pte, B_WRITE, 
				&klsize, klout, (daddr_t)0);
			if (klsize == 0)
				panic("pageout klsize");
			daddr = vtod(rp, v, &pushutl.u_dmap, 
				&pushutl.u_smap);
			swap(rp, daddr, ptob(v), 
				klsize * ctob(CLSIZE),
				B_WRITE, B_DIRTY, swapdev,
				 pte->pg_pfnum);
		}
		pagedirty++;
	}

	/*
	 * if local execution of a remote file, and on hash lists, then 
	 * remove from the lists.  This fix is to permit
	 * xflush_free_text() (vm_text.c) to work as implemented, since 
	 * it depends on the contiguous deallocation of pages on exit or
	 * swapout.   This should be changed in the future ...
	 */
	 if (c->c_blkno && !ISLOCAL(gp->g_mp)) {
		if (c->c_type != CTEXT)
			panic("checkpage munhash not text");
		j = CMHASH(c->c_blkno);
		c1 = &cmap[cmhash[j]];
		if (c1 == c)
			cmhash[j] = c1->c_hlink;
		else {
			for (;;) {
				if (c1 == ecmap)
					panic("checkpage ecmap");
				c2 = c1;
				c1 = &cmap[c2->c_hlink];
				if (c1 == c)
					break;
			}
			c2->c_hlink = c1->c_hlink;
		}
		if (mfind(c->c_mdev==MSWAPX?swapdev:mount[c->c_mdev].m_dev,
		      (daddr_t)c->c_blkno, gp))
			panic("checkpage mfind");
		c1->c_mdev = (u_char) NODEV;
		c1->c_blkno = 0;
		c1->c_hlink = 0;
	 	
	 }
	/*
 	 * If the page was dirty then ...
 	 *
	 * The cleaning of this page will be
	 * completed later, in cleanup() called
	 * (synchronously) by us (proc[2]).  In
	 * the meantime, the page frame is locked
	 * so no havoc can result.
	 */
	 if (pagedirty)
		return (1);	/* well, it'll be free soon */
	/*
	 * Decrement the resident set size of the current
	 * text object/process, and put the page in the
	 * free list. Note that we don't give memfree the
	 * pte as its argument, since we don't want to destroy
	 * the pte.  If it hasn't already been discarded
	 * it may yet have a chance to be reclaimed from
	 * the free list.
	 */
	if (c->c_gone == 0) {
		if (c->c_type == CTEXT)
			xp->x_rssize -= CLSIZE;
		else if (c->c_type == CSMEM)	/* SHMEM */
			sp->sm_rssize -= CLSIZE;
		else
			rp->p_rssize -= CLSIZE;
	}
	memfree(pte, CLSIZE, 0);
	cnt.v_dfree += CLSIZE;
	return (1);		/* freed a page! */
}

/*
 * Process the ``cleaned'' list.
 *
 * Scan through the linked list of swap I/O headers
 * and free the corresponding pages that have been
 * cleaned by being written back to the paging area.
 * If the page has been reclaimed during this time,
 * we do not free the page.  As they are processed,
 * the swap I/O headers are removed from the cleaned
 * list and inserted into the free list.
 */
cleanup()
{
	register struct buf *bp;
	register struct proc *rp;
	register struct text *xp;
	register struct smem *sp;	/* SHMEM */
	register struct cmap *c;
	register struct pte *pte;
	struct pte *upte;
	unsigned pf;
	register int i;
	int s, center;

	for (;;) {
		s = spl6();
		if ((bp = bclnlist) == 0)
			break;
		bclnlist = bp->av_forw;
		splx(s);
		pte = vtopte(&proc[2], btop(bp->b_un.b_addr));
		center = 0;
		for (i = 0; i < bp->b_bcount; i += CLSIZE * NBPG) {
			pf = pte->pg_pfnum;
			c = &cmap[pgtocm(pf)];
			MUNLOCK(c);
			if (pf != bp->b_pfcent) {
				if (c->c_gone) {
					memfree(pte, CLSIZE, 0);
					cnt.v_dfree += CLSIZE;
				}
				goto skip;
			}
			center++;
			switch (c->c_type) {

			case CSYS:
				panic("cleanup CSYS");

			case CTEXT:
				xp = &text[c->c_ndx];
				xp->x_poip--;
				if (xp->x_poip == 0)
					wakeup((caddr_t)&xp->x_poip);
				break;

			case CDATA:
			case CSTACK:
				rp = &proc[c->c_ndx];
				while (rp->p_flag & SNOVM)
					rp = rp->p_xlink;
				rp->p_poip--;
				if (rp->p_poip == 0)
					wakeup((caddr_t)&rp->p_poip);
				break;

			case CSMEM:	/* SHMEM */
				sp = &smem[c->c_ndx];
				if(--(sp->sm_poip) == 0)
					wakeup((caddr_t)&sp->sm_poip);
				break;
			}
			if (c->c_gone == 0) {
				switch (c->c_type) {

				case CTEXT:
					upte = tptopte(xp->x_caddr, c->c_page);
					break;

				case CDATA:
					upte = dptopte(rp, c->c_page);
					break;

				case CSTACK:
					upte = sptopte(rp, c->c_page);
					break;

				case CSMEM:	/* SHMEM */
					upte = sp->sm_ptaddr +
							c->c_page;
					break;
				}
				if (upte->pg_v) 
					goto skip;
				if (c->c_type == CTEXT)
					xp->x_rssize -= CLSIZE;
				else if (c->c_type == CSMEM)	/* SHMEM */
					sp->sm_rssize -= CLSIZE;
				else
					rp->p_rssize -= CLSIZE;
			}
			memfree(pte, CLSIZE, 0);
			cnt.v_dfree += CLSIZE;
skip:
			pte += CLSIZE;
		}
		if (center != 1)
			panic("cleanup center");
		bp->b_flags = 0;
		bp->av_forw = bswlist.av_forw;
		bswlist.av_forw = bp;
		if (bswlist.b_flags & B_WANTED) {
			bswlist.b_flags &= ~B_WANTED;
			wakeup((caddr_t)&bswlist);
		}
	}
	splx(s);
}

/*
 * Kluster locates pages adjacent to the argument pages
 * that are immediately available to include in the pagein/pageout,
 * and given the availability of memory includes them.
 * It knows that the process image is contiguous in chunks;
 * an assumption here is that CLSIZE * KLMAX is a divisor of dmmin,
 * so that by looking at KLMAX chunks of pages, all such will
 * necessarily be mapped swap contiguous.
 */
int	noklust;
int	klicnt[KLMAX];
int	klocnt[KLMAX];

kluster(p, v, pte0, rw, pkl, klsize, bn0)
	register struct proc *p;
	unsigned v;
	struct pte *pte0;
	int rw, *pkl, klsize;
	daddr_t bn0;
{
	int type, cl, clmax;
	int kloff, k, klmax;
	register struct pte *pte;
	int klback, klforw;
	register int i;
	unsigned v0;
	daddr_t bn;
	register struct cmap *c;

	if (rw == B_READ)
		klicnt[0]++;
	else
		klocnt[0]++;
	*pkl = 1;
	if (noklust || klsize <= 1 || klsize > KLMAX || (klsize & (klsize - 1)))
		return (v);
	if (rw == B_READ && freemem < CLSIZE * KLMAX)
		return (v);
	if (isassv(p, v)) {
		type = CSTACK;
		cl = vtosp(p, v) / CLSIZE;
		clmax = p->p_ssize / CLSIZE;
	} else if (isadsv(p, v)) {
		type = CDATA;
		cl = vtodp(p, v) / CLSIZE;
		clmax = p->p_dsize / CLSIZE;
	} else {
		type = CTEXT;
		cl = vtotp(p, v) / CLSIZE;
		clmax = p->p_textp->x_size / CLSIZE;
	}
	kloff = cl & (klsize - 1);
	pte = pte0;
	bn = bn0;
	for (k = kloff; --k >= 0;) {
		if (type == CSTACK)
			pte += CLSIZE;
		else
			pte -= CLSIZE;
		if (type == CTEXT && rw == B_READ && bn) {
			bn -= CLBYTES / DEV_BSIZE;
			if (mfind(swapdev, bn, p->p_textp->x_gptr))
				break;
		}
		if (!klok(pte, rw))
			break;
	}
	klback = (kloff - k) - 1;
	pte = pte0;
	if ((cl - kloff) + klsize > clmax)
		klmax = clmax - (cl - kloff);
	else
		klmax = klsize;
	bn = bn0;
	for (k = kloff; ++k < klmax;) {
		if (type == CSTACK)
			pte -= CLSIZE;
		else
			pte += CLSIZE;
		if (type == CTEXT && rw == B_READ && bn) {
			bn += (CLBYTES / DEV_BSIZE);
			if (mfind(swapdev, bn, p->p_textp->x_gptr))
				break;
		}
		if (!klok(pte, rw))
			break;
	}
	klforw = (k - kloff) - 1;
	if (klforw + klback == 0)
		return (v);
	pte = pte0;
	if (type == CSTACK) {
		pte -= klforw * CLSIZE;
		v -= klforw * CLSIZE;
	} else {
		pte -= klback * CLSIZE;
		v -= klback * CLSIZE;
	}
	*pkl = klforw + klback + 1;
	if (rw == B_READ)
		klicnt[0]--, klicnt[*pkl - 1]++;
	else
		klocnt[0]--, klocnt[*pkl - 1]++;
	v0 = v;
	for (i = 0; i < *pkl; i++) {
		if (pte == pte0)
			goto cont;
		if (rw == B_WRITE) {
			c = &cmap[pgtocm(pte->pg_pfnum)];
			MLOCK(c);
			pte->pg_m = 0;
			distcl(pte);
			if (type == CTEXT)
				distpte(p->p_textp, vtotp(p, v), pte);
		} else {
			struct pte opte;
			int pf;

			opte = *pte;
			if (memall(pte, CLSIZE, p, type) == 0)
				panic("kluster");
			pte->pg_prot = opte.pg_prot;
			pf = pte->pg_pfnum;
			cmap[pgtocm(pf)].c_intrans = 1;
			distcl(pte);
			if (type == CTEXT) {
				p->p_textp->x_rssize += CLSIZE;
				distpte(p->p_textp, vtotp(p, v), pte);
			} else
				p->p_rssize += CLSIZE;
			distcl(pte);
		}
cont:
		pte += CLSIZE;
		v += CLSIZE;
	}
	return (v0);
}

klok(pte, rw)
	register struct pte *pte;
	int rw;
{
	register struct cmap *c;

	if (rw == B_WRITE) {
		if (pte->pg_fod)
			return (0);
		if (pte->pg_pfnum == 0)
			return (0);
		c = &cmap[pgtocm(pte->pg_pfnum)];
		if (c->c_lock || c->c_intrans)
			return (0);
		if (!dirtycl(pte))
			return (0);
		return (1);
	} else {
		if (pte->pg_fod)
			return (0);
		if (pte->pg_pfnum)
			return (0);
		return (1);
	}
}

/*
 * Fodkluster locates pages adjacent to the argument pages
 * that are immediately available to include in the pagein,
 * and given the availability of memory includes them.
 * It wants to page in a file system block if it can.
 */
int nofodklust = 0;
int fodklcnt[KLMAX];

fodkluster(p, v0, pte0, pkl, dev, pbn)
	register struct proc *p;
	unsigned v0;
	struct pte *pte0;
	int *pkl;
	dev_t dev;
	daddr_t *pbn;
{
	register struct pte *pte;
	register struct fpte *fpte;
	struct cmap *c;
	register daddr_t bn;
	daddr_t bnswap, v;
	register int klsize;
	int klback, type, i;
	long vmin, vmax;

	if (nofodklust)
		return (v0);
	fodklcnt[0]++;
	*pkl = 1;
	if (freemem < KLMAX)
		return (v0);
	if (isatsv(p, v0)) {
		type = CTEXT;
		vmin = tptov(p, 0);
		vmax = tptov(p, clrnd(p->p_tsize) - CLSIZE);
	} else {
		type = CDATA;
		vmin = dptov(p, 0);
		vmax = dptov(p, clrnd(p->p_dsize) - CLSIZE);
	}
	fpte = (struct fpte *)pte0;
	bn = *pbn;
	v = v0;
	for (klsize = 1; klsize < KLMAX; klsize++) {
		v -= CLSIZE;
		if (v < vmin)
			break;
		fpte -= CLSIZE;
		if (fpte->pg_fod == 0)
			break;
		bn -= btodb(CLBYTES);
		if (fpte->pg_blkno != bn)
			break;
		if (type == CTEXT) {
			if (mfind(dev, bn, p->p_textp->x_gptr))
				break;
			/*
			 * Flush any previous text page use of this
			 * swap device block.
			 */
			bnswap = vtod(p, v, &u.u_dmap, &u.u_smap);
			c = mfind(swapdev, bnswap, p->p_textp->x_gptr);
			if (c) munhash(swapdev, bnswap, p->p_textp->x_gptr);
		}
	}
	klback = klsize - 1;
	fpte = (struct fpte *)pte0;
	bn = *pbn;
	v = v0;
	for (; klsize < KLMAX; klsize++) {
		v += CLSIZE;
		if (v > vmax)
			break;
		fpte += CLSIZE;
		if (fpte->pg_fod == 0)
			break;
		bn += btodb(CLBYTES);
		if (fpte->pg_blkno != bn)
			break;
		if (type == CTEXT) {
			if (mfind(dev, bn, p->p_textp->x_gptr))
				break;
			/*
			 * Flush any previous text page use of this
			 * swap device block.
			 */
			bnswap = vtod(p, v, &u.u_dmap, &u.u_smap);
			c = mfind(swapdev, bnswap, p->p_textp->x_gptr);
			if (c) munhash(swapdev, bnswap, p->p_textp->x_gptr);
		}
	}
	if (klsize == 1)
		return (v0);
	pte = pte0;
	pte -= klback * CLSIZE;
	v0 -= klback * CLSIZE;
	*pbn -= klback * btodb(CLBYTES);
	*pkl = klsize;
	fodklcnt[0]--; fodklcnt[klsize - 1]++;
	v = v0;
	for (i = 0; i < klsize; i++) {
		if (pte != pte0) {
			struct pte opte;
			int pf;

			opte = *pte;
			if (memall(pte, CLSIZE, p, type) == 0)
				panic("fodkluster");
			pte->pg_prot = opte.pg_prot;
			pf = pte->pg_pfnum;
			cmap[pgtocm(pf)].c_intrans = 1;
			distcl(pte);
			if (type == CTEXT) {
				p->p_textp->x_rssize += CLSIZE;
				distpte(p->p_textp, vtotp(p, v), pte);
			} else
				p->p_rssize += CLSIZE;
			distcl(pte);
		}
		pte += CLSIZE;
		v += CLSIZE;
	}
	return (v0);
}
