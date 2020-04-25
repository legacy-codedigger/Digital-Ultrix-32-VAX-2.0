#ifndef lint
static char *sccsid = "@(#)ka8800.c	1.23	ULTRIX	2/12/87";
#endif lint

/************************************************************************
 *									*
 *			Copyright (c) 1984,85,86 by			*
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
 *   The information in this software is subject to change  without	*
 *   notice  and should not be construed as a commitment by Digital	*
 *   Equipment Corporation.						*
 *									*
 *   Digital assumes no responsibility for the use  or  reliability	*
 *   of its software on equipment which is not supplied by Digital.	*
 *									*
 ************************************************************************/

/***********************************************************************
 *
 * Modification History:
 *
 * 06-Aug-86 -- jaw	fixed baddaddr to work on running system.
 *
 * 28-Jul-86  -- bjg	Set cpu_subtype to 8500, 8550, 8700, or 8800; 
 *			and log cpu_subtype with MEM errors 
 *
 * 11-Jun-86   -- jaw 	Machine check recovery code.
 *
 * 5-Jun-86   -- jaw 	changes to config.
 *
 * 14-May-86 -- pmk  Changed where nbianum gets logged, now in LSUBID
 *
 * 29-Apr-86 -- jaw add error logging for nmi faults.
 *
 * 18-Apr-86 -- jaw	hooks for nmi faults and fixes to bierrors.
 *
 * 14-Apr-86 -- jaw  get cpu message to print out correct type.
 *
 * 09-Apr-86 -- jaw  fix bierror for multiple bi's.
 *
 * 02-Apr-86 -- jaw  add support for nautilus console and memory adapter
 *
 * 18-Mar-86 -- jrs
 *	Changed to new console bit defns.  Also add error printf
 *	if configuration request fails.
 *
 * 13-Mar-86	Darrell Dunnuck
 *	Moved ka8800 specific part of configure() here into ka8800conf.
 *	Passing cpup into nbiinit -- for consistency sake.
 *
 * 05-Mar-86 -- jaw  VAXBI device and controller config code added.
 *		     todr code put in cpusw.
 *
 * 03-Mar-86 -- jrs
 *	Added code to automatically start up secondary processor if
 *	it exists.  This parallels the vms code so that we can share
 *	console command files.
 *
 * 18-Mar-86 -- jaw  add routines to cpu switch for nexus/unibus addreses
 *		     also got rid of some globals like nexnum.
 *		     ka8800 cleanup.
 *
 * 04-feb-86 -- jaw  get rid of biic.h.
 *
 * 12-Dec-85 	Darrell Dunnuck
 *	Created this file to as part of machdep restructuring.
 *
 **********************************************************************/

/* ------------------------------------------------------------------------
 * Modification History:
 *
 *	04-FEB-86  jaw -- complete rewrite...
 *
 *	03-FEB-86  jaw -- changes for SCB.
 *
 * ------------------------------------------------------------------------
 */

#include "../machine/pte.h"
#include "../h/param.h"
#include "../h/conf.h"
#include "../h/time.h"
#include "../h/errno.h"
#include "../h/systm.h"
#include "../h/types.h"
#include "../h/map.h"
#include "../h/buf.h"
#include "../h/errlog.h"
#include "../h/ioctl.h"
#include "../h/tty.h"
#include "../h/cpudata.h"

#include "../vax/cons.h"
#include "../vax/cons.h"
#include "../vax/cpu.h"
#include "../vax/clock.h"
#include "../vax/mtpr.h"
#include "../vax/mem.h"
#include "../vax/nexus.h"
#include "../vax/scb.h"
#include "../vax/ka8800.h"
#include "../vax/rx50.h"

#include "../vaxuba/ubareg.h"
#include "../vaxuba/ubavar.h"
#include "../vaxbi/buareg.h"
#include "../sas/vmb.h"

extern int (*vax8800bivec[])();
extern struct bidata bidata[];
extern int cache_state;
extern struct timeval time;
extern int nNVAXBI;

struct nbib_regs adpt_loopback[];	/* nbib's registers */
struct nbia_regs nbia_addr[];		/* nbia registers */
struct nmi_reg v8800mem;		/* memory csrs */

