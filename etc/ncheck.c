
#ifndef lint
static	char	*sccsid = "@(#)ncheck.c	1.4	(ULTRIX)	1/15/87";
#endif lint

/************************************************************************
 *									*
 *			Copyright (c) 1986,87 by			*
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

/*
 * ncheck -- obtain file names from reading filesystem
 */

/*
 *		Modification History					*
 *									*
 * 3) - 15 Jan 87 -- prs						*
 *	Increased HSIZE and added code to default to all mounted	*
 *	ULTRIX file systems if none are passed.				*
 *									*
 * 2) - 16 Dec 86 -- prs						*
 *	Changed error message.						*
 *									*
 * 1) - 15 Mar 85 -- funding						*
 *	Added named pipe support (re. System V named pipes)		*
 */

#define	NB		500
#define	HSIZE		8017
#define	MAXNINDIR	(MAXBSIZE / sizeof (daddr_t))

#define NPIPES							/* 1 */

#include <sys/param.h>
#include <sys/inode.h>
#include <sys/fs.h>
#include <sys/dir.h>
#include <sys/mount.h>
#include <sys/fs_types.h>
#include <stdio.h>

struct	fs	sblock;
struct	dinode	itab[MAXIPG];
struct 	dinode	*gip;
struct ilist {
	ino_t	ino;
	u_short	mode;
	short	uid;
	short	gid;
} ilist[NB];
struct	htab
{
	ino_t	h_ino;
	ino_t	h_pino;
	char	*h_name;
} htab[HSIZE];
char strngtab[30 * HSIZE];
int strngloc;

struct dirstuff {
	int loc;
	struct dinode *ip;
	char dbuf[MAXBSIZE];
};

int	aflg;
int	sflg;
int	iflg; /* number of inodes being searched for */
int	mflg;
int	fi;
ino_t	ino;
int	nhent;
int	nxfile;

int	nerror;
daddr_t	bmap();
long	atol();
struct htab *lookup();

main(argc, argv)
	int argc;
	char *argv[];
{
	register i;
	long n;
	int loc, ret;
	struct fs_data *mountbuffer;
	struct fs_data *fd;
#define MSIZE (NMOUNT * sizeof(struct fs_data))

	while (--argc) {
		argv++;
		if (**argv=='-')
		switch ((*argv)[1]) {

		case 'a':
			aflg++;
			continue;

		case 'i':
			for(iflg=0; iflg<NB; iflg++) {
				n = atol(argv[1]);
				if(n == 0)
					break;
				ilist[iflg].ino = n;
				nxfile = iflg;
				argv++;
				argc--;
			}
			continue;

		case 'm':
			mflg++;
			continue;

		case 's':
			sflg++;
			continue;

		default:
			fprintf(stderr, "ncheck: bad flag %c\n", (*argv)[1]);
			nerror++;
		}
		else break;
	}
	if (argc) {		/* arg list has file names */
		while(argc-- > 0)
			check(*argv++);
	}
	else {		/* 3 - read in mounted file systems for default */
		/*
		 * 3 - malloc enough space for mountbuffer to hold all
		 * the fs_data structures for all mounted file
		 * systems.
		 */
		mountbuffer = (struct fs_data *) malloc(MSIZE);
		/*
		 * 3 - Get all mounted file systems
		 */
		ret = getmnt(&loc, mountbuffer, MSIZE);
		if (ret < 0) {
			fprintf(stderr, "ncheck: unable to read default file sytems\n");
			return(1);
		}
		/*
		 * 3 - For all the mounted file systems, call check only is
		 * it is a local file system
		 */
		for (fd = mountbuffer; fd < &mountbuffer[ret]; fd++)
			if (fd->fd_fstype == GT_ULTRIX)
				check((char *)fd->fd_devname);
	}
	return(nerror);
}

check(file)
	char *file;
{
	register int i, j, c;
	int nfiles;

	fi = open(file, 0);
	if(fi < 0) {
		fprintf(stderr, "ncheck: cannot open %s\n", file);
		nerror++;
		return;
	}
	nhent = 0;
	printf("%s:\n", file);
	sync();
	bread(SBLOCK, (char *)&sblock, SBSIZE);
	if (sblock.fs_magic != FS_MAGIC) {
		printf("%s: not a file system\n", file);
		nerror++;
		return;
	}
	ino = 0;
	for (c = 0; c < sblock.fs_ncg; c++) {
		bread(fsbtodb(&sblock, cgimin(&sblock, c)), (char *)itab,
		    sblock.fs_ipg * sizeof (struct dinode));
		for(j = 0; j < sblock.fs_ipg; j++) {
			if (itab[j].di_mode != 0)
				pass1(&itab[j]);
			ino++;
		}
	}
	ilist[nxfile+1].ino = 0;
	ino = 0;
	for (c = 0; c < sblock.fs_ncg; c++) {
		bread(fsbtodb(&sblock, cgimin(&sblock, c)), (char *)itab,
		    sblock.fs_ipg * sizeof (struct dinode));
		for(j = 0; j < sblock.fs_ipg; j++) {
			if (itab[j].di_mode != 0)
				pass2(&itab[j]);
			ino++;
		}
	}
	ino = 0;
	for (c = 0; c < sblock.fs_ncg; c++) {
		bread(fsbtodb(&sblock, cgimin(&sblock, c)), (char *)itab,
		    sblock.fs_ipg * sizeof (struct dinode));
		for(j = 0; j < sblock.fs_ipg; j++) {
			if (itab[j].di_mode != 0)
				pass3(&itab[j]);
			ino++;
		}
	}
	close(fi);
	for (i = 0; i < HSIZE; i++)
		htab[i].h_ino = 0;
	for (i = iflg; i < NB; i++)
		ilist[i].ino = 0;
	nxfile = iflg;
}

