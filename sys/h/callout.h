/*	@(#)callout.h	1.3	Ultrix	6/11/85	(callout.h	 6.1	 83/07/29)	  */

/*
 * The callout structure is for
 * a routine arranging
 * to be called by the clock interrupt
 * (clock.c) with a specified argument,
 * in a specified amount of time.
 * Used, for example, to time tab
 * delays on typewriters.
 */

struct	callout {
	int	c_time; 	/* incremental time */
	caddr_t c_arg;		/* argument to routine */
	int	(*c_func)();	/* routine */
	struct	callout *c_next;
};
#ifdef KERNEL
struct	callout *callfree, *callout, calltodo;
int	ncallout;
#endif

struct chrout {
	int c_arg;
	int d_arg;
	int (*c_func)();
	struct chrout *c_next;
};
#ifdef KERNEL
struct chrout *chrfree, *chrlst, *chrcur, *chrout;
int nchrout;
#endif