struct nbia_info {
	struct nbia_regs *nbia;
	int alive;
	int nbib_alive[2];
} nbia_info[2];


struct {
	struct mc8800frame last8800mc;
	struct timeval	mc8800time;
} ka8800mcinfo[2];


ka8800machcheck (cmcf)
caddr_t cmcf;
{
register int recover=1;
register struct mc8800frame *mcf = (struct mc8800frame	 *) cmcf;
register int cpunum,eboxerr,i;
register struct mc8800frame *lastmcf;

	cpunum = ((mfpr(SID) & 0x800000) >> 23);
	lastmcf = &ka8800mcinfo[cpunum].last8800mc;

	/* check the microcode ABORT bit.  This indicates whether
	   VAX state has been changed */
	if (mfpr(MCSTS) & MCSTS_ABORT) recover = 0;

	/* check for IBOX errors that cause use to abort */
	if ((mcf->mc8800_iber & IBOX_ABORT) != 0) recover = 0;

	/* check for CBOX errors that cause use to abort */
	if ((mcf->mc8800_cber & CBOX_ABORT) != 0) recover = 0;
	
	/* this loop checks each byte of ebox parity checking for
	   a parity error.  Abort occurs if the source to the A or
	   B data path side is from the FILE or if the B side is
	   from the Slow Date FILE and a parity error is signaled. */
	eboxerr = mcf->mc8800_eber;
	for (i=0 ; i<4 ; i++) {
		if (eboxerr & EBOXA_PE)
			if ((eboxerr & (EBOXA_FILE << (8*i))) == AFILE) 
				recover = 0;
		if (eboxerr & (EBOXB_PE<< (8 * i))) { 
			if ((eboxerr & (EBOXB_FILE << (8*i))) == BFILE) 
				recover = 0;
			if ((eboxerr & (EBOXB_FILE << (8*i))) == SDFILE)
				recover = 0;
		}
	}

	/* did we just get a machine check at the same address or PC.  If
	   so its time to give up!!!! */
	if (((time.tv_sec - ka8800mcinfo[cpunum].mc8800time.tv_sec) 
						< MC8800_THRESH) &&
	   ((mcf->mc8800_pc == lastmcf->mc8800_pc) ||
	   (mcf->mc8800_va_viba==lastmcf->mc8800_va_viba)))
		recover=0;
			

	logmck((int *)cmcf, cpunum, recover);
	if (recover == 0) {
	    cprintf("\tlength\t= %x\n", mcf->mc8800_bcnt);
	    cprintf("\tmcstat\t= %x\n", mcf->mc8800_mcstat);
	    cprintf("\tipc\t= %x\n", mcf->mc8800_ipc);
	    cprintf("\tva.viba\t= %x\n", mcf->mc8800_va_viba);
	    cprintf("\tiber\t= %x\n", mcf->mc8800_iber);
	    cprintf("\tcber\t= %x\n", mcf->mc8800_cber);
	    cprintf("\teber\t= %x\n", mcf->mc8800_eber);
	    cprintf("\tnmifsr\t= %x\n", mcf->mc8800_nmifsr);
	    cprintf("\tnmiear\t= %x\n", mcf->mc8800_nmiear);
	    cprintf("\tpc\t= %x\n", mcf->mc8800_pc);
	    cprintf("\tpsl\t= %x\n", mcf->mc8800_psl);
	}


	if (recover) {
		mtpr (MCESR,0);
	 	ka8800mcinfo[cpunum].mc8800time.tv_sec =time.tv_sec;
	 	ka8800mcinfo[cpunum].mc8800time.tv_usec =time.tv_usec;
	    	lastmcf->mc8800_bcnt=mcf->mc8800_bcnt;
	    	lastmcf->mc8800_mcstat=mcf->mc8800_mcstat;
	    	lastmcf->mc8800_ipc=mcf->mc8800_ipc;
	    	lastmcf->mc8800_va_viba=mcf->mc8800_va_viba;
	    	lastmcf->mc8800_iber=mcf->mc8800_iber;
	    	lastmcf->mc8800_cber=mcf->mc8800_cber;
	    	lastmcf->mc8800_eber=mcf->mc8800_eber;
	    	lastmcf->mc8800_nmifsr=mcf->mc8800_nmifsr;
	    	lastmcf->mc8800_nmiear=mcf->mc8800_nmiear;
	    	lastmcf->mc8800_pc=mcf->mc8800_pc;
	    	lastmcf->mc8800_psl=mcf->mc8800_psl;
		nmifaultclear(); 
		mtpr(TBIA,0);
		setcache(1);
	} else {
		memerr ();
		panic ("mchk");
		/* never return */
	}
	return(0);
}