pass1(ip)
	register struct dinode *ip;
{
	int i;

	if (mflg)
		for (i = 0; i < iflg; i++)
			if (ino == ilist[i].ino) {
				ilist[i].mode = ip->di_mode;
				ilist[i].uid = ip->di_uid;
				ilist[i].gid = ip->di_gid;
			}
	if ((ip->di_mode & IFMT) != IFDIR) {
		if (sflg==0 || nxfile>=NB)
			return;
		if ((ip->di_mode&IFMT)==IFBLK || (ip->di_mode&IFMT)==IFCHR ||
								/* 1 */
		(ip->di_mode&IFMT)==IFPORT || ip->di_mode&(ISUID|ISGID)) {
			ilist[nxfile].ino = ino;
			ilist[nxfile].mode = ip->di_mode;
			ilist[nxfile].uid = ip->di_uid;
			ilist[nxfile++].gid = ip->di_gid;
			return;
		}
	}
	lookup(ino, 1);
}

pass2(ip)
	register struct dinode *ip;
{
	register struct direct *dp;
	struct dirstuff dirp;
	struct htab *hp;

	if((ip->di_mode&IFMT) != IFDIR)
		return;
	dirp.loc = 0;
	dirp.ip = ip;
	gip = ip;
	for (dp = readdir(&dirp); dp != NULL; dp = readdir(&dirp)) {
		if(dp->d_ino == 0)
			continue;
		hp = lookup(dp->d_ino, 0);
		if(hp == 0)
			continue;
		if(dotname(dp))
			continue;
		hp->h_pino = ino;
		hp->h_name = &strngtab[strngloc];
		strngloc += strlen(dp->d_name) + 1;
		strcpy(hp->h_name, dp->d_name);
	}
}

pass3(ip)
	register struct dinode *ip;
{
	register struct direct *dp;
	struct dirstuff dirp;
	int k;

	if((ip->di_mode&IFMT) != IFDIR)
		return;
	dirp.loc = 0;
	dirp.ip = ip;
	gip = ip;
	for(dp = readdir(&dirp); dp != NULL; dp = readdir(&dirp)) {
		if(aflg==0 && dotname(dp))
			continue;
		if(sflg == 0 && iflg == 0)
			goto pr;
		for(k = 0; ilist[k].ino != 0; k++)
			if(ilist[k].ino == dp->d_ino)
				break;
		if (ilist[k].ino == 0)
			continue;
		if (mflg)
			printf("mode %-6o uid %-5d gid %-5d ino ",
			    ilist[k].mode, ilist[k].uid, ilist[k].gid);
	pr:
		printf("%-5u\t", dp->d_ino);
		pname(ino, 0);
		printf("/%s", dp->d_name);
		if (lookup(dp->d_ino, 0))
			printf("/.");
		printf("\n");
	}
}

/*
 * get next entry in a directory.
 */
struct direct *
readdir(dirp)
	register struct dirstuff *dirp;
{
	register struct direct *dp;
	daddr_t lbn, d;

	for(;;) {
		if (dirp->loc >= dirp->ip->di_size)
			return NULL;
		if ((lbn = lblkno(&sblock, dirp->loc)) == 0) {
			d = bmap(lbn);
			if(d == 0)
				return NULL;
			bread(fsbtodb(&sblock, d), dirp->dbuf,
			    dblksize(&sblock, dirp->ip, lbn));
		}
		dp = (struct direct *)
		    (dirp->dbuf + blkoff(&sblock, dirp->loc));
		dirp->loc += dp->d_reclen;
		if (dp->d_ino == 0)
			continue;
		return (dp);
	}
}

dotname(dp)
	register struct direct *dp;
{

	if (dp->d_name[0]=='.')
		if (dp->d_name[1]==0 ||
		   (dp->d_name[1]=='.' && dp->d_name[2]==0))
			return(1);
	return(0);
}

pname(i, lev)
	ino_t i;
	int lev;
{
	register struct htab *hp;

	if (i==ROOTINO)
		return;
	if ((hp = lookup(i, 0)) == 0) {
		printf("???");
		return;
	}
	if (lev > 10) {
		printf("...");
		return;
	}
	pname(hp->h_pino, ++lev);
	printf("/%s", hp->h_name);
}

struct htab *
lookup(i, ef)
	ino_t i;
	int ef;
{
	register struct htab *hp;

	for (hp = &htab[i%HSIZE]; hp->h_ino;) {
		if (hp->h_ino==i)
			return(hp);
		if (++hp >= &htab[HSIZE])
			hp = htab;
	}
	if (ef==0)
		return(0);
	if (++nhent >= HSIZE) {
		fprintf(stderr, "ncheck: out of core\n"); /* 002 */
		exit(1);
	}
	hp->h_ino = i;
	return(hp);
}

bread(bno, buf, cnt)
	daddr_t bno;
	char *buf;
	int cnt;
{
	register i;

	lseek(fi, bno * DEV_BSIZE, 0);
	if (read(fi, buf, cnt) != cnt) {
		fprintf(stderr, "ncheck: read error %d\n", bno);
		for(i=0; i < cnt; i++)
			buf[i] = 0;
	}
}

daddr_t
bmap(i)
	int i;
{
	daddr_t ibuf[MAXNINDIR];

	if(i < NDADDR)
		return(gip->di_db[i]);
	i -= NDADDR;
	if(i > NINDIR(&sblock)) {
		fprintf(stderr, "ncheck: %u - huge directory\n", ino);
		return((daddr_t)0);
	}
	bread(fsbtodb(&sblock, gip->di_ib[i]), (char *)ibuf, sizeof(ibuf));
	return(ibuf[i]);
}
