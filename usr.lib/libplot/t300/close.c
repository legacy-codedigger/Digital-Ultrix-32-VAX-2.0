#ifndef lint
static char sccsid[] = "@(#)close.c	4.1 (Berkeley) 6/27/83";
#endif

#include <stdio.h>
closevt(){
	closepl();
}
closepl(){
	fflush(stdout);
	reset();
}