ka8800conf(cpup)
register struct cpusw *cpup;
{
	union cpusid cpusid;
	register struct nbib_regs *nbib;
	register char *nxp;
	register struct nbia_regs *nbia;
	register int binumber, numnbia;
	register int bicpunode,vor;
	register info;
	int retry;
	char *cputype;

	cpusid.cpusid = mfpr(SID);

	/* get the configuration word from the PRO. It tells us
	   the CPU type and whether there is one or two cpus. */	
	for ( info = 0, retry = 0; retry < 3 && info == 0 ; retry++) {
		/* ask console what our configuration is */
		info = ka8800getconf();
	}
	if (info == 0) printf("no reponse to configuration request!\n");

	if (info & N_SINGLE_CPU) {
		if (info & N_CONF_BOUND) cputype = "85";
		else cputype = "87";
	} else
		cputype = "88";

	printf("VAX%s%s, serial no. %d, hardware level = %d, cpu %d\n",
		cputype, ((info & N_SLOW_CPU) ? "00" : "50"),
		cpusid.cpu8800.cp_sno, cpusid.cpu8800.cp_eco,
		cpusid.cpu8800.cp_lr);

	/* set cpu_subtype for error logger */
	switch (*(cputype+1)) {
		case '5': cpu_subtype = ((info &N_SLOW_CPU)?ST_8500:ST_8550);
			   break;
		case '7': cpu_subtype = ST_8700;
			   break;
		case '8': cpu_subtype = ST_8800;
			   break;
		default:   
			   break;
	}

	/* VAX8800 has only one MEMORY CSR.  Set it up */
	nxaccess((char *) 0x3e000000,V8800mem, 512);
	mcrdata[0].memtype = MEMTYPE_MS8800;
	mcrdata[0].mcraddr = (struct mcr *) &v8800mem;
	nmcr++;

	mtpr(NMION,0xe0);	/* device interrupts on */
	mtpr(CCR,1);  		/* cache on */
	bidata[0].bivec_page=vax8800bivec;

	/* bi interrupt vector pages must start on a 1k boundary */
	if (((SCB_BI_OFFSET(0)) & 0x200) != 0) {
	   	bidata[0].bivec_page += 128;
	}
	(void)spl0();
	for(binumber=0; binumber < 4; binumber++) {
	    numnbia=binumber>>1;

	    /* map the nbia into virtual memory */
	    nxp = (char *) VAX8800_ADPT_ADDR(numnbia);
	    nxaccess(nxp,Nbia[numnbia],NBPG);
	    nbia = (struct nbia_regs *) nbia_addr;
	    nbia += numnbia;

	    /* is nbia present ?? */
	    if (bbadaddr((caddr_t)(nbia),4)) continue;

	    /* save of info about nbia */
	    nbia_info[numnbia].alive = 1;
	    nbia_info[numnbia].nbia = nbia;


  	    vor = (SCB_BI_OFFSET(0)) + (numnbia * 0x400);
	    if ((binumber&1) == 0) {
		printf("nbia%x adapter at address %x\n",numnbia,nxp);
	    }

	    /* initialize info about the BI we are going to autoconfigure */
	    bidata[binumber].bivirt = ((struct bi_nodespace *)(nexus));
	    bidata[binumber].bivirt += (binumber*16);
	    bidata[binumber].biphys = (struct bi_nodespace *) (ka8800nexaddr(binumber,0));
	    bidata[binumber].bivec_page = bidata[0].bivec_page+(binumber*128);

	    /* turn on loopback so we can get nbib node number */
    	    nbia->nbi_csr1 = nbia->nbi_csr1;
    	    nbia->nbi_csr0 |= (vor|NBIC0_INTREN|NBIC0_LOOPBACK);

	    /* see if BI is present (is nbib present? )  */
   	    if ((nbia->nbi_csr1 & (NBIC1_BI0<<(binumber&1))) == 0) {
	     	 nbia->nbi_csr0 &= ~(NBIC0_LOOPBACK);
		 continue;
	    }

	    nbia_info[numnbia].nbib_alive[binumber&1] = 1;

	    /* map nbib loopback address into virtual memory */
	    nbib = (struct nbib_regs *) adpt_loopback;
	    nbib += binumber;
	    nxp = (char *) (ka8800nexaddr(binumber,0));
	    nxaccess(nxp,ADPT_loopback[binumber],NBPG);
	    printf("vaxbi%x at address %x\n",binumber,nxp);

	    /* initialize that nbib */
	    nbib->nbi_biic.biic_typ = BI_NBI;
	    nbib->nbi_biic.biic_bci_ctrl |= BCI_INTREN;
	    nbib->nbi_biic.biic_strt = 0;
	    nbib->nbi_biic.biic_end = vmb_info.memsiz;
	    nbib->nbi_biic.biic_err = nbib->nbi_biic.biic_err;
	    nbib->nbi_biic.biic_ctrl |= BICTRL_BROKE;

	    /* map nbib into virtual memory */
	    bicpunode = nbib->nbi_biic.biic_ctrl & BICTRL_ID;
	    bidata[binumber].cpu_biic_addr =  (struct bi_nodespace *) nexus;
	    bidata[binumber].cpu_biic_addr += ((binumber*16) +bicpunode);
	    nxp = (char *) (ka8800nexaddr(binumber,bicpunode));
	    nxaccess(nxp,Nexmap[((binumber*16)+bicpunode)],BINODE_SIZE);

	    /* turn off loopback so nbia works normally */
     	    nbia->nbi_csr0 &= ~(NBIC0_LOOPBACK);
	    bidata[binumber].biintr_dst = 1 << bicpunode;

	    /* go autoconfigure the BI */
	    probebi(cpup,binumber);
	}

	/* if a secondary cpu is ready to be started, all we have
	   to do is tell console to start up the secondary for us */
	if ((info & (N_SCND_ENABLE | N_SINGLE_CPU)) == N_SCND_ENABLE) {
		/* only start 2nd cpu if configured */
		if (activecpu < maxcpu) {
			/* give console the magic cookie to start secondary */
			tocons(N_COMM | N_BOOT_OTHER);
		} else {
			mprintf("WARNING -- 2nd CPU not configured \n");
		}
	}
	return(0);
}

/* this routine request status information form the PRO console 
   to determine what type of Nautilus cpu we are on */
ka8800getconf() {
	register int timeo,info,response;

	/* to see if slave exists, we must ask console for
	   configuration information */
	tocons(N_COMM | N_GET_CONF);
	/* now wait for reply */
	for (info = 0, timeo = 100000; timeo > 0 && info == 0; --timeo) {
		/* wait for console to have something to say */
		if (mfpr(RXCS) & RXCS_DONE) {
			timeo = 100000;
			response = mfpr(RXDB);
			if ((response & N_MASK_ID) == N_CONF_DATA) {
				/* the console replied, record what we got */
				info = response & N_MASK_DATA;
				return(info);
			}
		}
	}
	return(0);
}

int ka8800badaddr(addr,len)
caddr_t addr;
int len;
{
	register int foo,s,i;	
	register struct bi_nodespace *biptr;
	
#ifdef lint
	len=len;
#endif lint

	s=spl7();

	for (i=0; i < nNVAXBI ; i++) {
		if (biptr = bidata[i].cpu_biic_addr) {
			biptr->biic.biic_err = biptr->biic.biic_err;
			foo = biptr->biic.biic_gpr0;
		}
	}

	foo = *(short *)addr;
	foo = 0;

	for (i=0; i < nNVAXBI ; i++) {
		if (biptr = bidata[i].cpu_biic_addr) {
			if ((biptr->biic.biic_err 
				& ~BIERR_UPEN)!=0) foo=1;
			biptr->biic.biic_err = biptr->biic.biic_err;
		}
	}

	/* clear any nmi faults generated by the read. */
	nmifaultclear();

	splx(s);
	return(foo);
}


nmifaultclear() 
{
	register int junk;
	register struct	nmi_reg *mcr;
#ifdef lint
	junk=junk;
#endif lint		
	mcr = (struct nmi_reg *) mcrdata[0].mcraddr; 
	junk = mcr->memcsr5;
	junk = mcr->memcsr0;
	mcr->memcsr0 = 0x04000000;		
	mtpr(CLRTOSTS,1);
}

ka8800nmifault() {
	int donot_recover = 0;

	/* check and log any nbia/nbib adapter errors.  Routine
	   will return info on whether to atempt to recover */
	donot_recover |= nbia_log_err(0);
	donot_recover |= nbia_log_err(1);

	/* check for any nmi faults.  Rountine will return info on whether
	   to attempt to recover. */
	donot_recover |= nmifault_log();

	if (donot_recover) panic("nmi fault");
	
	nmifaultclear(); 
}

nbia_log_err(nbianum) 
	int nbianum;
{
	register struct el_rec *elrp;
	register struct el_nmiadp *nmiadp;
	register struct nbib_regs *nbib;
	register int binumber;

	/* check for an adapter error */
	if (nbia_info[nbianum].nbia->nbi_csr1 & NBIC1_ERR)
		/* no error */
		return(0);

	/* log the nbia err */
	elrp = ealloc(sizeof(struct el_nmiadp),EL_PRISEVERE);
	if (elrp != NULL) {
	    	LSUBID(elrp,ELCT_ADPTR,ELADP_NBI,EL_UNDEF,0,nbianum,EL_UNDEF);

	    	nmiadp = (struct el_nmiadp *) &elrp->el_body.elnmiadp;
		nmiadp->nmiadp_nbiacsr0 = nbia_info[nbianum].nbia->nbi_csr0;
		nmiadp->nmiadp_nbiacsr1 = nbia_info[nbianum].nbia->nbi_csr1;
		
		binumber = nbianum << 1;
		if (nbia_info[nbianum].nbib_alive[0]) {
			nbib = (struct nbib_regs *)bidata[binumber].cpu_biic_addr;
			nmiadp->nmiadp_nbib0err = nbib->nbi_biic.biic_err;
		}
		if (nbia_info[nbianum].nbib_alive[1]) {
			nbib = (struct nbib_regs *)bidata[binumber+1].cpu_biic_addr;
			nmiadp->nmiadp_nbib0err = nbib->nbi_biic.biic_err;
		}
		EVALID(elrp);
	}
	/* currently donot recover */
	return(1);
}

nmifault_log() {
	register struct	nmi_reg *mcr;
	register struct el_rec *elrp;
	register struct el_nmiflt *nmiflt;
	register int i;
	int 	nmifsr,memcsr0,nbia0csr0,nbia1csr0;
	
	nmifsr = mfpr(NMIFSR);
	mcr = (struct nmi_reg *) mcrdata[0].mcraddr;
	memcsr0 = mcr->memcsr0;
	if (nbia_info[0].alive) 
		nbia0csr0 = nbia_info[0].nbia->nbi_csr0;
	else nbia0csr0 = 0;
	if (nbia_info[1].alive) 
		nbia1csr0 = nbia_info[1].nbia->nbi_csr0;
	else nbia1csr0 = 0;

	if (!((nmifsr != 0) ||  ((memcsr0 & NMI_C0_ERR) != 0) || 
	  ((nbia1csr0 & NBIC0_ERR) != 0) || ((nbia0csr0 & NBIC0_ERR) != 0)))
		/* no nmifault */
		return(0);


	/* log nmi fault */
	elrp = ealloc(sizeof(struct el_nmiflt),EL_PRISEVERE);
	if (elrp != NULL) {
	    	LSUBID(elrp,ELCT_BUS,ELBUS_NMIFLT,EL_UNDEF,0,EL_UNDEF,EL_UNDEF);
	    	nmiflt = (struct el_nmiflt *) &elrp->el_body.elnmiflt;
		
		nmiflt->nmiflt_nmifsr = nmifsr;
		nmiflt->nmiflt_nmiear = mfpr(NMIEAR);
		nmiflt->nmiflt_nbia0 = nbia0csr0;
		nmiflt->nmiflt_nbia1 = nbia1csr0;
		
		nmiflt->nmiflt_memcsr0 = memcsr0;

		
		for (i=0 ; i < EL_SIZE256; i++) {
			nmiflt->nmiflt_nmisilo[i] = mfpr(NMISILO);
		}
		EVALID(elrp);

	}
	return(1);
}


nbiinit(nxv,nxp,cpup,binumber,binode)
char *nxv;
char *nxp;
struct cpusw *cpup;
int binumber,binode;
{
#ifdef lint
	nxv=nxv; nxp=nxp;
	cpup = cpup;
	binumber=binumber;
	binode = binode;
#endif lint

	/* nothing to do */

}

ka8800nexaddr(binumber,binode) 
 	int binode,binumber;
{

	return((int)NEX8800(binumber,binode));

}

u_short *ka8800umaddr(binumber,binode) 
 	int binumber,binode;
{

	return(UMEM8800(binumber,binode));

}

u_short *ka8800udevaddr(binumber,binode) 
 	int binumber,binode;
{

	return(UDEVADDR8800(binumber,binode));

}

/*
 * Memenable enables the memory controller corrected data reporting.
 * This runs at regular intervals, turning on the interrupt.
 * The interrupt is turned off, per memory controller, when error
 * reporting occurs.  Thus we report at most once per memintvl.
 */

ka8800memenable ()
{
	register struct	nmi_reg *mcr;

	mcr = (struct nmi_reg *) mcrdata[0].mcraddr;
	mcr->memcsr3 |= NMI_C3_ENB_INT;

	return(0);

}

/*
 *  Function:
 *	ka8800memerr()
 *
 *  Description:
 *	log memory errors in kernel buffer
 *
 *  Arguments:
 *	none
 *
 *  Return value:
 *	none
 *
 *  Side effects:
 *	none
 */

ka8800memerr()
{
	register struct	nmi_reg *mcr;
	register struct el_rec *elrp;
	register struct el_mem *mrp;
	register int junk, priority,type;
#ifdef lint
	junk = junk;
#endif lint

	cprintf(" VAX8800 memory error \n");

	mcr = (struct nmi_reg *) mcrdata[0].mcraddr;
	
	if ((mcr->memcsr2 & (NMI_C2_RDS|NMI_C2_BAD_DATA)) ||
	     (mcr->memcsr3 & NMI_C3_INTERNAL_ERR)) {
		priority = EL_PRISEVERE;
		type = 2;		

	} else if (mcr->memcsr2 & NMI_C2_CRD) {
		priority = EL_PRILOW;
		type = 1;
	} else {
		/* no memory errors --clear interrupt just in case */
		junk = mcr->memcsr4;
		return(0);
	}	
	elrp = ealloc(EL_MEMSIZE,priority);
	if (elrp != NULL) {
	    LSUBID(elrp,ELCT_MEM,cpu_subtype,ELMCNTR_NMI,EL_UNDEF,EL_UNDEF,EL_UNDEF);
	    mrp = &elrp->el_body.elmem;
	    mrp->elmem_cnt = 1;
	    mrp->elmemerr.cntl = 1;
	    mrp->elmemerr.type = type;
	    mrp->elmemerr.numerr = 1;
	    mrp->elmemerr.regs[0] = mcr->memcsr0;
	    mrp->elmemerr.regs[1] = mcr->memcsr1;
	    mrp->elmemerr.regs[2] = mcr->memcsr2;
	    mrp->elmemerr.regs[3] = mcr->memcsr3;
	    EVALID(elrp);
	}
	/* clear error bits */
	mcr->memcsr2 = (mcr->memcsr2 & NMI_C2_ERR_BITS);

	/* disable crd's */
	mcr->memcsr3=(mcr->memcsr3& ~(NMI_C3_ENB_CRD))|NMI_C3_ENB_WRT;

	/* clear the NMI interrupt */
	junk = mcr->memcsr4;
	
	/* crash burn and die if a non-recoverable error */
	if (priority == EL_PRISEVERE) panic("memerr");

	return(0);
}
/*
 * this routine sets the cache to the state passed.  enabled/disabled
 */

ka8800setcache(state)
int state;
{
	mtpr (CCR, state);
	return(0);
}

ka8800cachenbl()
{
	cache_state = 0x1;
	return(0);
}


ka8800tocons(c)
	register int c;
{
	register int timeo;

	timeo = 100000;
	while ((mfpr (TXCS) & TXCS_RDY) == 0) {
		if (timeo-- <= 0) {
			return(0);
		}
	}
	mtpr (TXDB, c);
	return(0);
}

ka8800readtodr() {
	register u_int todr,data;
	register int s,i,j;

	s = spl7();
	while ((mfpr(TXCS) & TXCS_RDY) == 0);
	mtpr(TXDB,(N_TOY_READ|N_COMM));	
	i=0;
 	todr=0;
	while(i<4){
		j=0;
		while ((mfpr(RXCS) & RXCS_DONE) == 0) {
			j++;
			if (j==1000000) {
				splx( s );
				return(0);
			}
		}
 		data = mfpr(RXDB);
		if ((data&RXDB_ID) == N_TOY_DATA) {
			todr |= (data&RXDB_DATA)<< (8*i);
			i++;
		}
	}	
	splx( s );
	return(todr);
}
ka8800writetodr(yrtime) 
register u_int yrtime;
{
	register int s,i,j,todr;

	todr = TODRZERO + (100 * yrtime);

	s = spl7();
	while ((mfpr(TXCS) & TXCS_RDY) == 0);
	mtpr(TXDB,(N_TOY_WRITE|N_COMM));	
	i=0;
	while(i<4){
		j=0;
		while ((mfpr(TXCS) & TXCS_RDY) == 0) {
			j++;
			if (j==1000000) {
				splx( s );
				return;
			}
		}
 		mtpr(TXDB,(N_TOY_DATA + (todr&0xff)));
		todr = todr >> 8;
		i++;
	}	
	splx( s );
}


extern int txcs8800ie;
extern int rx8800ie;
extern struct tty cons[];
extern int tty8800rec[];

ka8800requeue(c) 
register int c;
{
	register struct tty *tp;
	register int i;

	switch (c&RXDB_ID) {
		case N_CSA1:
		case N_CSA2:
		case N_CONS_CNT:
		case N_CONS_MSG: 	
			{
		
			int rx8800_recieve();
			chrqueue(rx8800_recieve, c, 0);
			return;
			}
		case N_LCL_CONS: 
			i=0;
			break;

		case N_LCL_NOLOG: 
			i=1;
 			break;

		case N_RMT_CONS: 
			i=2;
			break;

		default:
			return;

	}
	tp = &cons[i];
	if (tp->t_state&TS_ISOPEN)
		chrqueue(linesw[tp->t_line].l_rint, c&0x7f, tp);
	if ((c&0x7f) == CSTOP)	tty8800rec[i] = 1;
	if ((c&0x7f) == CSTART) {
		tty8800rec[i] = 0;
		if (txcs8800ie == 0) {
			mtpr(TXCS,TXCS_IE);
			txcs8800ie = 1;
		}
	}

}



int rx8800error = 0;
int rx8800low = 0;
int rx8800code = 0;
extern struct rx5tab rx5tab;

rx8800_recieve(c) 
	int c;
{
	int id;

	if ((rx5tab.rx5_state & RX5BUSY) == 0) return;

	id = c & RXDB_ID;
	c = c & (~RXDB_ID); 

	switch (id) {


	case N_CONS_CNT:
		if (rx8800low) {
			rx8800code=c;
			rx8800low=0;
		}
		else {
			rx8800code |= (c<<8);
			cprintf("QIO error  %x \n",rx8800code);
			rx8800code = 0;
			break;
		}

	case N_CONS_MSG:

		switch (c&N_TYP_MASK) {

			case N_CSA1_STAT:
			case N_CSA2_STAT:
				c = c & ~(N_TYP_MASK);
				/* floppy completed ok? */
				if (c == N_CS_OK) {
					if ((rx5tab.rx5_buf->b_flags & B_READ)==0) {
						/* write is done start next trans action */
						if (rx5tab.rx5resid > 512)
							rx5tab.rx5resid -= 512;
						else rx5tab.rx5resid = 0;
					
						rx5tab.rx5blk++;

						if (rx5tab.rx5resid > 0)
							cs8800_start();
						else {
							iodone(rx5tab.rx5_buf);
							rx5tab.rx5_state &= ~RX5BUSY;
							wakeup((caddr_t)&rx5tab);
						}
					}
				} else {
					rx8800ie=0;
					rx8800low=1;
					rx5tab.rx5_buf->b_error = EIO;
					rx5tab.rx5_buf->b_flags |= B_ERROR;
					rx5tab.rx5_state &= ~ RX5BUSY;
					iodone(rx5tab.rx5_buf);
					wakeup((caddr_t) &rx5tab);
				}
				break;	
			
			default:
				printf("non-floppy status %x \n",c);
				break;
		}
		break;
	case N_CSA1:
	case N_CSA2:
		if (rx5tab.rx5_buf->b_flags & B_READ) {
			*rx5tab.rx5addr = (0xff &c);
	 		rx5tab.rx5addr++;
			rx5tab.count++;		

			if(rx5tab.count>=512) {
				/* write is done start next trans action */
				if (rx5tab.rx5resid > 512)
					rx5tab.rx5resid -= 512;
				else rx5tab.rx5resid = 0;
						
				rx5tab.rx5blk++;
	
				if (rx5tab.rx5resid > 0)
					cs8800_start();
				else {
					iodone(rx5tab.rx5_buf);
					rx5tab.rx5_state &= ~RX5BUSY;
					wakeup((caddr_t)&rx5tab);
				}
			}
		}
		break;
	}

}

cs8800_start() {
	register int s;

	rx5tab.cmdcount = 3;
	rx5tab.count = 0;
	rx5tab.command[1] =  (rx5tab.command[1] & 0xff00) |
				(rx5tab.rx5blk & 0xff);
	rx5tab.command[0] =  (rx5tab.command[0] & 0xff00) |
				((rx5tab.rx5blk >> 8) & 0xff);
	s=spl5();
	rx8800ie=1;
	if (txcs8800ie == 0) {
		txcs8800ie=1;
		mtpr(TXCS,TXCS_IE);
	}
	splx(s);
}
rx8800_trans() 
{
	int s;
	s=spl5();

	if ((rx5tab.rx5_state & RX5BUSY) == 0) rx8800ie=0;
	else {

		if (rx5tab.cmdcount > 0) {
			while((mfpr(TXCS)&TXCS_RDY) == 0) ;
			rx5tab.cmdcount--;
			mtpr(TXDB,rx5tab.command[rx5tab.cmdcount]);
			rx8800ie=1;
		} else {
			if (rx5tab.rx5_buf->b_flags & B_READ) {
				/* command is transmited */
				rx8800ie=0;
				
			} else {

				mtpr(TXDB, ((*rx5tab.rx5addr & 0xff)|rx5tab.id));
				
 				rx5tab.rx5addr++;
				rx5tab.count++;		
				rx8800ie=1;
				/* done writing to buffer */
				if (rx5tab.count==512) {
					 rx8800ie=0;
				}
			}

		}
	}
	if (txcs8800ie == 0) {
		txcs8800ie=1;
		mtpr(TXCS,TXCS_IE);
	}
	splx(s);
}

ka8800startrx() {

register u_short dn;
register int s;

	rx5tab.cmdcount =3;
	rx5tab.count =0;
	dn = (minor(rx5tab.rx5_buf->b_dev)>>3) & 07;


	if (rx5tab.rx5_buf->b_flags & B_READ ) { 
		rx5tab.command[2] = N_CSA_CMD | ((dn-1) << 4) | N_CS_READ;
	}
	else {
		rx5tab.command[2] = N_CSA_CMD | ((dn-1) << 4) | N_CS_WRITE;
	}

	rx5tab.id = N_CSA1 << ((dn-1)*2);
	rx5tab.command[1] = N_CSA_CMD | (rx5tab.rx5blk & 0xff);
	rx5tab.command[0] =  N_CSA_CMD | ((rx5tab.rx5blk >> 8)&0xff);

	s=spl5();
	rx8800ie=1;

	if (txcs8800ie == 0) {
		mtpr(TXCS,TXCS_IE);
		txcs8800ie = 1;
	}

	splx(s);
}




