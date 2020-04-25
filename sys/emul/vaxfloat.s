/*	@(#)vaxfloat.s	1.4		12/19/84		*/

# include "../emul/vaxemul.h"
# include "../machine/psl.h"
# include "../emul/vaxregdef.h"


/************************************************************************
 *									*
 *			Copyright (c) 1984 by				*
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

/************************************************************************
 *
 *			Modification History
 *
 *	Stephen Reilly, 05-Dec-84
 * 003- Fixed typo that made floating operations  work incorrectly.
 *
 *	Stephen Reilly, 28-Aug-84
 * 002- The polyf routine failed to clear r1.  I received this bug
 *	from Jeff Wiener on 21-Aug-1984.
 *
 *	Stephen Reilly, 28-Aug-84
 * 001- Corrected a BBS instruction in MULTIPLY__FFLOAT.  It has referred
 *	to FRACTION+8(FP).  It should have been FRACTION+12(FP). I 
 *	received this fix from Jeff Wiener.  The date he fixed it was
 *	10-Aug-1984.
 *
 *	Stephen Reilly, 20-Mar-84
 * 000- This code is the modification of the VMS emulation codethat 
 *	was written by Derek Zave.  It has been modified to run
 *	on Ultrix.
 *
 ***********************************************************************/

 #++
 # facility: vms executive floating point emulation
 #
 # abstract:
 #
 #	loadable code that emulates f, d, g and h floating instructions on
 #	any processor.  octaword integer emulation is included.
 #
 # environment: runs at any access mode, ast reentrant
 #
 # author: steven b. lionel, 22-march-1983
 #
 #	emulation code based on lib$emulate by derek zave.
 #
 # modified by:
 #
 #	LJK0025		Lawrence J. Kenah	8-Mar-1984
 #	Change PRVMOD field in PSL that is in effect while emulator is
 #	executing so that PROBEs work with correct access mode when the
 #	emulator is used in exec or supervisor mode. Fix incorrect
 #	register usage in READ_FAULT.
 #
 #	LJK0015		Lawrence J. Kenah	2-Feb-1984
 #	Fix error destinations for inaccessible instruction stream or 
 #	exception stack. Use G^ addressing for SYS.STB symbols.
 #
 #	JCW1005		Jeffrey C. Wiener	11-January-1984
 #	Corrected the discription of the algorithm used to divide unsigned
 #	multiple length integers. A fix was also added to the associated
 #	code to fix an outstanding DIVG/DIVH bug. The fix checks a "carry-
 #	over". If the "carry-over" is negative, then the "carry-over" is
 #	zeroed.
 #
 #	sbl1002		steven b. lionel	23-may-1983
 #	add check for no p1 region.
 #
 #	sbl1001		steven b. lionel	22-march-1983
 #	adapt lib$emulate for integration into the vms executive.
 #--

 #
 # macros:
 #
 
 #	macro for comparing condition codes
 # 	.macro	cmpcond	cond,loc
 #	cmpzv	#3,#26,loc,#cond@-3
 #	.endm
 
 #	macro for loading op_types with the types of the various operands,
 #	.macro	set_op_types	op1=f,op2=f,op3=f,op4=f,op5=f,op6=f
 #	.narg	n_args
 #	.if	eq n_args-6	# 6 arguments?
 #	movw	#<typ_'op5'+<typ_'op6'@8>>, op_types4(fp)
 #	.ndc
 #	.if	eq n_args-5	# 5 arguments?
 #	movb	#<typ_'op5'>, op_types4(fp)
 # 	.endc
 #	.if	gt n_args-2	# more than 2 arguments?
 #	movl	#<typ_'op1'+ -
 #		 <typ_'op2'@8>+ -
 #		 <typ_'op3'@16>+ -
 #		 <typ_'op4'@24>>, op_types(fp)
 #	.endc
 #	.if	eq n_args-2	# 2 arguments?
 #	movw	#<typ_'op1'+<typ_'op2'@8>>, op_types(fp)
 #	.endc
 #	.if	eq n_args-1	# 1 argument?
 #	movb	#typ_'op1', op_types(fp)
 #	.endc
 #	.endm
 
 #
 # equated symbols:
 #
 #	see body of routine

 #
 # own storage:
 #
 #	none
 #

 #	****************************************************************
 #	*							       *
 #	*							       *
 #	*			assorted definitions		       *
 #	*							       *
 #	*							       *
 #	****************************************************************
 #
 #
 #
 #	parameters
 #
# define  call_args 40
				# flexible stack space (longwords)
 #
 #	opcode range limits
 #
# define  lo_1byte 0x40
# define  hi_1byte 0x76
# define lo_2byte 0x32
# define hi_2byte 0xff
 #
 #	operand area layout
 #
# define zero 0
					# zero indicator (byte)
# define sign 1			
					# sign indicator (byte)
# define power 4				
					# exponent (longword)
# define fraction 8			
					# fraction area (octaword)
# define operand_size 24
					# operand area size (bytes)
 #
 #	bits in the processor status longword (psl)
 #
# define psl_c 0			
					# carry indicator
# define psl_v 1			
					# overflow indicator
# define psl_z 2			
					# zero indicator
# define psl_n 3	
					# negative indicator
# define psl_t 4			
					# trace enable indicator
# define psl_iv	5			
					# integer overflow trap enable
# define psl_fu	6
					# floating underflow fault enable
# define psl_cam 24
					# low bit of current access mode
# define psl_fpd 27			
					# instruction first part done
# define psl_tp	30
					# trace pending indicator
 #
 #	masks for the processor status longword
 #
# define pslm_c	1<<psl_c 		
					# carry indicator
# define pslm_v 1<<psl_v 		
					# overflow indicator
# define pslm_z 1<<psl_z 		
					# zero indicator
# define pslm_n	1<<psl_n 		
					# negative indicator
# define pslm_vc pslm_v + pslm_c
					# overflow and carry indicators
# define pslm_nzvc pslm_vc + pslm_n+pslm_z
					# condition code
# define pslm_nz pslm_n +  pslm_z
					# comparison codes
# define pslm_nzv pslm_nz + pslm_v
					# bits other than carry
# define pslm_lss  pslm_n
					# less than condition code
# define pslm_eql pslm_z
					# equals condition code
# define pslm_gtr 0
					# greater than condition code
 #
 #	call frame layout

 #
# define handler 0
					# condition handler location
# define save_psw 4
					# saved processor status word
# define save_mask 6
					# register save mask
# define mask_align 14
					# bit position of alignment bits
# define save_ap 8
					# user's argument pointer
# define save_fp 12
					# user's frame pointer
# define save_pc 16
					# return point
# define reg_r0	20
					# user's r0
# define reg_r1	24
					# user's r1
# define reg_r2	28
					# user's r2
# define reg_r3	32
					# user's r3
# define reg_r4	36
					# user's r4
# define reg_r5	40
					# user's r5
# define reg_r6	44
					# user's r6
# define reg_r7	48
					# user's r7
# define reg_r8	52
					# user's r8
# define reg_r9	56
					# user's r9
# define reg_r10 60
					# user's r10
# define reg_r11 64
					# user's r11
# define frame_end 68
					# end of call frame
 #
 #	call frame extension layout
 #
# define reg_ap	68
					# user's ap
# define reg_fp	72
					# user's fp
# define reg_sp	76
					# user's sp
# define reg_pc	80
					# user's pc
# define psl 84
					# user's psl
# define local_end 88
					# end of emulator local storage
# define temp 88
					# temporary area for arithmetic
 #
 #	local storage layout
 #
# define save_align -1
					# saved copy of alignment bits
# define save_parcnt -2
					# saved copy of parameter count
# define mode -3
					# access mode for probes
# define flags -4
					# indicator flag bits
# define short_local -5
					# start of short local storage
# define regmod_pc -6
					# changes to user's pc
# define regmod_sp -7
					# changes to user's sp
# define regmod_fp -8
					# changes to user's fp
# define regmod_ap -9
					# changes to user's ap
# define regmod_r11 -10
					# changes to user's r11
# define regmod_r10 -11
					# changes to user's r10
# define regmod_r9 -12
					# changes to user's r9
# define regmod_r8 -13
					# changes to user's r8
# define regmod_r7 -14
					# changes to user's r7
# define regmod_r6 -15
					# changes to user's r6
# define regmod_r5 -16
					# changes to user's r5
# define regmod_r4 -17
					# changes to user's r4
# define regmod_r3 -18
					# changes to user's r3
# define regmod_r2  -19
					# changes to user's r2
# define regmod_r1 -20
					# changes to user's r1
# define regmod_r0 -21
					# changes to user's r0
# define address1 -25
					# temporary address area #1
# define address2 -29
					# temporary address area #2

# define address3 -33
					# temporary address area #3
# define operand1 address3 - operand_size
					# temporary operand area #1
# define operand2 operand1 - operand_size
					# temporary operand area #2
# define operand3 operand2 - operand_size	
					# temporary operand area #3
# define op_types4 operand3 - 4
					# four bytes for operand type codes
# define op_types op_types4 - 4
					# four more bytes for operand type codes
# define op_index op_types - 4
					# pointer to current byte of op_types
# define local_start 0xffffff8b
			# op_index start of emulator local storage
 #
 #	indicator bit numbers
 #	
# define flag0	0
					# inhibit local store check
# define flag1	1
					# register mode operand
# define flag2	2
					# (not assigned)
# define flag3	3
					# (not assigned)
# define flag4  4
					# (not assigned)
# define flag5	5
					# (not assigned)
# define flag6	6
					# (not assigned)
# define flag7	7
					# temporary use
 #
 #	indicator bit masks
 #
# define flag0m	1<<0
					# inhibit local store check
# define flag1m	1<<1
					# register mode operand
# define flag2m 1<<2
					# (not assigned)
# define flag3m 1<<3
					# (not assigned)
# define flag4m	1<<4
					# (not assigned)
# define flag5m	1<<5
					# (not assigned)
# define flag6m	1<<6
					# (not assigned)
# define flag7m	1<<7
					# temporary use
 #
 #	fields in the operand areas
 #
# define zero1	operand1 + zero
					# zero flag of operand1
# define zero2	operand2 + zero
					# zero flag of operand2
# define zero3	operand3 + zero
					# zero flag of operand3
# define sign1	operand1 + sign
					# sign of operand1
# define sign2	operand2 + sign
					# sign of operand2
# define sign3	operand3 + sign
					# sign of operand3
# define power1	operand1 + power
					# exponent of operand1
# define power2	operand2 + power
					# exponent of operand2
# define power3	operand3 + power
					# exponent of operand3
# define fraction1 operand1 + fraction
					# fraction of operand1
# define fraction2 operand2 + fraction
					# fraction of operand2
# define fraction3 operand3 + fraction
					# fraction of operand3
 #
 #	access type code definitions
 #
# define type_read 1
					# read only access
# define type_write 2
					# write only access
# define type_modify 3
					# modify access
# define type_address 4
					# address access
 #
 #	data type code definitions
 #
# define typ_b	1
					# byte
# define typ_w	2
					# word

# define typ_l	3
					# longword
# define typ_q	4
					# quadword
# define typ_o	5
					# octaword
# define typ_f	6
					# f_floating
# define typ_d	7
					# d_floating
# define typ_g	8
					# g_floating
# define typ_h	9
					# h_floating
 
 #
 # instruction type definitions for optimization check
 #
# define it_d  1
# define it_f  2
# define it_g  4
# define it_h  8
# define it_x 0	
						# none

 #+
 # functional description:
 #
 #	this routine is entered in kernel mode through the scb vector for
 #	the opcdec exception. it determines if the instruction that caused
 #	the fault is one supported by this emulator. if so, the rest of the
 #	emulation is carried out by an instruction-specific routine. if not,
 #	control is transferred to the opcdec handler that is a part of the
 #	vms executive to allow normal exception dispatching to take place.
 #
 # input parameters:
 #
 #	0(sp) - pc of faulting instruction
 #	4(sp) - psl at the time of the fault
 #
 # output parameters:
 #
 #	the real output from this routine is the routine to which control
 #	is passed, namely the routine that handles each separate instruction.
 #-
	.text
  	.align	2
	.globl	vax$opcdec
 
 vax$opcdec:
 
 	movq	r0, -(sp)		# save r0 and r1
 
 # it is not clear whether the following prober is necessary. one approach is 
 # that an inaccessible opcode would cause an access violation rather than
 # a reserved instruction exception.
 
 	movl	8(sp), r0		# r0 contains the pc of the instruction
 # PUSHR; movl r0,-(sp); PRINTF(1, "pc that caused the exc %x\n"); POPR
	 prober	$0,$1,(r0)		# insure that opcode can be read
	 beql	6f
 	movzbl	(r0)+, r1		# get first opcode byte, increment "pc"
 # PUSHR; movl r1,-(sp); PRINTF(1, "the instruction to decoded %x\n"); POPR
 	bbc	r1, op_mask_1byte, 9f # test for opcode not emulated
 
 	cmpb	r1, $0xfd		# is it a two-byte opcode?
 	bneq	1f			# skip if not
 	 prober	$0,$1,(r0)		# can second byte be read?
	 beql	1f
	movzbl	(r0), r1		# fetch second byte
 	bbc	r1, op_mask_2byte, 9f	#  test for opcode not emulated
 
 
 #+
 # now the kernel stack looks as follows:
 #
 #	00(sp)	- saved r0
 #	04(sp)	- saved r1
 #	08(sp)	- pc of instruction
 #	12(sp)	- psl of instruction
 #
 #
 # switch stacks to that of the exception, push onto that stack the pc/psl.
 # push the psl with t, tp and fpd bits clear, the address of

 # emulate_fp, and then rei to emulate_fp.
 #-
 
1:
 #	 prober	$0,$4,*$ctl$al_stack		# is there a control region?
 #	 beql	9f				# (not swapper,nullproc)
 	extzv	$psl$v_curmod,$psl$s_curmod,12(sp),r1 # get previous mode
 
 	beql	2f			# br if kernel, no stack change needed
 # 	assume	psl$c_kernel eq 0
 #	assume	pr$_esp eq psl$c_exec
 #	assume	pr$_ssp eq psl$c_super
 #	assume	pr$_usp eq psl$c_user

 	mfpr	r1, r0			# get address of stack of excpt mode
 	probew $0,$8,-8(r0)		# br if cannot copy to excpt mode stk
 	beql	4f
 #	cmpl	r0,*$ctl$al_stack[r1]	# top address of stack in range?
 
 #	bgtru	4f			# if gtru no.
 	subl2	$8, r0			# get new low stack address
 	cmpl	$psl$c_user,r1		# previous mode user?
 	beql	3f			# if eql yes.
 #	cmpl	r0,*$ctl$al_stacklim[r1]# bottom address of stack in range?
 
 #	bgequ	3f			# if gequ yes.
3:
 	movq	8(sp), (r0)		# push pc/psl
 	mtpr	r0, r1			# set stack pointer to new value
 # 	bicl2	$psl$m_tp|psl$m_tbit|psl$m_fpd,12(sp) # clear bits in psl
 	 bicl2	$0x48000010,12(sp)
	insv	r1,$psl$v_prvmod,$psl$s_prvmod,12(sp) # set prvmod = curmod
 	movab	vax$$emulate_fp, 8(sp)# set entry address
 
 	movq	(sp)+, r0		# pop saved r0 and r1
	rei				# jump to emulate_fp
 	brb	2f			# join common code
 6:	brb	4f			# chain branch for accvio test
 
 #+
 # we come here if the previous mode is kernel, since we don't need to
 # switch modes.
 #-
 
 2:	movq	(sp)+, r0		# pop saved r0 and r1
 	jmp	vax$$emulate_fp		# emulate the instruction
 
 #+
 # if we don't handle the instruction, remove the things we pushed on the
 # stack and jump to the execption code that handles ss$_opcdec
 #-
 
 9:	movq	(sp)+, r0		# restore r0-r1
 	jmp	_Xprivinflt1		# reflect exception
 
 # if a probe of an outer access mode fails, then the exception is reported
 # as an access violation rather than as a reserved instruction. this allows
 # the stack expansion logic and other such things to be invoked without this
 # emulator worrying about such things.
 
 4:	movq	(sp), -(sp)		# move saved r0-r1
 	movl	r0,12(sp)		# store inaccessible stack address

 	movq	(sp)+,r0		# restore r0-r1
 	clrl	(sp)			# set mask to indicate a read
 	jmp	_Xprotflt		# pass control to vms handler
 

 #
 #	op_mask_1byte and op_mask_2byte are 256-bit bitmasks with
 #	bits set corresponding to opcodes of instructions that
 #	this emulator can handle.
 #
 
 op_mask_1byte:		# mask for 1-byte opcodes (including fd)
 #		  fedcba9876543210fedcba9876543210
 # 	.long	b`00000000000000000000000000000000	# 00-1f
.long	0x0
 # 	.long	b`00000000000000000000000000000000	# 20-3f
.long	0x0
 # 	.long	b`00000000011111111111111111111111	# 40-5f
.long	0x7fffff
 # 	.long	b`00000000011111111111111111111111	# 60-7f
.long	0x7fffff
 # 	.long	b`00000000000000000000000000000000	# 80-9f
.long	0x0
 # 	.long	b`00000000000000000000000000000000	# a0-bf
.long	0x0
 # 	.long	b`00000000000000000000000000000000	# c0-df
.long	0x0
 # 	.long	b`00100000000000000000000000000000	# e0-ff
.long	0x20000000 
 op_mask_2byte:		# mask for 2-byte opcodes (second byte index)
 #		  fedcba9876543210fedcba9876543210
 # 	.long	b`00000000000000000000000000000000	# 00-1f
.long	0x0
 # 	.long	b`00000000000011000000000000000000	# 20-3f
.long	0xc0000
 # 	.long	b`00000000011111111111111111111111	# 40-5f
.long	0x7fffff
 # 	.long	b`11110000011111111111111111111111	# 60-7f
.long	0xf07fffff
 # 	.long	b`00000011000000000000000000000000	# 80-9f
.long	0x3000000
 # 	.long	b`00000000000000000000000000000000	# a0-bf
.long	0x0
 # 	.long	b`00000000000000000000000000000000	# c0-df
.long	0x0
 # 	.long	b`00000000110000000000000000000000	# e0-ff
.long	0xc00000
 
 #
 #	vax$$emulate_fp - emulator entrance
 #
 #		entered by branching
 #
 #		parameters	0(sp)	instruction pc
 #				4(sp)	instruction psl
 #
 #	discussion
 #
 #	    this routine provides a simple method of activating the
 #	emulator. the pc and psl for the instruction being emulated
 #	are pushed onto the stack and the routine is entered. the 
 #	routine simply allocates the simulated user stack space for
 #	the emulator and calls the emulation procedure.
 #
 #	notes:	1. the fpd bit may be set in the pushed psl. this
 #		   bit will only be interpreted during the emulation
 #		   of the polyx instructions where it is
 #		   interpreted as described in the vax system 
 #		   reference manual.
 #
 #
 
	.globl	vax$$emulate_fp
 
 vax$$emulate_fp:
 	movab	-4*(call_args-2)(sp),sp # allocate the parameter block
 	calls	$call_args,emulator	# call the emulator
 	jmp	_Xprivinflt1		# shouldn't return here - 
 					# indicate opcdec as fallback
 #
	#
 #	emulator - start instruction emulation
 #
 #		parameters:	( described below )
 #
 #	discussion
 #
 #	    this routine initializes the emulator, processes the
 #	instruction code, and passes control to the appropriate 
 #	instruction emulation routine. the parameter list consists of
 #	call_args longwords of which only the last two have any 
 #	meaning. these parameters are the pc and psl for the emulation.
 #	the position following the parameter list is the
 #	user's stack pointer. the area covered by the parameter list
 #	is used to emulate the top of the user's stack.
 #
 #	    when the routine is entered the calls instruction saves
 #	the user's registers r0 to r11 in order and saves ap and fp
 #	elsewhere in the frame. the routine extends the saved
 #	registers by saving the user's ap, fp, sp, pc, and psl after
 #	the saved register area (the last two are taken from the
 #	parameter list).
 #
 #	    the local storage is allocated by extending the stack and
 #	the register modification bytes are cleared (these bytes
 #	record small changes to the register values). the cell mode
 #	is set equal to the current access mode for use in probing
 #	memory references. the alignment bits in the call frame and 
 #	the call parameter count are also saved so there is a safe
 #	copies to use when processing unwinds.
 #
 #	notes:	1. from the description of the way the simulated
 #		   register area is constructed, it is clear that
 #		   the length longword of the parameter list is
 #		   overwritten. all of the methods of leaving the
 #		   emulator put this longword back together. the
 #		   internal condition handler does this if it 
 #		   detects an unwind.
 #
 #		2. here are some more details on the register change
 #		   bytes: until the very end of instruction processing
 #		   when the results are output, all of the changes
 #		   which occur to the registers are caused by adding
 #		   or subtracting small values to or from a register.
 #		   these changes are also recorded in a corresponding 
 #		   register change byte so the register may be 
 #		   restored to its original value if a fault occurs.
 #		   those instructions that save results in the
 #		   registers in order to be interruptable, use the fpd
 #		   bit in the psl to indicate that this has been done
 #		   so different logic should be used for restarting
 #		   the instruction after a fault. in this case the 
 #		   change bytes should be cleared when fpd is set
 #		   except for the one for pc.
 #

 #		3. the location of the instruction being emulated is
 #		   stored in the return pc for the emulator's frame
 #		   so it may be easily located from the traceback
 #		   report if the emulator blows up.
 #
 emulator:				# entrance
	.word	0x0fff					# entry mask
 	movab	local_start(fp),sp	# allocate the local storage
 	extzv	$mask_align,$2,save_mask(fp),r0 # r0 = alignment bits
 
 	movb	r0,save_align(fp)	# save them
 	movb	$call_args,save_parcnt(fp) # save the parameter count
 	clrb	flags(fp)		# clear the flag bits
 	movab	cond_handler,handler(fp) # set up the condition handler
 	clrq	regmod_r0(fp)		# clear register modification bytes
 	clrq	regmod_r8(fp)		# clear register modification bytes
 	movq	save_ap(fp),reg_ap(fp)	# move user's ap and fp into place

  	movab	4*(call_args+1)(ap),reg_sp(fp) # move user's sp into place
 	movq	4*(call_args-1)(ap),reg_pc(fp) # move pc and psl into place
 
 	extzv	$psl_cam,$2,psl(fp),r0	# r0 = user's access mode
 
 	movb	r0,mode(fp)		# save it for probes
 	movl	reg_pc(fp),r11		# get instruction pc
 	movl	r11,save_pc(fp)		# save pc in the return pc
 	movab	op_types(fp), op_index(fp)# initialize ptr to operand type codes
 	movzbl	(r11)+,r0		# get first opcode byte
 	incl	reg_pc(fp)		# increment emulated pc
 	incl	regmod_pc(fp)		# remember the increment
 	bbc	$psl_t,psl(fp),1f	# check for t-bit
 	bbss	$psl_tp,psl(fp),1f	# set tp if t set
 1:	bicl2	$pslm_v,psl(fp)		# clear the v bit in the psl
 	cmpb	r0,$0xfd		# two-byte instruction?
 	bneq	dispatch_1byte		# skip if not
 	movzbl	(r11)+,r0		# get next opcode byte
 	incl	reg_pc(fp)		# increment emulated pc
 	incl	regmod_pc(fp)		# remember the increment
 	brw	dispatch_2byte		# execute 2-byte opcode

 
 #
 #	dispatch_1byte - branch to emulation routine for 1-byte opcode
 #
 #		entered by branching
 #
 #		r0 contains opcode
 #
 
 dispatch_1byte:
 	caseb	r0,$0x40,$(0x76-0x40)	# from addf2 through cvtdf
 
 1:
	.word	inst_addf2-1b		# 40	addf2
 	.word	inst_addf3-1b		# 41	addf3
 	.word	inst_subf2-1b		# 42	subf2
 	.word	inst_subf3-1b		# 43	subf3
 	.word	inst_mulf2-1b		# 44	mulf2
 	.word	inst_mulf3-1b		# 45	mulf3
 	.word	inst_divf2-1b		# 46	divf2
 	.word	inst_divf3-1b		# 47	divf3
 	.word	inst_cvtfb-1b		# 48	cvtfb
 	.word	inst_cvtfw-1b		# 49	cvtfw
 	.word	inst_cvtfl-1b		# 4a	cvtfl
 	.word	inst_cvtrfl-1b		# 4b	cvtrfl
 	.word	inst_cvtbf-1b		# 4c	cvtbf
 	.word	inst_cvtwf-1b		# 4d	cvtwf
 	.word	inst_cvtlf-1b		# 4e	cvtlf
 	.word	inst_acbf-1b		# 4f	acbf
 	.word	inst_movf-1b		# 50	movf
 	.word	inst_cmpf-1b		# 51	cmpf
 	.word	inst_mnegf-1b		# 52	mnegf
 	.word	inst_tstf-1b		# 53	tstf
 	.word	inst_emodf-1b		# 54	emodf
 	.word	inst_polyf-1b		# 55	polyf
 	.word	inst_cvtfd-1b		# 56	cvtfd
 	.word	0f - 1b			# 57
 	.word	0f - 1b			# 58	adawi
 	.word	0f - 1b			# 59
 	.word	0f - 1b			# 5a
 	.word	0f - 1b			# 5b
 	.word	0f - 1b			# 5c	insqhi
 	.word	0f - 1b			# 5d	insqti
 	.word	0f - 1b			# 5e	remqhi
 	.word	0f - 1b			# 5f	remqti
 	.word	inst_addd2-1b		# 60	addd2
 	.word	inst_addd3-1b		# 61	addd3
 	.word	inst_subd2-1b		# 62	subd2
 	.word	inst_subd3-1b		# 63	subd3
 	.word	inst_muld2-1b		# 64	muld2
 	.word	inst_muld3-1b		# 65	muld3
 	.word	inst_divd2-1b		# 66	divd2
 	.word	inst_divd3-1b		# 67	divd3
 	.word	inst_cvtdb-1b		# 68	cvtdb
 	.word	inst_cvtdw-1b		# 69	cvtdw
 	.word	inst_cvtdl-1b		# 6a	cvtdl
 	.word	inst_cvtrdl-1b		# 6b	cvtrdl

 	.word	inst_cvtbd-1b		# 6c	cvtbd
 	.word	inst_cvtwd-1b		# 6d	cvtwd
 	.word	inst_cvtld-1b		# 6e	cvtld
 	.word	inst_acbd-1b		# 6f	acbd
 	.word	inst_movd-1b		# 70	movd
 	.word	inst_cmpd-1b		# 71	cmpd
 	.word	inst_mnegd-1b		# 72	mnegd
 	.word	inst_tstd-1b		# 73	tstd
 	.word	inst_emodd-1b		# 74	emodd
 	.word	inst_polyd-1b		# 75	polyd
 	.word	inst_cvtdf-1b		# 76	cvtdf
 
 0:	brw	opcode_fault		# unrecognized opcode

 
 #
 #	dispatch_2byte - branch to emulation routine for 2-byte opcode
 #
 #		entered by branching
 #
 #		r0 contains second opcode byte
 #
 
 dispatch_2byte:
 	caseb	r0,$0x32,$(0x7f-0x32)	# covers cvtdh through pushao
 
 1:
	.word	inst_cvtdh-1b		# 32fd	cvtdh
 	.word	inst_cvtgf-1b		# 33fd	cvtgf
 	.word	0f - 1b			# 34fd
 	.word	0f - 1b			# 35fd
 	.word	0f - 1b			# 36fd
 	.word	0f - 1b			# 37fd
 	.word	0f - 1b			# 38fd
 	.word	0f - 1b			# 39fd
 	.word	0f - 1b			# 3afd
 	.word	0f - 1b			# 3bfd
 	.word	0f - 1b			# 3cfd
 	.word	0f - 1b			# 3dfd
 	.word	0f - 1b			# 3efd
 	.word	0f - 1b			# 3ffd
 	.word	inst_addg2-1b		# 40fd	addg2
 	.word	inst_addg3-1b		# 41fd	addg3
 	.word	inst_subg2-1b		# 42fd	subg2
 	.word	inst_subg3-1b		# 43fd	subg3
 	.word	inst_mulg2-1b		# 44fd	mulg2
 	.word	inst_mulg3-1b		# 45fd	mulg3
 	.word	inst_divg2-1b		# 46fd	divg2
 	.word	inst_divg3-1b		# 47fd	divg3
 	.word	inst_cvtgb-1b		# 48fd	cvtgb
 	.word	inst_cvtgw-1b		# 49fd	cvtgw
 	.word	inst_cvtgl-1b		# 4afd	cvtgl
 	.word	inst_cvtrgl-1b		# 4bfd	cvtrgl
 	.word	inst_cvtbg-1b		# 4cfd	cvtbg
 	.word	inst_cvtwg-1b		# 4dfd	cvtwg
 	.word	inst_cvtlg-1b		# 4efd	cvtlg
 	.word	inst_acbg-1b		# 4ffd	acbg
 	.word	inst_movg-1b		# 50fd	movg
 	.word	inst_cmpg-1b		# 51fd	cmpg
 	.word	inst_mnegg-1b		# 52fd	mnegg
 	.word	inst_tstg-1b		# 53fd	tstg
 	.word	inst_emodg-1b		# 54fd	emodg
 	.word	inst_polyg-1b		# 55fd	polyg
 	.word	inst_cvtgh-1b		# 56fd	cvtgh
 	.word	0f - 1b			# 57fd
 	.word	0f - 1b			# 58fd
 	.word	0f - 1b			# 59fd
 	.word	0f - 1b			# 5afd
 	.word	0f - 1b			# 5bfd
 	.word	0f - 1b			# 5cfd
 	.word	0f - 1b			# 5dfd

 	.word	0f - 1b			# 5efd
 	.word	0f - 1b			# 5ffd
 	.word	inst_addh2-1b		# 60fd	addh2
 	.word	inst_addh3-1b		# 61fd	addh3
 	.word	inst_subh2-1b		# 62fd	subh2
 	.word	inst_subh3-1b		# 63fd	subh3
 	.word	inst_mulh2-1b		# 64fd	mulh2
 	.word	inst_mulh3-1b		# 65fd	mulh3
 	.word	inst_divh2-1b		# 66fd	divh2
 	.word	inst_divh3-1b		# 67fd	divh3
 	.word	inst_cvthb-1b		# 68fd	cvthb
 	.word	inst_cvthw-1b		# 69fd	cvthw
 	.word	inst_cvthl-1b		# 6afd	cvthl
 	.word	inst_cvtrhl-1b		# 6bfd	cvtrhl
 	.word	inst_cvtbh-1b		# 6cfd	cvtbh
 	.word	inst_cvtwh-1b		# 6dfd	cvtwh
 	.word	inst_cvtlh-1b		# 6efd	cvtlh
 	.word	inst_acbh-1b		# 6ffd	acbh
 	.word	inst_movh-1b		# 70fd	movh
 	.word	inst_cmph-1b		# 71fd	cmph
 	.word	inst_mnegh-1b		# 72fd	mnegh
 	.word	inst_tsth-1b		# 73fd	tsth
 	.word	inst_emodh-1b		# 74fd	emodh
 	.word	inst_polyh-1b		# 75fd	polyh
 	.word	inst_cvthg-1b		# 76fd	cvthg
 	.word	0f - 1b			# 77fd
 	.word	0f - 1b			# 78fd
 	.word	0f - 1b			# 79fd
 	.word	0f - 1b			# 7afd
 	.word	0f - 1b			# 7bfd
 	.word	inst_clro-1b		# 7cfd	clro,clrh
 	.word	inst_movo-1b		# 7dfd	movo
 	.word	inst_movao-1b		# 7efd	movao,movah
 	.word	inst_pushao-1b		# 7ffd	pushao,pushah
 
 0:	cmpb	r0,$0x99		# cvtfg?
 	bgtru	3f			# skip if not
 	beql	5f			# skip if yes
 	cmpb	r0,$0x98		# cvtfh?
 	bneq	9f			# error if not
 	brw	inst_cvtfh		# execute cvtfh
 5:	brw	inst_cvtfg		# execute cvtfg
 3:	cmpb	r0,$0xf6		# cvthf?
 	bgtru	4f			# skip if not
 	bneq	9f			# error if lssu
 	brw	inst_cvthf		# execute cvthf
 4:	cmpb	r0,$0xf7		# cvthd?
 	bneq	9f			# error if not
 	brw	inst_cvthd		# execute cvthd
 
 9:	brw	opcode_fault		# shouldn't happen
 
 #
 #	normal_exit - normal end of instruction emulation
 #
 #		entered by branching
 #
 #		no parameters
 #
 #	discussion
 #
 #	    this routine restores control to the user program whenever
 #	the emulation ends without causing an exception. first the v
 #	and iv bits in the user's psl are checked. if they are both 
 #	set then an integer overflow trap is signaled. when the
 #	emulator returns, all of the registers, pc, and the psl are
 #	set to the emulated values.
 #
 #	    the method of leaving the emulator consists of pushing the
 #	user's pc and psl onto the user's stack putting the saved ap
 #	and fp back in their proper places in the frame and performing
 #	the indicated adjustment so that when a ret instruction is
 #	executed all of the registers up to fp will be restored and
 #	the stack pointer will be positioned to the pc, psl pair.
 #
 #	    at this point, a speed optimization is performed.  if the
 #	next instruction is also one we emulate, then we can bypass the
 #	overhead for the reserved opcode fault and exception 
 #	dispatching by merely looping back to the beginning of the
 #	emulator.  after the ret restores all registers, the stack
 #	contains the pc/psl pair for the next instruction.  the psl is
 #	examined to see if the t-bit is set.  if so, we can't do the
 #	optimization.  if t is clear, we then examine the next opcode.
 #	if it is one which we emulate, a branch is made to emulate$
 #	to begin emulation of the next instruction.  note that the
 #	"arguments" to emulate$, a pc/psl pair, are already in place!
 #
 #	if the optimization can not be performed, an rei is executed
 #	which restores the pc and psl for the next instruction.
 #
 normal_exit:				# entrance
 	bbc	$psl_v,psl(fp),1f	# no integer overflow - bypass
 	bbc	$psl_iv,psl(fp),1f	# no integer overflow trap - skip
 	brw	int_overflow		# process the integer overflow trap
 1:	movab	short_local(fp),sp	# shorten the frame
 	movl	$8,r0			# r0 = size of pc, psl pair
 	bsbw	test_frame		# make sure we have room to push it
 	subl2	$8,reg_sp(fp)		# allocate room on the user's stack
 	movq	reg_pc(fp),*reg_sp(fp)	# push the pc, psl pair
 	movq	reg_ap(fp),save_ap(fp)	# put the user's pc, psl pair back
 	movab	2f,save_pc(fp)		# store our return point
 	movab	frame_end+4(fp),r0	# r0 = location of end of frame
 	subl3	r0,reg_sp(fp),r1	# r1 = distance of user sp from it
 
 	extzv	$0,$2,r1,r2		# r2 = stack alignment
 
 	insv	r2,$mask_align,$2,save_mask(fp) # store it into the frame

 
 	addl2	r2,r0			# compute the parameter area location
 	ashl	$-2,r1,-4(r0)		# store the parameter count
 
 	ret				# return (to next instruction)
 
 #+
 # perform instruction lookahead for speed optimization.
 # at this point, 0(sp) contains the pc of the next user instruction, 4(sp)
 # has the user psl.
 #-
 
 2:
	brb	9f	
/*
 *	I commented this code out so that it would not try to decode the
 *	next instruction.  The reason for this is that an array must
 *	be initialized to indicated what instructions can be
 *	decoded based on the machine's architecture. Maybe someday we 
 *	will do this.
 *
 *	bbs	$psl_t, 4(sp), 9f	# if t-bit set, don't do lookahead
 *	movq	r0, -(sp)		# save r0-r1 temporarily
 *	movl	8(sp), r1		# get pc in r1

 *	extzv	$psl_cam, $2, 12(sp), r0# get current access mode in r0
 
 *	prober	r0, $2, (r1)		# can we read the next two bytes?
 *	beql	8f			# if not, just return
 *	movzbl	(r1)+, r0		# get next opcode byte in r0
 * 	cmpb	r0, $0xfd		# 2-byte opcode?
 *	beql	0f			# skip if yes
 *	cmpb	r0, $0x40		# compare against addf2
 *	blssu	8f			# not emulated if lssu
 *	cmpb	r0, $0x76		# compare against cvtdf
 *	bgtru	8f			# not emulated if gtru
 *	mull2	$4, r0			# get bit offset of mask
 *	extzv	r0, $4, inst_types_1byte, r1 # get inst-types mask in r1
 
 
 *	brb	7f			# join common code
 *0:	cvtbl	(r1), r0		# get next opcode byte in r0
 *	blss	3f			# skip if greater than pushao (0x7f)
 *	cmpb	r0, $0x32		# compare against cvtdh
 *	blssu	8f			# not emulated if lssu
 *	mull2	$4, r0			# get bit offset of mask
 *	extzv	r0, $4, inst_types_2byte, r1 # get inst-types mask in r1
 
 
 *	brb	7f			# join common code
 *8:	movq	(sp)+, r0		# restore saved r0
 */

 9:
	rei				# return to the next user instruction
/*
 *3:	movzbl	$(it_f+it_h), r1	# assume cvtfh or cvthf
 *	cmpb	r0,$0x99		# compare against cvtfg
 *	bgtru	4f			# not cvtfg or cvtfh if gtru
 *	cmpb	r0,$0x98		# compare against cvtfh
 *	blssu	8b			# not emulated if lssu
 *	beql	7f			# r1 mask is correct for cvtfh
 *	xorb2	$(it_g+it_h), r1	# cvtfg - switch to using f and g
 *	brb	7f			# join common code
 *4:	cmpb	r0, $0xf6		# compare against cvthf
 *	blssu	8b			# not emulated if lssu
 *	beql	7f			# join common code if cvthf
 *	xorb2	$(it_f+it_d), r1	# cvthd - switch to using h and d
 *7:	ashl	$arc$v_dflt_emul, r1, r1# align mask with exe$gl_archflag
 *	bitl	r1, *$exe$gl_archflag	# should we emulate this instruction?
 
 *	beql	8b			# if all bits test zero, no
 *	movq	(sp)+, r0		# pop saved r0 and r1
 *	jmp	vax$$emulate_fp		# emulate the next instruction
 */

 # 	assume	arc$v_fflt_emul eq arc$v_dflt_emul+1
 #	assume	arc$v_gflt_emul eq arc$v_fflt_emul+1
 #	assume	arc$v_hflt_emul eq arc$v_gflt_emul+1
 #

 
 #+
 # the following two tables provide information on what floating types
 # are manipulated by each instruction.  for each opcode there are
 # four bits which, if set, indicate that the instruction uses d, f, g
 # and h_floating data, respectively.  these four bits are compared against
 # the corresponding four bits in exe$gl_archflag to see if the next 
 # instruction should be emulated; this test takes place in normal_exit.
 #-
 
 
 #+
 # macro inst_type generates table entries
 #-
 
 #	.macro	inst_type	opcode1,opcode2
 #	$$x=0
 #	.irpc	$$t,<opcode2>
 #	$$x=$$x+it_'$$t'
 #	.endr
 #	$$x=$$x@4
 #	.irpc	$$t,<opcode1>
 #	$$x=$$x+it_'$$t'
 #	.endr
 #	.byte	$$x
 #	.endm
 
 #+
 # inst_types_1byte - masks for 1-byte instructions.
 # covers opcodes 40 (addf2) through 76 (cvtdf)
 #-
 
 # inst_types_1byte=.-(0x40/2)	# offset for first opcode
.set	inst_types_1byte,0x277
 # 	inst_type	f,f		# addf2, addf3
.byte 0x22
 #	inst_type	f,f		# subf2, subf3
.byte 0x22
 #	inst_type	f,f		# mulf2, mulf3
.byte 0x22
 #	inst_type	f,f		# divf2, divf3
.byte 0x22	
 #	inst_type	f,f		# cvtfb, cvtfw
.byte 0x22
 # 	inst_type	f,f		# cvtfl, cvtrfl
.byte 0x22
 # 	inst_type	f,f		# cvtbf, cvtwf
.byte 0x22
 # 	inst_type	f,f		# cvtlf, acbf
.byte 0x22
 # 	inst_type	f,f		# movf, cmpf
.byte 0x22
 # 	inst_type	f,f		# mnegf, tstf
.byte 0x22
 # 	inst_type	f,f		# emodf, polyf
.byte 0x22
 # 	inst_type	fd,x		# cvtfd, <57>
.byte 0x3
 # 	inst_type	x,x		# adawi, <59>
.byte 0x0
 # 	inst_type	x,x		# <5a>, <5b>
.byte 0x0
 # 	inst_type	x,x		# insqhi, insqti
.byte 0x0
 # 	inst_type	x,x		# remqhi, remqti
.byte 0x0
 # 	inst_type	d,d		# addd2, addd3
.byte 0x11
 # 	inst_type	d,d		# subd2, subd3
.byte 0x11
 # 	inst_type	d,d		# muld2, muld3
.byte 0x11
 # 	inst_type	d,d		# divd2, divd3
.byte 0x11
 # 	inst_type	d,d		# cvtdb, cvtdw
.byte 0x11
 # 	inst_type	d,d		# cvtdl, cvtrdl
.byte 0x11
 # 	inst_type	d,d		# cvtbd, cvtwd
.byte 0x11
 # 	inst_type	d,d		# cvtld, acbd
.byte 0x11
 # 	inst_type	d,d		# movd, cmpd
.byte 0x11
 # 	inst_type	d,d		# mnegd, tstd
.byte 0x11
 # 	inst_type	d,d		# emodd, polyd
.byte 0x11
 # 	inst_type	fd,x		# cvtdf, <77>
.byte 0x3
 
 #+
 # inst_types_2byte - masks for 2-byte instructions.
 # covers opcodes 32fd (cvtdh) through 7ffd (pushao)
 #-
 
 # inst_types_2byte=.-(0x32/2)	# offset for first opcode
.set	inst_types_2byte,0x29a
 # 	inst_type	dh,gf		# cvtdh, cvtgf
.byte 0x69
 # 	inst_type	x,x		# <34fd>, <35fd>
.byte 0x0
 # 	inst_type	x,x		# <36fd>, <37fd>
.byte 0x0
 # 	inst_type	x,x		# <38fd>, <39fd>
.byte 0x0
 # 	inst_type	x,x		# <3afd>, <3bfd>
.byte 0x0
 # 	inst_type	x,x		# <3cfd>, <3dfd>
.byte 0x0
 # 	inst_type	x,x		# <3efd>, <3ffd>
.byte 0x0
 # 	inst_type	g,g		# addg2, addg3
.byte 0x44
 # 	inst_type	g,g		# subg2, subg3
.byte 0x44
 # 	inst_type	g,g		# mulg2, mulg3
.byte 0x44
 # 	inst_type	g,g		# divg2, divg3
.byte 0x44
 # 	inst_type	g,g		# cvtgb, cvtgw
.byte 0x44
 # 	inst_type	g,g		# cvtgl, cvtrgl
.byte 0x44
 # 	inst_type	g,g		# cvtbg, cvtwg
.byte 0x44
 # 	inst_type	g,g		# cvtlg, acbg
.byte 0x44
 # 	inst_type	g,g		# movg, cmpg
.byte 0x44
 # 	inst_type	g,g		# mnegg, tstg
.byte 0x44
 # 	inst_type	g,g		# emodg, polyg
.byte 0x44
 # 	inst_type	gh,x		# cvtgh, <57fd>
.byte 0xc
 # 	inst_type	x,x		# <58fd>, <59fd>
.byte 0x0
 # 	inst_type	x,x		# <5afd>, <5bfd>
.byte 0x0
 # 	inst_type	x,x		# <5cfd>, <5dfd>
.byte 0x0
 # 	inst_type	x,x		# <5efd>, <5ffd>
.byte 0x0
 # 	inst_type	h,h		# addh2, addh3
.byte 0x88
 # 	inst_type	h,h		# subh2, subh3
.byte 0x88
 # 	inst_type	h,h		# mulh2, mulh3
.byte 0x88
 # 	inst_type	h,h		# divh2, divh3
.byte 0x88
 # 	inst_type	h,h		# cvthb, cvthw
.byte 0x88
 # 	inst_type	h,h		# cvthl, cvtrhl
.byte 0x88
 # 	inst_type	h,h		# cvtbh, cvtwh
.byte 0x88
 # 	inst_type	h,h		# cvtlh, acbh
.byte 0x88
 # 	inst_type	h,h		# movh, cmph
.byte 0x88
 # 	inst_type	h,h		# mnegh, tsth
.byte 0x88
 # 	inst_type	h,h		# emodh, polyh
.byte 0x88
 # 	inst_type	hg,x		# cvthg, <77fd>
.byte 0xc
 # 	inst_type	x,x		# <78fd>, <79fd>
.byte 0x0
 # 	inst_type	x,x		# <7afd>, <7bfd>
.byte 0x0
 # 	inst_type	h,h		# clro, movo
.byte 0x88
 # 	inst_type	h,h		# movao, pushao
.byte 0x88
 
 #
 #	test_frame - test frame location and move if necessary
 #
 #		entered by subroutine branching
 #
 #		parameter:	r0 = size of information to be pushed
 #
 #		returns with	r0 = distance frame was moved
 #
 #	discussion
 #
 #	    this routine determines whether or not the address given
 #	by subtracting r0 from the user's stack pointer can be made
 #	the location following a parameter list without the location
 #	being within the local storage. if this cannot be done then
 #	the entire procedure frame is moved so the condition can be
 #	satisfied. the distance that the procedure frame was moved
 #	is returned in r0. the value is zero if the frame is not 
 #	moved.
 #
 #	note:	1. the switch from one frame location to another is
 #		   performed by a single indivisible popr instruction
 #		   so the emulator is never in an anomalous state.
 #
 #		2. if the frame is moved to a higher address, then
 #		   the saved ap and fp are changed to the values of
 #		   the emulated registers. the reason for this is
 #		   that the move may overlay a valid frame so it is
 #		   assumed that the user's ap and fp have been changed
 #		   by the instruction to information about a new valid
 #		   frame. the implementor thinks that all of this is
 #		   pretty strange but if the program will work with
 #		   the hardware it will still work with the emulator.
 #
 test_frame:				# entrance
 	pushl	$0			# push a zero
 	subl3	r0,reg_sp(fp),r0	# compute pushed information address
 
 	bicl2	$3,r0			# align the value
 	movab	local_end(fp),r1	# r1 = end of local storage
 	cmpl	r0,r1			# does push extend below the frame ?
 	bgequ	2f			# no - bypass
 	bicl3	$3,sp,r3		# r3 = aligned stack pointer
 	subl2	$24,r3			# adjust for additional pushes
 	movl	r0,r2			# r2 = address following moved frame
 	cmpl	r2,r3			# does it extend into the frame ?
 	blequ	3f			# no - bypass
 	movl	r3,r2			# yes - use address below the frame
 	brb	3f			# bypass
 2:	movab	frame_end+1027(fp),r2	# r2 = last possible parameter end
 	cmpl	r0,r2			# does the push end above it ?
 	blequ	5f			# no - bypass
 	movq	reg_ap(fp),save_ap(fp)	# change the saved ap and fp
 	bicl3	$3,r0,r2		# r2 = aligned user stack pointer
 3:	subl2	r1,r2			# r2 = distance of the move

 	pushl	r2			# push the quantity
 	pushab	(sp)[r2]		# push the modified sp
 	pushab	(fp)[r2]		# push the modified fp
 	pushab	(ap)[r2]		# push the modified ap
 	pushab	save_align(fp)[r2]	# push the new alignment bits location
 	pushab	save_parcnt(fp)[r2]	# push the new parameter count address
 	movab	frame_end+4(fp)[r2],r3	# r3 = new frame end + 4 location
 	subl3	r3,r0,r3		# r3 = distance to user's sp
 	ashl	$-2,r3,-(sp)		# push the new parameter count
 
 	subl3	sp,r1,r0		# r0 = number of bytes to move
 	movl	sp,r1			# r1 = location of bytes to move
 	tstl	r2			# will we extend the stack ?
 	bgeq	4f			# no - skip
 	addl2	r2,sp			# yes - extend the stack pointer
 4:	movc3	r0,(r1),(r1)[r2]	# move the frame
 	cvtlb	(sp)+,*(sp)+		# store the new parameter count
 	clrb	*(sp)+			# clear the new alignment bits
 	popr	$0x7000			# switch to the new frame ^m<ap,fp,sp>
 5:	popr	$0x1			# r0 = distance frame was moved
 	rsb				# return
 #

 
 #
 #	cond_handler - internal condition handler
 #
 #		parameters:	p1 = signal array location
 #				p2 = mechanism array location
 #
 #		returns with	r0 = condition response
 #
 #	discussion
 #	
 #	    this routine is the internal condition handler for the
 #	emulator. since the emulator does not make constructive use
 #	of exceptions in its main procedure, this routine requests 
 #	resignaling of all conditions it intercepts.
 #
 #	    if the condition is ss$_unwind which indicates that an
 #	unwind is about to take place, then it restores the argument
 #	count longword in the parameter list for the procedure so the
 #	unwind will work properly.
 #
 cond_handler:				# entrance
 	.word	0			# entry mask
 	movq	4(ap),r0		# r0,r1 = condition array locations
 # 	cmpcond	ss$_unwind,4(r0)	# is this an unwind ?
	 cmpzv $3,$26,4(r0),$ss$_unwind
 	bneq	1f			# no - bypass
 	movl	4(r1),r0		# r0 = frame location
 	movb	save_align(r0),r1	# r1 = safe copy of alignment bits
 	movzbl	save_parcnt(fp),-(sp)	# push the argument count
 	insv	r1,$mask_align,$2,save_mask(r0) # store align bits in frame
 
 	addl2	r1,r0			# add to the frame location
 	movl	(sp)+,frame_end(r0)	# store the argument count
 1:	movzwl	$ss$_resignal,r0	# resignal the condition
 	ret				# return
 #

 
 #	****************************************************************
 #	*							       *
 #	*							       *
 #	*		instruction emulation routines		       *
 #	*							       *
 #	*							       *
 #	****************************************************************
 #
 #
 #	introduction
 #	------------
 #
 #	    following are the routines for emulating the individual 
 #	new instructions. there is one routine for each instruction
 #	but the structure of most of these routines is extremely
 #	simple so we have included all of the descriptive information
 #	here rather than duplicating it for each routine. special
 #	discussions are given for those instructions or families of
 #	instructions which do not quite fit into the general patterns.
 #
 #	    the routines themselves have been written so that they
 #	will be easy to follow. because of this the temptation to
 #	remove a considerable amount of duplicated code has been
 #	staunchly resisted.
 #
 #	    the emulation routines have names which are of the form
 #	"inst_mnemonic", are entered by branching from the routine
 #	emulator, and when instruction is complete the routines branch
 #	to normal_exit. when exceptions occur, then flow of control is
 #	somewhat more complicated and is described below.
 #
 #
 #	operand processing
 #	------------------
 #
 #	    the first step for each of the instructions is to process
 #	the instruction operands (this process is inhibited only for
 #	polyx when fpd is set in the psl). this is done by
 #	calling the operand scanning routines for each operand and by
 #	saving the operands values (for read and modify access
 #	operands) and operand addresses (for write, modify, and 
 #	address, access operands) in the special areas of the frame
 #	allocated for that purpose. floating values of all types that
 #	are input are converted to our internal floating format by the
 #	unpack routines which are described below.
 #
 #
 #	instruction emulation
 #	---------------------
 #
 #	    after all of the operands have been processed, the action
 #	of the instruction is performed usually by calling one of the
 #	arithmetic routines. for many of the move and convert 
 #	instructions no special emulation action is necessary since
 #	everything is done by the pack and unpack routines. all of the

 #	floating arithmetic is performed using our internal floating
 #	representation.
 #
 #
 #	storing the results
 #	-------------------
 #
 #	    the last step of instruction emulation is storing the
 #	resulting values and updating the condition codes. the values
 #	are stored in the order in which their corresponding operands
 #	occur so the instruction is emulated properly when the write
 #	or modify access operands overlap. floating values are 
 #	converted from the internal floating representation to the
 #	target representation by one of the pack routines described
 #	below. after the results are output, the condition codes in
 #	the emulated psl are updated. this order of operation is 
 #	important since the pack routines may convert very small
 #	nonzero values to zero values if an underflow occurs and fu is
 #	clear in the psl. when the instruction emulation is complete
 #	the routine branches to normal_exit.
 #
 #
 #	exceptions
 #	----------
 #
 #	    except for the integer overflow trap, all of the 
 #	exceptions that the emulator checks for are faults. when
 #	faults occur the emulator restores everything to a state in
 #	which the instruction can be restarted and signals the fault.
 #	for the integer overflow trap, the instruction is run to
 #	completion, possibly outputing a truncated result, and the
 #	trap is signaled. here we describe how instruction emulation
 #	is organized so this can be accomplished. further information
 #	can be found in the essay on exception processing which 
 #	appears below.
 #
 #
 #	faults
 #
 #	    until the results of an instruction are output, all of the
 #	changes which take place to any register are additions and 
 #	subtractions of small integers. these changes are also 
 #	recorded in the change bytes corresponding to the registers.
 #	therefore the only requirement necessary for correct fault
 #	processing is to insure that all fault detection takes place
 #	before any of the instruction results are output (actually,
 #	things are a little more complicated for polyx).
 #	this is done by making the result outputing steps the last
 #	part of instruction emulation. in this way fault detection
 #	can be placed anywhere in the emulator it is convenient rather
 #	than requiring close synchronization with the instruction
 #	emulation logic. for this reason direct processing of faults
 #	(rather than, say, returning status codes) appears throughout
 #	the common emulator subroutines.
 #
 #	    the architecture makes no special requirements on the
 #	the condition codes generated by a fault except that they

 #	be sufficient for correctly restarting the instruction. in
 #	general, the v bit is cleared by emulator on entry to an
 #	instruction emulation routine since the bit is used for
 #	detecting integer overflow traps (see below). none of the
 #	other condition bits is altered until the results are output
 #	at the end of instruction emulation. consequently all of the
 #	other condition bits are preserved into faults. (with the
 #	present set of emulated instructions the only preservation
 #	requirement is that the c bit be preserved on faults by the
 #	acbx instructions.)
 #
 #
 #	integer overflow traps
 #
 #	    when a integer overflow is detected (either in a common
 #	subroutine or in the instruction emulation routine) the v
 #	bit is set in the emulated condition codes and the value is
 #	truncated. everything proceeds normally until control reaches
 #	normal_exit where the v and iv bits in the emulated psl are
 #	checked. if both are set then an integer overflow trap is
 #	signaled.
 #
 #
 #	access modes and access violations
 #
 #	    this version of the emulator has been designed to operate
 #	at the same access mode as the instruction being emulated.
 #	however most of the instruction emulation logic has been 
 #	designed to operate at any access mode that is not less 
 #	privleged than that of the instruction (exceptions: the logic
 #	for getting in, the logic for getting out, and the exception
 #	signaling logic). all attempts to access memory on behalf of
 #	the instruction are probed using the access mode contained in
 #	the local cell mode. this is normally set to the current 
 #	access mode but may be set to some less privleged access mode.
 #	because this version of the emulator operates on the user
 #	stack it is not necessary to probe stack operations, however,
 #	these probes are still done to insure that the code will 
 #	remain usable for different access modes.
 #
 #
 #	notes on the acbx instructions
 #	---------------------------------------
 #
 #	    for these instructions the operands are processed, the
 #	step is added to the index, and the sum is packed and output.
 #	afterwards the sum is unpacked again and compared with the
 #	limit, the type of comparison depending on the sign of the
 #	step. the packing and unpacking is necessary to truncate the
 #	sum to the correct number of bits, to perform any rounding,
 #	and to check for underflow or overflow exceptions. if the
 #	branch is to be taken, the branch destination is moved into
 #	the emulated pc.
 #
 #
 #	notes on the emodx instructions
 #	-----------------------------------------

 #
 #	    for these instructions the first two operands are a 
 #	floating value of the appropriate type and a word containing
 #	some extension bits. when the extension bits are picked up
 #	they are stored in the correct position of the unpacked first
 #	operand. the remaining operands are scanned and flag bits 1
 #	and 7 are used to remember which output operands are in the
 #	registers. the multiply is then performed using the proper
 #	arithmetic routine and the product is truncated to the correct
 #	number of bits. next the integer part is extracted and saved
 #	in an internal cell while the fraction part is extracted and
 #	packed. next any register output operands are output and
 #	the routine test_frame is called to insure that the user's 
 #	stack pointer is within the parameter area. next any output
 #	operands in memory are output with stores into the emulator's
 #	working storage disabled .if both output operands are in the
 #	same type of storage, then the integer part is output before
 #	the fraction part. this complicated method of outputing the
 #	results is necessary because one of the register operands may
 #	contain sp and extend the user's stack into the emulator's
 #	working storage. the call to test_frame will move the frame
 #	if this occurs so if the other operand will be stored into
 #	memory properly if it is not below the user's stack pointer.
 #
 #
 #	notes on the polyx instructions
 #	-----------------------------------------
 #
 #	    these instructions have especially complicated emulation
 #	routines because they do a lot, have a large number of 
 #	implicit inputs and outputs, and are intended to be resumed
 #	instead of restarted when faults occur. for this reason we
 #	describe the action of the instruction emulation routines in
 #	some detail.
 #
 #	    these instructions can be thought as having two states.
 #	in the first of these states no unreversable changes have 
 #	been made to the registers so if a fault occurs the 
 #	instruction can be restarted. the instruction remains in this
 #	state until all of the operands have been processed and the
 #	first coefficient has been validated. after this point the
 #	instruction saves various things in the registers r0-r5 (and
 #	on the stack for polyh) so the instruction can no longer be
 #	restarted but the information saved is sufficient for resuming
 #	the instruction after a fault. when this second state is
 #	reached the fpd bit is set in the psl so the when the 
 #	instruction emulation routine is entered for resuming the 
 #	instruction it will know enough to do so.
 #
 #	    following is an outline of the steps in the emulation of
 #	the two instructions. the text generally describes polyg and
 #	the differences for polyh are noted in parentheses.
 #
 #
 #	     1. this is the first step for the instruction emulation.
 #		if the fpd bit is clear in the psl then control passes
 #		to step 2. otherwise the following actions which are

 #		concerned with restarting the instruction take place:
 #
 #		the length of the instruction operands is retrieved 
 #		from the high order three bytes of the user's r2 (r4
 #		for polyh) and added to the current pc and to the 
 #		change byte for the pc. if the instruction terminates
 #		the pc will be positioned following the instruction
 #		and if the instruction faults it will be reset to the
 #		location of the instruction.
 #
 #		the result so far is unpacked from r0-r1 (r0-r3 for
 #		polyh) and the unpacked value is stored in operand2.
 #		the condition codes are set to describe this value.
 #
 #		the argument is unpacked from r4-r5 (from a stacked
 #		octaword for polyh, which is probed) and the unpacked
 #		value is stored in operand3.
 #
 #		the remaining coefficient count in the low order byte
 #		of r2 (r4 for polyh) is checked for validity.
 #
 #		finally control passes to step 3.
 #
 #
 #	     2. this step performs all of the processing for initial
 #		entry to the instruction.
 #
 #		the first operand is processed and the unpacked
 #		argument is saved in operand3.
 #
 #		the second operand is processed and the degree is 
 #		checked for validity and the value is saved 
 #		temporarily in address1.
 #
 #		the third operand is processed and the address of the
 #		coefficient table is saved. the first coefficient is
 #		probed, unpacked, and saved in operand2.
 #
 #		if the instruction is polyh then the user's sp is 
 #		decremented by 16 (and so is the change byte) and
 #		the argument value in operand3 is packed and output
 #		to the allocated stack area. (if a fault occurs before
 #		fpd is set then sp will be reinitilized properly.)
 #
 #		the coefficient in operand2 is packed and stored in
 #		the user's registers r0-r1 (r0-r4 for polyh), the
 #		address of the remaining coefficients is stored in the
 #		user's r4 (r6 for polyh), the degree is stored in the
 #		low order byte of the user's r2 (r4 for polyh), and
 #		the length of the instruction operands (the pc change
 #		byte minus two) is saved in the upper three bytes of
 #		that register. the condition codes are set based on
 #		the value in operand2.
 #
 #		all of the change bytes except that for pc are cleared
 #		and the bit fpd is set in the emulated psl.
 #

 #		if the instruction is polyg then the argument in
 #		operand3 is packed and saved in the user's r4-r5.
 #
 #		control passes to step 3.
 #
 #
 #	     3. this step performs the basic polynomial evaluation 
 #		iteration.
 #
 #		if the remaining coefficient count in the low order
 #		byte of the user's r2 (r4 for polyh) is zero then 
 #		control passes to step 4.
 #	
 #		the value so far in operand2 and the argument in
 #		operand3 are multiplied and the unnormalized product
 #		is truncated to 63 (127 for polyh) bits and stored
 #		in operand1. the truncation is performed by clearing
 #		the low order bit of the 64 (128 for polyh) bit
 #		product returned by the multiply routine.
 #
 #		the coefficient addressed by the user's r3 (r5 for 
 #		polyh) is probed and unpacked to operand2. the result
 #		is then added to operand1.
 #
 #		the new value so far in operand1 is packed and stored
 #		in the user's r0-r1 (r0-r3 for polyh). the condition
 #		codes are set based on this value. the value is then
 #		unpacked and stored in operand2.
 #
 #		the remaining coefficient count in the low order byte
 #		of r2 (r4 for polyh) is decremented and the pointer to
 #		the next coeffiecient in r3 (r5 for polyh) is
 #		incremented to point to the next coefficient.
 #
 #		control then passes to the beginning of this step.
 #
 #
 #	     4. this step performs the termination of the instruction.
 #
 #		the register r2 (r4 for polyh) which contains the
 #		instruction length and the coefficient count is
 #		cleared.
 #
 #		if the instruction was polyg then the registers r4-r5
 #		which contained the argument value are cleared.
 #
 #		if the instruction was polyh then the user's sp is
 #		incremented by 16 to unstack the argument.
 #
 #		the fpd bit in the psl is cleared.
 #
 #		instruction emulation is now complete.
 #
 #
 #	    careful reading of the above outline will show that the
 #	polyg and polyh instructions are correctly emulated even down
 #	to the handling of faults. faults may be detected at any of

 #	the probes and at some of the pack and unpack operations. when
 #	faults are detected control immediatly leaves the outline so
 #	it is important that everything be correct at the time the 
 #	check is made. the reader may notice that some results are
 #	packed and then immediatly unpacked. this is done to check for
 #	overflow and underflow and to perform any rounding specified
 #	by the architecture. this technique also converts nonstandard
 #	floating zero representations to standard ones.
 #

 #
 #	4f acbf - add compare and branch f_floating
 #
 inst_acbf:
 	set_op_types	f
 	brb	inst_acbx
 
 #
 #	6f acbd - add compare and branch d_floating
 #
 inst_acbd:
 	set_op_types	d
 	brb	inst_acbx
 
 #
 #	4ffd acbg - add compare and branch g_floating
 #
 inst_acbg:
 	set_op_types	g
 	brb	inst_acbx
 
 #
 #	6ffd acbh - add compare and branch h_floating
 #
 inst_acbh:
 	set_op_types	h
 # brb	inst_acbx
 
 inst_acbx:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	bsbw	read_access		# second operand is read only
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	modify_access		# third operand is modified
 	movl	r11,address1(fp)	# save the operand address
 	bsbw	unpack_float1		# unpack and save the value
 	bsbw	branch_word		# fourth operand is branch destination
 	movl	r11,address2(fp)	# save the branch destination
 	bsbw	add_real		# add the step and index
 	bsbw	pack_float1		# pack the index value
 	movl	address1(fp),r11	# r11 = destination address
 	bsbw	store_operand		# store into third operand
 	bsbw	unpack_float1		# put the value back
 	movab	operand1(fp),r1 	# r1 = location of index value
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	bicb2	$pslm_v,psl(fp) 	# clear v in the psl
 	movab	operand2(fp),r1 	# r1 = address of step value
 	bsbw	test_real		# test the value
 	blss	2f			# it's negative - bypass
 	movab	operand1(fp),r1 	# r1 = address of index value
 	movab	operand3(fp),r2 	# r2 = address of limit value
 	bsbw	compare_real		# have we passed the limit ?
 	bgtr	3f			# yes - bypass
 1:	movl	address2(fp),reg_pc(fp) # perform the branch
 	brb	3f			# bypass
 2:	movab	operand1(fp),r1 	# r1 = address of index value

 	movab	operand3(fp),r2 	# r2 = address of limit value
 	bsbw	compare_real		# have we passed the limit ?
 	bgeq	1b			# no - perform the branch
 3:	brw	normal_exit		# done
 
 #
 #	40 addf2 - add f_floating (two operands)
 #
 inst_addf2:				# entrance
 	set_op_types	f
 	brb	inst_addx2
 
 #
 #	60 addd2 - add d_floating (two operands)
 #
 inst_addd2:				# entrance
 	set_op_types	d
 	brb	inst_addx2
 
 #
 #	40fd addg2 - add g_floating (two operands)
 #
 inst_addg2:				# entrance
 	set_op_types	g
 	brb	inst_addx2
 
 #
 #	60fd addh2 - add hfloat (two operands)
 #
 inst_addh2:				# entrance
 	set_op_types	h
 #brb	inst_addx2
 
 inst_addx2:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	bsbw	modify_access		# second operand is modified
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	add_real		# compute the sum
 	bsbw	pack_float1		# pack the sum
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	41 addf3 - add f_floating (three operands)
 #
 inst_addf3:				# entrance
 	set_op_types	f
 	brb	inst_addx3
 
 #
 #	61 addd3 - add d_floating (three operands)
 #
 inst_addd3:				# entrance

 	set_op_types	d
 	brb	inst_addx3
 
 #
 #	41fd addg3 - add g_floating (three operands)
 #
 inst_addg3:				# entrance
 	set_op_types	g
 	brb	inst_addx3
 
 #
 #	61fd addh3 - add hfloat (three operands)
 #
 inst_addh3:				# entrance
 	set_op_types	h
 #brb	inst_addx3
 
 inst_addx3:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	bsbw	read_access		# second operand is read only
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	write_access		# third operand is write only
 	movl	r11,address1(fp)	# save the destination address
 	bsbw	add_real		# compute the sum
 	bsbw	pack_float1		# pack the sum
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	7cfd clro - clear octaword
 #
 #	7cfd clrh - clear h_floating
 #
 inst_clro:				# entrance
 	set_op_types	o
 	bsbw	write_access		# first operand is write only
 	clrq	(r11)+			# clear the first part of the value
 	clrq	(r11)			# clear the second part of the value
 	bicl2	$pslm_nzv,psl(fp)	# clear the condition codes except c
 	bisl2	$pslm_z,psl(fp) 	# set the z bit in the psl
 	brw	normal_exit		# done
 
 #
 #	51 cmpf - compare f_floating
 #
 inst_cmpf:				# entrance
 	set_op_types	f
 	brb	inst_cmpx
 
 #
 #	71 cmpd - compare d_floating
 #
 inst_cmpd:				# entrance
 	set_op_types	d

 	brb	inst_cmpx
 
 #
 #	51fd cmpg - compare g_floating
 #
 inst_cmpg:				# entrance
 	set_op_types	g
 	brb	inst_cmpx
 
 #
 #	71fd cmph - compare h_floating
 #
 inst_cmph:				# entrance
 	set_op_types	h
 #brb	inst_cmpx
 
 inst_cmpx:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	bsbw	read_access		# second operand is read only
 	bsbw	unpack_float2		# unpack and save the value
 	movab	operand1(fp),r1 	# r1 = location of first value
 	movab	operand2(fp),r2 	# r2 = location of second value
 	bsbw	compare_real		# compare the values
 	bsbw	set_condition		# set the condition codes
 	bicl2	$pslm_vc,psl(fp)	# clear the v bit and c bit in the psl
 	brw	normal_exit		# done
 
 #
 #	4c cvtbf - convert byte to f_floating
 #
 inst_cvtbf:				# entrance
 	set_op_types	b,f
 	brb	inst_cvtbx
 
 #
 #	6c cvtbd - convert byte to d_floating
 #
 inst_cvtbd:				# entrance
 	set_op_types	b,d
 	brb	inst_cvtbx
 
 #
 #	4cfd cvtbg - convert byte to g_floating
 #
 inst_cvtbg:				# entrance
 	set_op_types	b,g
 	brb	inst_cvtbx
 
 #
 #	6cfd cvtbh - convert byte to h_floating
 #
 inst_cvtbh:				# entrance
 	set_op_types	b,h
 	brb	inst_cvtbx
 
 #

 #	4d cvtwf - convert word to f_floating
 #
 inst_cvtwf:
 	set_op_types	w,f
 	brb	inst_cvtwx
 
 #
 #	6d cvtwd - convert word to d_floating
 #
 inst_cvtwd:
 	set_op_types	w,d
 	brb	inst_cvtwx
 
 #
 #	4dfd cvtwg - convert word to g_floating
 #
 inst_cvtwg:				# entrance
 	set_op_types	w,g
 	brb	inst_cvtwx
 
 #
 #	6dfd cvtwh - convert word to h_floating
 #
 inst_cvtwh:				# entrance
 	set_op_types	w,h
 	brb	inst_cvtwx
 
 #
 #	4e cvtlf - convert long to f_floating
 #
 inst_cvtlf:				# entrance
 	set_op_types	l,f
 	brb	inst_cvtlx
 
 #
 #	6e cvtld - convert long to d_floating
 #
 inst_cvtld:				# entrance
 	set_op_types	l,d
 	brb	inst_cvtlx
 
 #
 #	4efd cvtlg - convert long to g_floating
 #
 inst_cvtlg:				# entrance
 	set_op_types	l,g
 	brb	inst_cvtlx
 
 #
 #	6efd cvtlh - convert long to h_floating
 #
 inst_cvtlh:				# entrance
 	set_op_types	l,h
 #brb	inst_cvtlx
 
 inst_cvtbx:
 inst_cvtwx:

 inst_cvtlx:
 	bsbw	read_access		# first operand is read only
 	bsbw	float_long		# convert to floating and save value
 	incl	op_index(fp)		# move to second operand
 	bsbw	write_access		# second operand is write only
 	movl	r11,address1(fp)	# save the destination address
 	bsbw	pack_float1		# pack the value
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	48 cvtfb - convert f_floating to byte
 #
 inst_cvtfb:
 	set_op_types	f,b
 	brb	inst_cvtxb
 
 #
 #	68 cvtdb - convert d_floating to byte
 #
 inst_cvtdb:
 	set_op_types	d,b
 	brb	inst_cvtxb
 
 #
 #	48fd cvtgb - convert g_floating to byte
 #
 inst_cvtgb:
 	set_op_types	g,b
 	brb	inst_cvtxb
 
 #
 #	68fd cvthb - convert h_floating to byte
 #
 inst_cvthb:
 	set_op_types	h,b
 	brb	inst_cvtxb
 
 #
 #	49 cvtfw - convert f_floating to word
 #
 inst_cvtfw:
 	set_op_types	f,w
 	brb	inst_cvtxw
 
 #
 #	69 cvtdw - convert d_floating to word
 #
 inst_cvtdw:
 	set_op_types	d,w
 	brb	inst_cvtxw
 
 #
 #	49fd cvtgw - convert g_floating to word
 #

 inst_cvtgw:
 	set_op_types	g,w
 	brb	inst_cvtxw
 
 #
 #	69fd cvthw - convert h_floating to word
 #
 inst_cvthw:
 	set_op_types	h,w
 	brb	inst_cvtxw
 
 #
 #	4a cvtfl - convert f_floating to long
 #
 inst_cvtfl:
 	set_op_types	f,l
 	brb	inst_cvtxl
 
 #
 #	6a cvtdl - convert d_floating to long
 #
 inst_cvtdl:
 	set_op_types	d,l
 	brb	inst_cvtxl
 
 #
 #	4afd cvtgl - convert g_floating to long
 #
 inst_cvtgl:
 	set_op_types	g,l
 	brb	inst_cvtxl
 
 #
 #	6afd cvthl - convert h_floating to long
 #
 inst_cvthl:
 	set_op_types	h,l
 	brb	inst_cvtxl
 
 inst_cvtxb:
 inst_cvtxw:
 inst_cvtxl:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	incl	op_index(fp)		# move to second operand
 	bsbw	write_access		# second operand is write only
 	movl	r11,address1(fp)	# save the destination location
 	bicl2	$pslm_nzvc,psl(fp)	# clear the condition codes
 	bsbw	fix_real		# fix the value
 	cmpb	*op_index(fp),$typ_w	# case on datatype
 	bgtr	3f			# skip if longword
 	beql	1f			# skip if word
 	cvtlb	r0,r0			# convert long to byte
 	brb	2f			# continue
 1:	cvtlw	r0,r0			# convert long to word
 2:	bvc	3f			# no overflow - skip
 	bisl2	$pslm_v,psl(fp) 	# indicate integer overflow

 3:	movl	address1(fp),r11	# get address of result
 	bsbw	store_operand		# store the result
 	bsbw	set_condition		# set the condition codes
 	brw	normal_exit		# done
 
 #
 #	56 cvtfd - convert f_floating to d_floating
 #
 inst_cvtfd:
 	set_op_types	f,d
 	brb	inst_cvtxy
 
 #
 #	99fd cvtfg - convert floating to g_floating
 #
 inst_cvtfg:				# entrance
 	set_op_types	f,g
 	brb	inst_cvtxy
 
 #
 #	98fd cvtfh - convert f_floating to h_floating
 #
 inst_cvtfh:				# entrance
 	set_op_types	f,h
 	brb	inst_cvtxy
 
 #
 #	76 cvtdf - convert d_floating to h_floating
 #
 inst_cvtdf:				# entrance
 	set_op_types	d,f
 	brb	inst_cvtxy
 
 #
 #	32fd cvtdh - convert d_floating to h_floating
 #
 inst_cvtdh:
 	set_op_types	d,h
 	brb	inst_cvtxy
 
 #
 #	33fd cvtgf - convert g_floating to f_floating
 #
 inst_cvtgf:
 	set_op_types	g,f
 	brb	inst_cvtxy
 
 #
 #	56fd cvtgh - convert g_floating to h_floating
 #
 inst_cvtgh:
 	set_op_types	g,h
 	brb	inst_cvtxy
 
 #
 #	f6fd cvthf - convert h_floating to f_floating
 #

 inst_cvthf:
 	set_op_types	h,f
 	brb	inst_cvtxy
 
 #
 #	f7fd cvthd - convert h_floating to d_floating
 #
 inst_cvthd:
 	set_op_types	h,d
 	brb	inst_cvtxy
 
 #
 #	76fd cvthg - convert h_floating to g_floating
 #
 inst_cvthg:
 	set_op_types	h,g
 #brb	inst_cvtxy
 
 inst_cvtxy:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	incl	op_index(fp)		# move to second operand
 	bsbw	write_access		# second operand is write only
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	pack_float1		# pack the value
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	4b cvtrfl - convert rounded f_floating to long
 #
 inst_cvtrfl:
 	set_op_types	f,l
 	brb	inst_cvtrxl
 
 #
 #	6b cvtrdl - convert rounded d_floating to long
 #
 inst_cvtrdl:
 	set_op_types	d,l
 	brb	inst_cvtrxl
 
 #
 #	4bfd cvtrgl - convert rounded g_floating to long
 #
 inst_cvtrgl:				# entrance
 	set_op_types	g,l
 	brb	inst_cvtrxl
 
 #
 #	6bfd cvtrhl - convert rounded h_floating to long
 #
 inst_cvtrhl:				# entrance
 	set_op_types	h,l
 #brb	inst_cvtrxl

 
 inst_cvtrxl:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack the value
 	incl	op_index(fp)		# move to second operand
 	bsbw	write_access		# second operand is write only
 	movl	r11,address1(fp)	# save the destination location
 	bicl2	$pslm_nzvc,psl(fp)	# clear the condition codes
 	bsbw	round_real		# round the value
 	movl	r0,*address1(fp)	# output the value
 	bsbw	set_condition		# set the condition codes
 	brw	normal_exit		# done
 
 #
 #	46 divf2 - divide f_floating (two operands)
 #
 inst_divf2:
 	set_op_types	f
 	brb	inst_divx2
 
 #
 #	66 divd2 - divide d_floating (two operands)
 #
 inst_divd2:
 	set_op_types	d
 	brb	inst_divx2
 
 #
 #	46fd divg2 - divide g_floating (two operands)
 #
 inst_divg2:
 	set_op_types	g
 	brb	inst_divx2
 
 #
 #	66fd divh2 - divide h_floating (two operands)
 #
 inst_divh2:
 	set_op_types	h
 #brb	inst_divx2
 
 inst_divx2:				# entrance
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	bsbw	modify_access		# second operand is modified
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	divide_float		# compute the quotient
 	bsbw	pack_float1		# pack the result
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	47 divf3 - divide f_floating (three operands)
 #

 inst_divf3:
 	set_op_types	f
 	brb	inst_divx3
 
 #
 #	67 divd3 - divide d_floating (three operands)
 #
 inst_divd3:
 	set_op_types	d
 	brb	inst_divx3
 
 #
 #	47fd divg3 - divide g_floating (three operands)
 #
 inst_divg3:
 	set_op_types	g
 	brb	inst_divx3
 
 #
 #	67fd divh3 - divide hfloat (three operands)
 #
 inst_divh3:				# entrance
 	set_op_types	h
 #brb	inst_divx3
 
 inst_divx3:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	bsbw	read_access		# second operand is read only
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	write_access		# third operand is write only
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	divide_float		# compute the quotient
 	bsbw	pack_float1		# pack the result
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	54 emodf - extended modulus f_floating
 #
 inst_emodf:
 	set_op_types	f,b,f,l,f
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float2		# unpack and save the operand
 	incl	op_index(fp)		# move to second operand
 	bsbw	read_access		# second operand is read only
 	movb	r0,fraction2+12(fp)	# insert bits 0-7 of the fraction
 	incl	op_index(fp)		# move to third operand
 	bsbw	read_access		# third operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	movb	$flag0m,flags(fp)	# inhibit checking for local store
 	incl	op_index(fp)		# move to fourth operand
 	bsbw	write_access		# fourth operand is write only
 	bbcc	$flag1,flags(fp),1f	# not register mode - skip
 	bbcs	$flag7,flags(fp),1f	# make a note

 1:	movl	r11,address1(fp)	# save the first destination address
 	incl	op_index(fp)		# move to fifth operand
 	bsbw	write_access		# fifth operand is write only
 	movl	r11,address2(fp)	# save the second destination address
 	bsbw	multiply_float		# compute the product
 	insv	$0,$0,r0,fraction1+12(fp)# truncate the product if necessary
 
 	bicl2	$pslm_nzvc,psl(fp)	# clear the condition codes
 	bsbw	fix_real		# fix the product
 	movl	r0,address3(fp)		# save the integer part
 	bsbw	fraction_real		# form the fractional part
 	bsbw	pack_float1		# pack the fraction value
 	pushl	r0			# push the fraction
 	bbc	$flag7,flags(fp),2f	# fourth operand not register - skip
 	movl	address3(fp),*address1(fp) # output the integer part
 2:	bbc	$flag1,flags(fp),3f	# fifth operand not register - skip
 	movl	(sp)+,*address2(fp)	# output the fraction
 3:	movl	$4,r0			# allow room for dummy store
 	bsbw	test_frame		# move the frame if necessary
 	bbs	$flag7,flags(fp),4f	# fourth operand is register - bypass
 	movl	$4,r10			# r10 = size of integer part
 	movl	address1(fp),r11	# r11 = location of fourth operand
 	bsbw	local_test		# check for a store into local storage
 	movl	address3(fp),(r11)	# output the integer part
 4:	bbs	$flag1,flags(fp),5f	# fifth operand is register - bypass
 	movl	$4,r10			# r10 = size of the fraction
 	movl	address2(fp),r11	# r11 = location of second operand
 	bsbw	local_test		# check for a store into local storage
 	movl	(sp)+,(r11)		# output the fraction
 5:	movab	operand1(fp),r1 	# r1 = location of the fraction
 	bsbw	test_real		# test the fraction
 	bsbw	set_condition		# set the condition codes
 	brw	normal_exit		# done
 
 #
 #	74 emodd - extended modulus d_floating
 #
 inst_emodd:
 	set_op_types	d,b,d,l,d
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float2		# unpack and save the operand
 	incl	op_index(fp)		# move to second operand
 	bsbw	read_access		# second operand is read only
 	movb	r0,fraction2+8(fp)	# insert bits 0-7 of the fraction
 	brb	common_emoddg		# join common d/g code
 
 #
 #	54fd emodg - extended modulus g_floating
 #
 inst_emodg:				# entrance
 	set_op_types	g,w,g,l,g
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float2		# unpack and save the operand
 	incl	op_index(fp)		# move to second operand
 	bsbw	read_access		# second operand is read only
 	rotl	$27,r0,r0		# position the high-order 11 bits
 	insv	r0,$0,$11,fraction2+8(fp) # insert bits 0-10 of the fraction

 
 common_emoddg:
 	incl	op_index(fp)		# move to third operand
 	bsbw	read_access		# third operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	movb	$flag0m,flags(fp)	# inhibit checking for local store
 	incl	op_index(fp)		# move to fourth operand
 	bsbw	write_access		# fourth operand is write only
 	bbcc	$flag1,flags(fp),1f	# not register mode - skip
 	bbcs	$flag7,flags(fp),1f	# make a note
 1:	movl	r11,address1(fp)	# save the first destination address
 	incl	op_index(fp)		# move to fifth operand
 	bsbw	write_access		# fifth operand is write only
 	movl	r11,address2(fp)	# save the second destination address
 	bsbw	multiply_float		# compute the product
 	insv	$0,$0,r0,fraction1+8(fp)# truncate the product if necessary
 
 	bicl2	$pslm_nzvc,psl(fp)	# clear the condition codes
 	bsbw	fix_real		# fix the product
 	movl	r0,address3(fp)		# save the integer part
 	bsbw	fraction_real		# form the fractional part
 	bsbw	pack_float1		# pack the fraction value
 	pushr	$0x03			# push the fraction ^m<r0,r1>
 	bbc	$flag7,flags(fp),2f	# fourth operand not register - skip
 	movl	address3(fp),*address1(fp) # output the integer part
 2:	bbc	$flag1,flags(fp),3f	# fifth operand not register - skip
 	movq	(sp)+,*address2(fp)	# output the fraction
 3:	movl	$8,r0			# allow room for dummy store
 	bsbw	test_frame		# move the frame if necessary
 	bbs	$flag7,flags(fp),4f	# fourth operand is register - bypass
 	movl	$4,r10			# r10 = size of integer part
 	movl	address1(fp),r11	# r11 = location of fourth operand
 	bsbw	local_test		# check for a store into local storage
 	movl	address3(fp),(r11)	# output the integer part
 4:	bbs	$flag1,flags(fp),5f	# fifth operand is register - bypass
 	movl	$8,r10			# r10 = size of the fraction
 	movl	address2(fp),r11	# r11 = location of second operand
 	bsbw	local_test		# check for a store into local storage
 	movq	(sp)+,(r11)		# output the fraction
 5:	movab	operand1(fp),r1 	# r1 = location of the fraction
 	bsbw	test_real		# test the fraction
 	bsbw	set_condition		# set the condition codes
 	brw	normal_exit		# done
 
 #
 #	74fd emodh - extended modulus hfloat
 #
 inst_emodh:				# entrance
 	set_op_types	h,w,h,l,h
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float2		# unpack and save the operand
 	incl	op_index(fp)		# move to second operand
 	bsbw	read_access		# second operand is read only
 	rotl	$31,r0,r0		# position the high-order 15 bits
 	insv	r0,$0,$15,fraction2(fp) # insert bits 0-14 of the fraction
 
 	incl	op_index(fp)		# move to third operand

 	bsbw	read_access		# third operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	movb	$flag0m,flags(fp)	# inhibit checking for local store
 	incl	op_index(fp)		# move to fourth operand
 	bsbw	write_access		# fourth operand is write only
 	bbcc	$flag1,flags(fp),1f	# not register mode - skip
 	bbcs	$flag7,flags(fp),1f	# make a note
 1:	movl	r11,address1(fp)	# save the first destination address
 	incl	op_index(fp)		# move to fifth operand
 	bsbw	write_access		# fifth operand is write only
 	movl	r11,address2(fp)	# save the second destination address
 	bsbw	multiply_float		# compute the product
 	insv	$0,$0,r0,fraction1(fp)	# truncate the product if necessary
 
 	bicl2	$pslm_nzvc,psl(fp)	# clear the condition codes
 	bsbw	fix_real		# fix the product
 	movl	r0,address3(fp)		# save the integer part
 	bsbw	fraction_real		# form the fractional part
 	bsbw	pack_float1		# pack the fraction value
 	pushr	$0xf			# push the fraction ^m<r0,r1,r2,r3>
 	bbc	$flag7,flags(fp),2f	# fourth operand not register - skip
 	movl	address3(fp),*address1(fp) # output the integer part
 2:	bbc	$flag1,flags(fp),3f	# fifth operand not register - bypass
 	movl	address2(fp),r11	# r11 = location of the register
 	movq	(sp)+,(r11)+		# output first part of the fraction
 	movq	(sp)+,(r11)		# output second part of the fraction
 3:	movl	$16,r0			# allow room for dummy store
 	bsbw	test_frame		# move the frame if necessary
 	bbs	$flag7,flags(fp),4f	# fourth operand is register - bypass
 	movl	$4,r10			# r10 = size of integer part
 	movl	address1(fp),r11	# r11 = location of fourth operand
 	bsbw	local_test		# check for a store into local storage
 	movl	address3(fp),(r11)	# output the integer part
 4:	bbs	$flag1,flags(fp),5f	# fifth operand is register - bypass
 	movl	$16,r10			# r10 = size of the fraction
 	movl	address2(fp),r11	# r11 = location of second operand
 	bsbw	local_test		# check for a store into local storage
 	movq	(sp)+,(r11)+		# output first part of the fraction
 	movq	(sp)+,(r11)		# output second part of the fraction
 5:	movab	operand1(fp),r1 	# r1 = location of the fraction
 	bsbw	test_real		# test the fraction
 	bsbw	set_condition		# set the condition codes
 	brw	normal_exit		# done
 
 #
 #	52 mnegf - move negated f_floating
 #
 inst_mnegf:
 	set_op_types	f
 	brb	inst_mnegx
 
 #
 #	72 mnegd - move negated d_floating
 #
 inst_mnegd:
 	set_op_types	d
 	brb	inst_mnegx

 
 #
 #	52fd mnegg - move negated g_floating
 #
 inst_mnegg:
 	set_op_types	g
 	brb	inst_mnegx
 
 #
 #	72fd mnegh - move negated hfloat
 #
 inst_mnegh:
 	set_op_types	h
 #brb	inst_mnegx
 
 inst_mnegx:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	bsbw	negate_real		# negate the value
 	bsbw	write_access		# second operand is write only
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	pack_float1		# pack the value
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done

 #
 #	7efd movao - move address of octaword
 #
 #	7efd movah - move address of h_floating
 #
 inst_movao:				# entrance
 	set_op_types	o,l
 	bsbw	address_access		# first operand is address only
 	movl	r11,address1(fp)	# save the operand address
 	incl	op_index(fp)		# move to second operand
 	bsbw	write_access		# second operand is write only
 	movl	address1(fp),(r11)	# output the operand address
 	bsbw	set_condition		# capture the condition code
 	bicl2	$pslm_v,psl(fp) 	# clear the v bit in the psl
 	brw	normal_exit		# done
 
 #
 #	50 movf - move f_floating
 #
 inst_movf:
 	set_op_types	f
 	brb	inst_movx
 
 #
 #	70 movd - move d_floating
 #
 inst_movd:
 	set_op_types	d
 	brb	inst_movx
 
 #
 #	50fd movg - move g_floating
 #
 inst_movg:
 	set_op_types	g
 	brb	inst_movx
 
 #
 #	70fd movh - move hfloat
 #
 inst_movh:
 	set_op_types	h
 #brb	inst_movx
 
 inst_movx:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	bsbw	write_access		# second operand is write only
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	pack_float1		# pack the value
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	movab	operand1(fp),r1		# r1 = location of the value
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	bicl2	$pslm_v,psl(fp)		# clear the v bit in the psl
 	brw	normal_exit		# done

 
 #
 #	7dfd movo - move octaword
 #
 inst_movo:
 	set_op_types	o
 	bsbw	read_access		# first operand is read only
 	movq	r0,operand1(fp) 	# save the first part of the value
 	movq	r2,operand1+8(fp)	# save the second part of the value
 	bsbw	write_access		# second operand is write only
 	movl	r11,address1(fp)	# save destination location
 	bsbw	test_octa		# test the value
 	bsbw	set_condition		# set the condition codes
 	bicl2	$pslm_v,psl(fp)		# clear the v bit in the psl
 	movl	address1(fp),r11	# r11 = destination location
 	movq	operand1(fp),(r11)+	# output the first part of the result
 	movq	operand1+8(fp),(r11)	# output the second part of the result
 	brw	normal_exit		# done
 
 #
 #	44 mulf2 - multiply f_floating (two operands)
 #
 inst_mulf2:
 	set_op_types	f
 	brb	inst_mulx2
 
 #
 #	64 muld2 - multiply d_floating (two operands)
 #
 inst_muld2:
 	set_op_types	d
 	brb	inst_mulx2
 
 #
 #	44fd mulg2 - multiply g_floating (two operands)
 #
 inst_mulg2:
 	set_op_types	g
 	brb	inst_mulx2
 
 #
 #	64fd mulh2 - multiply hfloat (two operands)
 #
 inst_mulh2:				# entrance
 	set_op_types	h
 #brb	inst_mulx2
 
 inst_mulx2:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float2		# unpack and save the first operand
 	bsbw	modify_access		# second operand is modified
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	unpack_float3		# unpack and save the second operand
 	bsbw	multiply_float		# compute the product
 	bsbw	pack_float1		# pack the value
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result

 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	45 mulf3 - multiply f_floating (three operands)
 #
 inst_mulf3:
 	set_op_types	f
 	brb	inst_mulx3
 
 #
 #	65 muld3 - multiply d_floating (three operands)
 #
 inst_muld3:
 	set_op_types	d
 	brb	inst_mulx3
 
 #
 #	45fd mulg3 - multiply g_floating (three operands)
 #
 inst_mulg3:
 	set_op_types	g
 	brb	inst_mulx3
 
 #
 #	65fd mulh3 - multiply hfloat (three operands)
 #
 inst_mulh3:
 	set_op_types	h
 #brb	inst_mulx3
 
 inst_mulx3:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	read_access		# second operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	bsbw	write_access		# third operand is write only
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	multiply_float		# compute the product
 	bsbw	pack_float1		# pack the value
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store the result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	55 polyf - evaluate polynomial f_floating
 #
 inst_polyf:				# entrance
 	set_op_types	f,w,b,f		# phantom fourth operand
 	bbc	$psl_fpd,psl(fp),1f	# not instruction resumption - bypass
 	extzv	$8,$24,reg_r2(fp),r0	# r0 = saved instruction length
 
 	addl2	r0,reg_pc(fp)		# position pc to end of instruction
 	addb2	r0,regmod_pc(fp)	# increment the pc modification count
 	movl	reg_r0(fp),r0		# r0 = result so far
 	bsbw	unpack_float2		# unpack and save the value

 	movab	operand2(fp),r1		# r1 = location of operand2
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	movl	reg_r1(fp),r0		# r0 = argument value
 	bsbw	unpack_float3		# unpack and save the value
 	cmpb	$31,reg_r2(fp)		# is the iteration count too large ?
 	bgequ	4f			# no - resume the instruction
 	brw	operand_fault		# process the reserved operand
 1:	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	incl	op_index(fp)		# look at second operand
 	bsbw	read_access		# second operand is read only
 	cmpl	$31,r0			# is the value reserved ?
 	bgequ	2f			# no - skip
 	brw	operand_fault		# process the reserved operand
 2:	movl	r0,address1(fp) 	# save the operand value
 	incl	op_index(fp)		# look at third operand
 	bsbw	address_access		# third operand is address only
 	prober	mode(fp),$4,(r11)	# can we read the first longword?
 
 	bneq	3f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 3:	movl	(r11)+,r0		# r0 = the first table entry
 	movl	r11,address2(fp)	# save the following address
 	incl	op_index(fp)		# use "fourth operand" type for rest
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	pack_float2		# pack the value
 	movl	r0,reg_r0(fp)		# save the value in user's r0
 	movab	operand2(fp),r1		# r1 = location of operand2
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	bicl2	$pslm_vc,psl(fp)	# clear the v bit and c bit in the psl
 	movl	address2(fp),reg_r3(fp)	# store next location in user's r3
 	movl	address1(fp),reg_r2(fp) # save the remaining iteration count
 	cvtbl	regmod_pc(fp),r0	# r0 = pc register modifications
 	clrq	regmod_r0(fp)		# clear modifications for r0 to r7
 	clrq	regmod_r8(fp)		# clear modifications for r8 to pc
 	movb	r0,regmod_pc(fp)	# put the pc modifications back
 	decl	r0			# subtract the operation code length
 	insv	r0,$8,$24,reg_r2(fp)	# save the value for resumption
 
 	bsbw	pack_float3		# pack the argument value
 	movl	r0,reg_r1(fp)		# save it for resumption
 	bbss	$psl_fpd,psl(fp),4f	# indicate first part done in psl
 4:	tstb	reg_r2(fp)		# more iterations to perform ?
 	beql	6f			# no - finish up
 	bsbw	multiply_float		# multiply the result and argument
 	incl	r0			# increment the shift count
 	insv	$0,$0,r0,fraction1+12(fp)# truncate the product
 
 	movl	reg_r3(fp),r11		# r11 = location of next table entry
 	prober	mode(fp),$4,(r11)	# can we read the next coefficient ?
 
 	bneq	5f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation

 5:	movl	*reg_r3(fp),r0		# r0 = next coefficient
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	add_real		# add the coefficient to the product
 	bsbw	pack_float1		# pack the result so far
 	movl	r0,reg_r0(fp)		# save the value
 	bsbw	unpack_float2		# unpack the result for next iteration
 	bsbw	set_condition1		# set the condition codes in the psl
 	addl2	$4,reg_r3(fp)		# update the table pointer
 	decb	reg_r2(fp)		# decrement the iteration counter
 	brw	4f			# start the next iteration
 6:	clrl	reg_r1(fp)		# 002
	clrl	reg_r2(fp)		# 002 polyf must have r1/r2 = 0
 	bbcc	$psl_fpd,psl(fp),7f	# indicate instruction complete
 7:	brw	normal_exit		# done
 
 #
 #	75 polyd - evaluate polynomial d_floating
 #
 inst_polyd:				# entrance
 	set_op_types	d,w,b,d		# phantom fourth operand
 	brw	inst_polydg
 
 #
 #	55fd polyg - evaluate polynomial g_floating
 #
 inst_polyg:				# entrance
 	set_op_types	g,w,b,g		# phantom fourth operand
 #brb	inst_polydg
 
 inst_polydg:
 	bbc	$psl_fpd,psl(fp),1f	# not instruction resumption - bypass
 	extzv	$8,$24,reg_r2(fp),r0	# r0 = saved instruction length
 
 	addl2	r0,reg_pc(fp)		# position pc to end of instruction
 	addb2	r0,regmod_pc(fp)	# increment the pc modification count
 	movq	reg_r0(fp),r0		# r0,r1 = result so far
 	bsbw	unpack_float2		# unpack and save the value
 	movab	operand2(fp),r1		# r1 = location of operand2
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	movq	reg_r4(fp),r0		# r0,r1 = argument value
 	bsbw	unpack_float3		# unpack and save the value
 	cmpb	$31,reg_r2(fp)		# is the iteration count too large ?
 	bgequ	8f			# no - resume the instruction
 	brw	operand_fault		# process the reserved operand
 8:	brw	4f
 1:	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	incl	op_index(fp)		# look at second operand
 	bsbw	read_access		# second operand is read only
 	cmpl	$31,r0			# is the value reserved ?
 	bgequ	2f			# no - skip
 	brw	operand_fault		# process the reserved operand
 2:	movl	r0,address1(fp) 	# save the operand value
 	incl	op_index(fp)		# look at third operand
 	bsbw	address_access		# third operand is address only
 	prober	mode(fp),$8,(r11)	# can we read the first quadword ?
 

 	bneq	3f			# yes - skip
 	movl	$8,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 3:	movq	(r11)+,r0		# r0,r1 = the first table entry
 	movl	r11,address2(fp)	# save the following address
 	incl	op_index(fp)		# use "fourth operand" type for rest
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	pack_float2		# pack the value
 	movq	r0,reg_r0(fp)		# save the value in user's r0-r1
 	movab	operand2(fp),r1		# r1 = location of operand2
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	bicl2	$pslm_vc,psl(fp)	# clear the v bit and c bit in the psl
 	movl	address2(fp),reg_r3(fp)	# store next location in user's r3
 	movl	address1(fp),reg_r2(fp) # save the remaining iteration count
 	cvtbl	regmod_pc(fp),r0	# r0 = pc register modifications
 	clrq	regmod_r0(fp)		# clear modifications for r0 to r7
 	clrq	regmod_r8(fp)		# clear modifications for r8 to pc
 	movb	r0,regmod_pc(fp)	# put the pc modifications back
 	decl	r0			# subtract the operation code length
 	cmpb	*op_index(fp),$typ_g	# polyg?
 	bneq	9f			# skip if not
 	decl	r0			# subtract another opcode byte length
 9:	insv	r0,$8,$24,reg_r2(fp)	# save the value for resumption
 
 	bsbw	pack_float3		# pack the argument value
 	movq	r0,reg_r4(fp)		# save it for resumption
 	bbss	$psl_fpd,psl(fp),4f	# indicate first part done in psl
 4:	tstb	reg_r2(fp)		# more iterations to perform ?
 	beql	6f			# no - finish up
 	bsbw	multiply_float		# multiply the result and argument
 	incl	r0			# increment the shift count
 	insv	$0,$0,r0,fraction1+8(fp)# truncate the product
 
 	movl	reg_r3(fp),r11		# r11 = location of next table entry
 	prober	mode(fp),$8,(r11)	# can we read the next coefficient ?
 
 	bneq	5f			# yes - skip
 	movl	$8,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 5:	movq	*reg_r3(fp),r0		# r0 = next coefficient
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	add_real		# add the coefficient to the product
 	bsbw	pack_float1		# pack the result so far
 	movq	r0,reg_r0(fp)		# save the value
 	bsbw	unpack_float2		# unpack the result for next iteration
 	bsbw	set_condition1		# set the condition codes in the psl
 	addl2	$8,reg_r3(fp)		# update the table pointer
 	decb	reg_r2(fp)		# decrement the iteration counter
 	brb	4b			# start the next iteration
 6:	clrl	reg_r2(fp)		# clear the user's r2
 	clrq	reg_r4(fp)		# clear the user's r4 and r5
 	bbcc	$psl_fpd,psl(fp),7f	# indicate instruction complete
 7:	brw	normal_exit		# done
 
 #
 #	75fd polyh - evaluate polynomial hfloat

 #
 inst_polyh:				# entrance
 	set_op_types	h,w,b,h		# use "phantom" fourth argument
 	bbc	$psl_fpd,psl(fp),3f	# not instruction resumption - bypass
 	extzv	$8,$24,reg_r4(fp),r0	# r0 = saved instruction length
 
 	addl2	r0,reg_pc(fp)		# position pc to end of instruction
 	addb2	r0,regmod_pc(fp)	# increment the pc modification count
 	movq	reg_r0(fp),r0		# r0,r1 = first part of result so far
 	movq	reg_r2(fp),r2		# r2,r3 = second part of result so far
 	bsbw	unpack_float2		# unpack and save the value
 	movab	operand2(fp),r1		# r1 = location of operand2
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	movl	reg_sp(fp),r11		# r11 = user's stack pointer
 	prober	mode(fp),$16,(r11)	# can we read a stacked octaword ?
 
 	bneq	1f			# yes - skip
 	movl	$16,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	movq	(r11)+,r0		# r0,r1 = first part of argument
 	movq	(r11),r2		# r2,r3 = second part of argument
 	bsbw	unpack_float3		# unpack and save the value
 	cmpb	$31,r4			# is the iteration count too large ?
 	blssu	2f			# no - skip
 	brw	operand_fault		# processed the reserved operand
 2:	brw	7f			# resume the instruction
 3:	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float3		# unpack and save the value
 	incl	op_index(fp)		# look at second operand
 	bsbw	read_access		# second operand is read only
 	cmpl	$31,r0			# is the value reserved ?
 	bgequ	4f			# no - skip
 	brw	operand_fault		# process the reserved operand
 4:	movl	r0,address1(fp) 	# save the operand value
 	incl	op_index(fp)		# look at third operand
 	bsbw	address_access		# third operand is address only
 	movl	r11,address2(fp)	# save the table address
 	incl	op_index(fp)		# use dummy fourth operand for datatype
 	bsbw	pack_float3		# pack the argument value
 	subl2	$16,reg_sp(fp)		# decrement the user sp
 	subb2	$16,regmod_sp(fp)	# remember the decrement
 	movl	reg_sp(fp),r11		# r11 = user's stack pointer
 	probew	mode(fp),$16,(r11)	# can we stack the argument ?
 
 	bneq	5f			# yes - skip
 	movl	$16,r10			# r10 = size of probe
 	bsbw	write_fault		# process the access violation
 5:	movq	r0,(r11)+		# save first part of argument
 	movq	r2,(r11)		# save second part of argument
 	movl	address2(fp),r11	# r11 = coefficient table address
 	prober	mode(fp),$16,(r11)	# can we read the first octaword ?
 
 	bneq	6f			# yes - skip
 	movl	$16,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 6:	movq	(r11)+,r0		# r0,r1 = first part of coefficient

 	movq	(r11)+,r2		# r2,r3 = second part of coefficient
 	movl	r11,address2(fp)	# save the following address
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	pack_float2		# pack the value again
 	movq	r0,reg_r0(fp)		# save first part of value so far
 	movq	r2,reg_r2(fp)		# save second part of value so far
 	movab	operand2(fp),r1		# r1 = location of operand2
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	bicl2	$pslm_vc,psl(fp)	# clear the v bit and c bit in the psl
 	movl	address1(fp),reg_r4(fp) # save the remaining iteration count
 	movl	address2(fp),reg_r5(fp)	# save the next coefficient address
 	cvtbl	regmod_pc(fp),r0	# r0 = pc register modifications
 	clrq	regmod_r0(fp)		# clear modifications for r0 to r7
 	clrq	regmod_r8(fp)		# clear modifications for r8 to pc
 	movb	r0,regmod_pc(fp)	# put the pc modifications back
 	subl2	$2,r0			# subtract the operation code length
 	insv	r0,$8,$24,reg_r4(fp)	# save the value for resumption
 
 	bbss	$psl_fpd,psl(fp),7f	# indicate first part done in psl
 7:	tstb	reg_r4(fp)		# more iterations to perform ?
 	beql	9f			# no - finish up
 	bsbw	multiply_float		# multiply the result and argument
 	incl	r0			# increment the shift count
 	insv	$0,$0,r0,fraction1(fp)	# truncate the product
 
 	movl	reg_r5(fp),r11		# r11 = location of next table entry
 	prober	mode(fp),$16,(r11)	# can we read the next coefficient ?
 
 	bneq	8f			# yes - skip
 	movl	$16,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 8:	movl	reg_r5(fp),r11		# r11 = location of next table entry
 	movq	(r11)+,r0		# r0,r1 = first part of next entry
 	movq	(r11),r2		# r2,r3 = second part of next entry
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	add_real		# add the coefficient to the product
 	bsbw	pack_float1		# pack the result so far
 	movq	r0,reg_r0(fp)		# save the first part of the value
 	movq	r2,reg_r2(fp)		# save the second part of the value
 	bsbw	unpack_float2		# unpack the result for next iteration
 	bsbw	set_condition1		# set the condition codes in the psl
 	addl2	$16,reg_r5(fp)		# update the table pointer
 	decb	reg_r4(fp)		# decrement the iteration counter
 	brb	7b			# start the next iteration
 9:	clrl	reg_r4(fp)		# clear the user's r4
 	addl2	$16,reg_sp(fp)		# unstack the argument value
 	bbcc	$psl_fpd,psl(fp),0f	# indicate instruction complete
 0:	brw	normal_exit		# done
 
 #
 #	7ffd pushao - push address of octaword
 #
 #	7ffd pushah - push address of h_floating
 #
 inst_pushao:
 	set_op_types	o

 	bsbw	address_access		# first operand is address only
 	subl2	$4,reg_sp(fp)		# decrement the user sp
 	subb2	$4,regmod_sp(fp)	# remember the decrement
 	movl	r11,r0			# r0 = the operand address
 	movl	reg_sp(fp),r11		# r11 = user's stack pointer
 	probew	mode(fp),$4,(r11)	# can we write the operand address ?
 
 	bneq	1f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	write_fault		# process the access violation
 1:	movl	r0,*reg_sp(fp)		# stack the operand address
 	tstl	r0			# test the operand address
 	bsbw	set_condition		# capture the condition code
 	bicl2	$pslm_v,psl(fp) 	# clear the v bit in the psl
 	brw	normal_exit		# done
 
 #
 #	42 subf2 - subtract f_floating (two operands)
 #
 inst_subf2:
 	set_op_types	f
 	brb	inst_subx2
 
 #
 #	62 subd2 - subtract d_floating (two operands)
 #
 inst_subd2:
 	set_op_types	d
 	brb	inst_subx2
 
 #
 #	42fd subg2 - subtract g_floating (two operands)
 #
 inst_subg2:
 	set_op_types	g
 	brb	inst_subx2
 
 #
 #	62fd subh2 - subtract hfloat (two operands)
 #
 inst_subh2:
 	set_op_types	h
 #brb	inst_subx2
 
 inst_subx2:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	bsbw	negate_real		# negate the value
 	bsbw	modify_access		# second operand is modified
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	add_real		# compute the sum
 	bsbw	pack_float1		# pack the value
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done

 
 #
 #	43 subf3 - subtract f_floating (three operands)
 #
 inst_subf3:
 	set_op_types	f
 	brb	inst_subx3
 
 #
 #	63 subd3 - subtract d_floating (three operands)
 #
 inst_subd3:
 	set_op_types	d
 	brb	inst_subx3
 
 #
 #	43fd subg3 - subtract g_floating (three operands)
 #
 inst_subg3:
 	set_op_types	g
 	brb	inst_subx3
 
 #
 #	63fd subh3 - subtract hfloat (three operands)
 #
 inst_subh3:
 	set_op_types	h
 #brb	inst_subx3
 
 inst_subx3:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	bsbw	negate_real		# negate the value
 	bsbw	read_access		# second operand is read only
 	bsbw	unpack_float2		# unpack and save the value
 	bsbw	write_access		# third operand is write only
 	movl	r11,address1(fp)	# save the destination location
 	bsbw	add_real		# compute the sum
 	bsbw	pack_float1		# pack the value
 	movl	address1(fp),r11	# r11 = destination location
 	bsbw	store_operand		# store result
 	bsbw	set_condition1		# set the condition codes in the psl
 	brw	normal_exit		# done
 
 #
 #	53 tstf - test f_floating
 #
 inst_tstf:
 	set_op_types	f
 	brb	inst_tstx
 
 #
 #	73 tstd - test d_floating
 #
 inst_tstd:
 	set_op_types	d
 	brb	inst_tstx

 
 #
 #	53fd tstg - test g_floating
 #
 inst_tstg:
 	set_op_types	g
 	brb	inst_tstx
 
 #
 #	73fd tsth - test hfloat
 #
 inst_tsth:
 	set_op_types	h
 #brb	inst_tstx
 
 inst_tstx:
 	bsbw	read_access		# first operand is read only
 	bsbw	unpack_float1		# unpack and save the value
 	movab	operand1(fp),r1 	# r1 = location of the value
 	bsbw	test_real		# test the value
 	bsbw	set_condition		# set the condition codes
 	bicl2	$pslm_vc,psl(fp)	# clear the v bit and c bit in the psl
 	brw	normal_exit		# done
 #

 #	****************************************************************
 #	*							       *
 #	*							       *
 #	*	    routines for scanning instruction operands	       *
 #	*							       *
 #	*							       *
 #	****************************************************************
 #
 #
 #	introduction
 #	------------
 #
 #	    the following section contains a complex of routines for
 #	scanning the operands of an instruction and determining the
 #	values and locations of operands. the code contains full error
 #	checking and also checks for the situations that the
 #	architecture considers to be unpredictable. in order to make
 #	the operand scanning in the instruction emulation routines 
 #	clear, separate entrys appear for each possible kind of
 #	operand.
 #
 #
 #	operand scanning routines
 #	-------------------------
 #
 #	    the operand scanning routines are entered by subroutine
 #	branching and have entry names of the form
 #
 #		<access type>_<data type>
 #
 #	in which <access type> is any one of the following
 #
 #		read		operand is read only
 #		write		operand is write only
 #		modify		operand is both read and write
 #		address		only the operand address is required
 #		branch		relative branch destintion
 #
 #	and in which <data type> is any one of the following
 #
 #		byte		byte
 #		word		word
 #		long		longword
 #		quad		quadword
 #		octa		octaword
 #		float		f-format floating
 #		dfloat		d-format floating
 #		gfloat		g-format floating
 #		hfloat		h-format floating
 #
 #	for an access type of branch the data type refers to the
 #	size of the relative address rather than the properties of
 #	any addressed information.
 #
 #	    entrys only exist for those types of operands which appear
 #	in the emulated instructions. if additional entrys are 
 #	required they can be added easily enough.

 #
 #	    when the routines are entered they scan the next 
 #	instruction operand starting at the value of the user's pc
 #	and check the operand for validity. if any exceptions are
 #	detected during operand scanning they are processed immediatly
 #	and the routines do not return. any changes that are made to
 #	any of the registers (including pc) are recorded in the change
 #	bytes so faults will be handled properly.
 #
 #	    when the routines return the following rules describe the
 #	contents of the registers:
 #
 #	     o	if the access type is read or modify and the data type
 #		is byte, word, long, or float, then r0 is the value
 #		of the operand. if the data type is byte or word then
 #		the value is sign extended to a longword.
 #
 #	     o	if the access type is read or modify and the data type
 #		is quad, dfloat, or gfloat, then r0-r1 contains the
 #		value of the operand.
 #
 #	     o	if the access type is read or modify and the data type
 #		is octa or hfloat then r0-r3 contains the value of the
 #		operand.
 #
 #	     o	if the access type is write, modify, address, or
 #		branch, then r11 is the address of the operand or the
 #		branch destination.
 #
 #	if the instruction operand specifies register mode, then the
 #	address associated with the operand is the location of the
 #	emulated register. if an instruction operand with write or
 #	modify access addresses the emulator's local storage then it
 #	is changed to an address that won't do any harm. this is 
 #	consistant with the notion that the area below the user's
 #	stack pointer is being continually garbaged. this check is not
 #	performed if flag bit 0 is set. the routines set flag bit 1 if
 #	the operand is a register mode operand.
 #
 #	    the subroutine local_test is available for checking for 
 #	stores into the emulator's local storage in places where this
 #	is not done automatically.
 #
 #
 #	exceptions
 #	----------
 #
 #	    the instruction operand scanning routines perform complete
 #	error checking and immediatly signal any exceptions detected.
 #	all of these exceptions are faults. the change bytes are
 #	constantly kept up to date so the instruction will be left in
 #	a consistant state for restarting if a fault occurs.
 #
 #	    all fetches from memory done in scanning the instruction
 #	operand or in fetching the operand or operand address are 
 #	probed and access violations are signaled if the probes fail.
 #	all of the addressing modes specified by the architecture to

 #	be reserved addressing modes or unpredictable are checked for
 #	and are signaled as reserved addressing modes if they are
 #	detected.
 #
 #
 #	routine organization
 #	--------------------
 #
 #	    except for branch access mode for which there are only
 #	isolated routines, the code at the individual routine 
 #	entrances simply loads the data type code into r9 and branches
 #	to a routine for the access type. this routine in turn loads
 #	the access type code into r8 and branches to the routine 
 #	get_specifier which process the operand specifier byte.
 #
 #	    get_specifier loads the length of the data type into r10
 #	and the operand specifier byte into r0. the high and low 
 #	order nibbles of this byte are stored in r1 and r2. the 
 #	register r7 which is reserved for the index modification is 
 #	cleared. the routine now branches on the high order nibble
 #	to a routine which will handle the specific kind of operand.
 #
 #	    for literals the values are expanded immediatly and the
 #	routine returns.
 #
 #	    for index mode operand specifiers, the index modification
 #	is computed and the next operand specifier byte is loaded into
 #	r0 and decomposed as before. again we branch on the high order
 #	nibble but this time certain addressing modes which are 
 #	illegal with indexing are checked for. also for those 
 #	addressing modes which change register values a check is made
 #	that the register is not the same as the index register.
 #
 #	    for register mode operands the address of the emulated
 #	register is loaded into r11. a check is made that the operand
 #	does not contain pc. then flag bit 1 is set and control passes
 #	to the operand reading routine if the access type is read or
 #	modify and the routine returns otherwise.
 #
 #	    for the remaining addressing modes the operand addresses
 #	are computed in a straightforward manner and loaded into r11.
 #	for some of these addressing modes the values of registers may
 #	be changed. these changes are reflected in the change bytes.
 #	when the operand address is computed control passes to the 
 #	operand accessing routine.
 #	
 #	    for address access mode operands the operand accessing
 #	routine returns but for all others it probes the operand 
 #	address and also checks for writes into the emulator's local
 #	storage unless flag bit 0 is set. if the operand is read or
 #	modify access control passes to the operand reading routine.
 #
 #	    the operand reading routine simply reads the operand 
 #	value into the registers starting at r0 and then returns.
 #	bytes and words are sign extended into longwords. however
 #	this routine does not check for reserved floating values
 #	since this is done by the unpack routines.

 #

 #
 #	process a read only operand
 #
 read_access:				# entrance
 	movl	$type_read,r8		# r8 = access type
 	movzbl	*op_index(fp),r9	# r9 = data type
 	brb	get_specifier		# scan the operand
 #
 #	process a write only operand
 #
 write_access:				# entrance
 	movl	$type_write,r8		# r8 = access type
 	movzbl	*op_index(fp),r9	# r9 = data type
 	brb	get_specifier		# scan the operand
 #
 #	process a modified operand
 #
 modify_access:				# entrance
 	movl	$type_modify,r8 	# r8 = access type
 	movzbl	*op_index(fp),r9	# r9 = data type
 	brb	get_specifier		# scan the operand
 #
 #	process an addressed operand
 #
 address_access: 			# entrance
 	movl	$type_address,r8	# r8 = access type
 	movzbl	*op_index(fp),r9	# r9 = data type
 	brb	get_specifier		# scan the operand
 #
 #	table of data type lengths
 #
 lengths:				# table origin
 	.byte	1			# 1 - byte
 	.byte	2			# 2 - word
 	.byte	4			# 3 - longword
 	.byte	8			# 4 - quadword
 	.byte	16			# 5 - octaword
 	.byte	4			# 6 - f_floating
 	.byte	8			# 7 - d_floating
 	.byte	8			# 8 - g_floating
 	.byte	16			# 9 - h_floating
 #
 #	process the next operand specifier
 #
 get_specifier:				# entrance
 	movzbl	lengths-1[r9],r10	# r10 = data type length
 	clrl	r7			# clear the index value
 	movl	reg_pc(fp),r11		# r11 = specifier byte location
 	prober	mode(fp),$1,(r11)	# can we read the specifier byte ?
 
 	bneq	1f			# yes - skip
 	movl	$1,r10			# r10 = size of probe
 	bsbw	read_fault		# process an access violation
 1:	movzbl	*reg_pc(fp),r0		# r0 = specifier byte
 	incl	reg_pc(fp)		# increment pc
 	incb	regmod_pc(fp)		# remember the incrementation
 	extzv	$4,$4,r0,r1		# r1 = high order nibble of specifier

 
 	extzv	$0,$4,r0,r2		# r2 = low order nibble of specifier
 
 	casel	r1,$0,$15		# branch on the high order nibble
 2:
	.word	literal_mode-2b 	# 0 - literal mode
 	.word	literal_mode-2b 	# 1 - literal mode
 	.word	literal_mode-2b 	# 2 - literal mode
 	.word	literal_mode-2b 	# 3 - literal mode
 	.word	index_mode-2b		# 4 - index mode
 	.word	register_mode-2b	# 5 - register mode
 	.word	reg_def_mode-2b 	# 6 - register deferred mode
 	.word	decr_mode-2b		# 7 - autodecrement mode
 	.word	incr_mode-2b		# 8 - autoincrement mode
 	.word	incr_def_mode-2b	# 9 - autoincrement deferred mode
 	.word	byte_disp_mode-2b	# a - byte displacement mode
 	.word	byte_def_mode-2b	# b - byte displacement deferred mode
 	.word	word_disp_mode-2b	# c - word displacement mode
 	.word	word_def_mode-2b	# d - word displacement deferred mode
 	.word	long_disp_mode-2b	# e - long displacement mode
 	.word	long_def_mode-2b	# f - long displacement deferred mode
 #
 #	process a literal mode operand specifier
 #
 literal_mode:				# entrance
 	casel	r8,$1,$3		# branch on the access type
 1:
	.word	2f-1b			# 1 - read only access
 	.word	address_fault-1b	# 2 - write only access
 	.word	address_fault-1b	# 3 - modify access
 	.word	address_fault-1b	# 4 - address access
 2:	casel	r9,$1,$8		# branch on the data type
 3:
	.word	6f-3b			# 1 - byte
 	.word	6f-3b			# 2 - word
 	.word	6f-3b			# 3 - longword
 	.word	5f-3b			# 4 - quadword
 	.word	4f-3b			# 5 - octaword
 	.word	8f-3b			# 6 - f_floating
 	.word	7f-3b			# 7 - d_floating
 	.word	9f-3b			# 8 - g_floating
 	.word	0f - 3b			# 9 - h_floating
 4:	clrq	r2			# clear second quadword of value
 5:	clrl	r1			# clear second longword of value
 6:	rsb				# return with the literal value
 7:	clrl	r1			# clear second longword of value
 8:	ashl	$4,r0,r0		# position the literal bits
 	bbcs	$14,r0,6b		# include exponent bias and return
 9:	ashl	$1,r0,r0		# position the literal bits
 	bbcs	$14,r0,5b		# include exponent bias and finish up
 0:	rotl	$29,r0,r0		# position the literal bits
 	bbcs	$14,r0,4b		# include exponent bias and finish up
 #
 #	process an index mode operand specifier
 #
 index_mode:				# entrance
 	cmpl	$15,r2			# is the register pc ?
 	bneq	1f			# no - skip
 	brw	address_fault	 	# process the reserved addressing mode
 1:	mull3	r10,reg_r0(fp)[r2],r7	# r7 = index address modification

 
 	movl	r2,r3			# save the register number
 	movl	reg_pc(fp),r11		# r11 = location of next byte
 	prober	mode(fp),$1,(r11)	# can we read the next byte ?
 
 	bneq	2f			# yes - skip
 	movl	$1,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 2:	movzbl	*reg_pc(fp),r0		# r0 = next operand specifier
 	incl	reg_pc(fp)		# increment pc
 	incb	regmod_pc(fp)		# remember the incrementation
 	extzv	$4,$4,r0,r1		# r1 = high order nibble of specifier
 
 	extzv	$0,$4,r0,r2		# r2 = low order nibble of specifier
 
 	casel	r1,$0,$15		# branch on the low order nibble
 3:
	.word	address_fault-3b	# 0 - literal mode
 	.word	address_fault-3b	# 1 - literal mode
 	.word	address_fault-3b	# 2 - literal mode
 	.word	address_fault-3b	# 3 - literal mode
 	.word	address_fault-3b	# 4 - index mode
 	.word	address_fault-3b	# 5 - register mode
 	.word	reg_def_mode-3b 	# 6 - register deferred mode
 	.word	4f-3b			# 7 - autodecrement mode
 	.word	4f-3b			# 8 - autoincrement mode
 	.word	4f-3b			# 9 - autoincrement deferred mode
 	.word	byte_disp_mode-3b	# a - byte displacement mode
 	.word	byte_def_mode-3b	# b - byte displacement deferred mode
 	.word	word_disp_mode-3b	# c - word displacement mode
 	.word	word_def_mode-3b	# d - word displacement deferred mode
 	.word	long_disp_mode-3b	# e - long displacement mode
 	.word	long_def_mode-3b	# f - long displacement deferred mode
 4:	cmpl	r2,r3			# is register the same as index ?
 	bneq	5f			# no - skip
 	brw	address_fault	 	# process the reserved addressing mode
 5:	casel	r1,$7,$2		# branch on the high order nibble
 6:
	.word	decr_mode-6b		# 7 - autodecrement mode
 	.word	incr_mode-6b		# 8 - autoincrement mode
 	.word	incr_def_mode-6b	# 9 - autoincrement deferred mode
 #
 #	process a register mode operand specifier
 #
 register_mode:				# entrance
 	bisb2	$flag1m,flags(fp)	# indicate a register mode operand
 	moval	(r10)[r2],r3		# byte position following operand
 	cmpl	$60,r3			# does the operand overlap pc ?
 	bgeq	1f			# no - skip
 	brw	address_fault	 	# process the reserved addressing mode
 1:	moval	reg_r0(fp)[r2],r11	# r11 = location of user register
 	casel	r8,$1,$3		# branch on the access type
 2:
	.word	read_value-2b		# 1 - read only access
 	.word	3f-2b			# 2 - write access
 	.word	read_value-2b		# 3 - modify access
 	.word	address_fault-2b	# 4 - address access
 3:	rsb				# return with the register address
 #
 #	process a register deferred mode operand specifier

 #
 reg_def_mode:				# entrance
 	cmpl	$15,r2			# is the register pc ?
 	bgtr	1f			# no - skip
 	brw	address_fault 		# process the reserved addressing mode
 1:	addl3	r7,reg_r0(fp)[r2],r11	# form the operand address
 
 	brw	access_value		# finish establishing the access
 #
 #	process an autodecrement mode operand specifier
 #
 decr_mode:				# entrance
 	cmpl	$15,r2			# is the register pc ?
 	bgtr	1f			# no - skip
 	brw	address_fault	 	# process the reserved addressing mode
 1:	subl2	r10,reg_r0(fp)[r2]	# subtract data size from register
 	subb2	r10,regmod_r0(fp)[r2]	# remember the subtraction
 	addl3	r7,reg_r0(fp)[r2],r11	# form the operand address
 
 	brw	access_value		# finish establishing the access
 #
 #	process an autoincrement mode operand specifier
 #
 incr_mode:				# entrance
 	cmpl	$15,r2			# is the register pc ?
 	bgtr	2f			# no - bypass
 	casel	r8,$1,$3		# branch on the access type
 1:
	.word	2f-1b			# 1 - read only access
 	.word	address_fault-1b	# 2 - write only access
 	.word	address_fault-1b	# 3 - modify access
 	.word	2f-1b			# 4 - address access
 2:	addl3	r7,reg_r0(fp)[r2],r11	# form the operand address
 
 	addl2	r10,reg_r0(fp)[r2]	# add the data size to the register
 	addb2	r10,regmod_r0(fp)[r2]	# remember the addition
 	brw	access_value		# finish establishing the access
 #
 #	process an autoincrement deferred mode operand specifier
 #
 incr_def_mode:				# entrance
 	movl	reg_r0(fp)[r2],r11	# r11 = register value
 	prober	mode(fp),$4,(r11)	# can we read longword it addresses ?
 
 	bneq	1f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	addl3	r7,(r11),r11		# form the operand address
 	addl2	$4,reg_r0(fp)[r2]	# add longword size to the register
 	addb2	$4,regmod_r0(fp)[r2]	# remember the incrementation
 	brw	access_value		# finish establishing the access
 #
 #	process a byte displacement mode operand specifier
 #
 byte_disp_mode: 			# entrance
 	movl	reg_pc(fp),r11		# r11 = location of displacement
 	prober	mode(fp),$1,(r11)	# can we read the displacement ?
 

 	bneq	1f			# yes - skip
 	movl	$1,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	cvtbl	(r11),r11		# r11 = displacement value
 	incl	reg_pc(fp)		# increment pc
 	incl	regmod_pc(fp)		# remember the increment
 	addl2	r7,r11			# add the displacement to the index
 	addl2	reg_r0(fp)[r2],r11	# add the register to the result
 	brw	access_value		# finish establishing the access
 #
 #	process a byte displacement deferred mode operand specifier
 #
 byte_def_mode:				# entrance
 	movl	reg_pc(fp),r11		# r11 = location of displacement
 	prober	mode(fp),$1,(r11)	# can we read the displacement ?
 
 	bneq	1f			# yes - skip
 	movl	$1,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	cvtbl	(r11),r11		# r11 = displacement value
 	incl	reg_pc(fp)		# increment pc
 	incb	regmod_pc(fp)		# remember the increment
 	addl2	reg_r0(fp)[r2],r11	# add the register to the displacement
 	prober	mode(fp),$4,(r11)	# can we read longword it addresses ?
 
 	bneq	2f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access fault
 2:	addl3	r7,(r11),r11		# form the operand address
 	brw	access_value		# finish establishing the access
 #
 #	process a word displacement mode operand specifier
 #
 word_disp_mode: 			# entrance
 	movl	reg_pc(fp),r11		# r11 = location of the displacement
 	prober	mode(fp),$2,(r11)	# can we read the displacement
 
 	bneq	1f			# yes - skip
 	movl	$2,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	cvtwl	(r11),r11		# r11 = displacement value
 	addl2	$2,reg_pc(fp)		# increment pc
 	addb2	$2,regmod_pc(fp)	# remember the increment
 	addl2	r7,r11			# add the index to the displacement
 	addl2	reg_r0(fp)[r2],r11	# add the register to the result
 	brw	access_value		# finish establishing the access
 #
 #	process a word displacement deferred mode operand specifier
 #
 word_def_mode:				# entrance
 	movl	reg_pc(fp),r11		# r11 = location of the displacement
 	prober	mode(fp),$2,(r11)	# can we read the displacement ?
 
 	bneq	1f			# yes - skip
 	movl	$2,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	cvtwl	(r11),r11		# r11 = displacement value

 	addl2	$2,reg_pc(fp)		# increment pc
 	addb2	$2,regmod_pc(fp)	# remember the increment
 	addl2	reg_r0(fp)[r2],r11	# add the register to the displacement
 	prober	mode(fp),$4,(r11)	# can we read longword it addresses ?
 
 	bneq	2f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 2:	addl3	r7,(r11),r11		# form the operand address
 	brw	access_value		# finish establishing the access
 #
 #	process a long displacement mode operand specifier
 #
 long_disp_mode: 			# entrance
 	movl	reg_pc(fp),r11		# r11 = location of the displacement
 	prober	mode(fp),$4,(r11)	# can we read the displacement ?
 
 	bneq	1f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	movl	(r11),r11		# r11 = displacement value
 	addl2	$4,reg_pc(fp)		# increment pc
 	addb2	$4,regmod_pc(fp)	# remember the increment
 	addl2	r7,r11			# add the index to the displacement
 	addl2	reg_r0(fp)[r2],r11	# add the register to the address
 	brw	access_value		# finish establishing the access
 #
 #	process a long displacement deferred mode operand specifier
 #
 long_def_mode:				# entrance
 	movl	reg_pc(fp),r11		# r11 = location of the displacement
 	prober	mode(fp),$4,(r11)	# can we read the displacement ?
 
 	bneq	1f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	movl	(r11),r11		# r11 = displacement value
 	addl2	$4,reg_pc(fp)		# increment pc
 	addb2	$4,regmod_pc(fp)	# remember the increment
 	addl2	reg_r0(fp)[r2],r11	# add the register to the displacement
 	prober	mode(fp),$4,(r11)	# can we read longword it addresses ?
 
 	bneq	2f			# yes - skip
 	movl	$4,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 2:	addl3	r7,(r11),r11		# form the operand address
 	brw	access_value		# finish establishing the access
 #
 #	set up the type of access requested
 #
 access_value:				# entrance
 	casel	r8,$1,$3		# branch on the access type
 1:
	.word	read_check-1b		# 1 - read only access
 	.word	write_check-1b		# 2 - write only access
 	.word	modify_check-1b 	# 3 - modify access
 	.word	2f-1b			# 4 - address access
 2:	rsb				# return with the operand address

 #
 #	perform error checking for modify access operands
 #
 modify_check:				# entrance
 	bsbb	write_check		# check write (and read) access
 	brb	read_value		# load the value
 #
 #	perform error checking for read only access operands
 #
 read_check:				# entrance
 	prober	mode(fp),r10,(r11)	# can we read the operand ?
 
 	bneq	1f			# yes - load the value
 	bsbw	read_fault		# process the access violation
 1:	brb	read_value		# load the value
 #
 #	perform error checking for write only access operands
 #
 write_check:				# entrance
 	probew	mode(fp),r10,(r11)	# can we write the operand ?
 
 	bneq	1f			# yes - bypass
 	bsbw	write_fault		# process the access violation
 	bbs	$flag0,flags(fp),1f	# no local store checking - skip
 	bsbw	local_test		# test for a write into local storage
 1:	rsb				# return
 #
 #	load a read operand into the registers
 #
 read_value:				# entrance
 	casel	r9,$1,$8		# branch on the data type
 1:
	.word	2f-1b			# 1 - byte
 	.word	3f-1b			# 2 - word
 	.word	4f-1b			# 3 - longword
 	.word	6f-1b			# 4 - quadword
 	.word	5f-1b			# 5 - octaword
 	.word	4f-1b			# 6 - f_floating
 	.word	6f-1b			# 7 - d_floating
 	.word	6f-1b			# 8 - g_floating
 	.word	5f-1b			# 9 - h_floating
 2:	cvtbl	(r11),r0		# r0 = operand value
 	rsb				# return
 3:	cvtwl	(r11),r0		# r0 = operand value
 	rsb				# return
 4:	movl	(r11),r0		# r0 = operand value
 	rsb				# return
 5:	movq	8(r11),r2		# r2,r3 = high order quadword of value
 6:	movq	(r11),r0		# r0,r1 = low order quadword of value
 	rsb				# return
 #
 #	process a word branch displacement operand
 #
 branch_word:				# entrance
 	movl	reg_pc(fp),r11		# r11 = location of the displacement
 	prober	mode(fp),$2,(r11)	# can we read the displacement ?
 
 	bneq	1f			# yes - skip

 	movl	$2,r10			# r10 = size of probe
 	bsbw	read_fault		# process the access violation
 1:	cvtwl	(r11),r11		# r11 = branch displacement
 	addl2	$2,reg_pc(fp)		# increment pc
 	addb2	$2,regmod_pc(fp)	# remember the increment
 	addl2	reg_pc(fp),r11		# compute the branch destination
 	rsb				# return
 #
 #	test for a write into local storage
 #
 #		entered by subroutine branching
 #
 #		parameters:	r10 = number of bytes to be written
 #				r11 = distination address
 #
 #		returns with	r11 = corrected destination address
 #
 #	discussion
 #	
 #	    this routine checks the write operation described by
 #	the parameters in r10 and r11 for a write into the emulator's
 #	working storage. if such a write is about to take place, r11
 #	is changed to an address where the write will not do any harm.
 #
 local_test:				# entrance
 	movab	local_end(fp),r3	# r3 = byte following local storage
 	cmpl	r11,r3			# is the write above the frame ?
 	bgequ	1f			# yes - bypass
 	addl3	r10,r11,r3		# r3 = byte following operand
 	cmpl	r3,sp			# is it above the stack pointer ?
 	blequ	1f			# no - operand is not in local storage
 	movab	temp(fp),r11		# redirect the write to temp
 1:	rsb				# return with the operand address
 #

 #	****************************************************************
 #	*							       *
 #	*							       *
 #	*       routines for unpacking and packing floating values     *
 #	*							       *
 #	*							       *
 #	****************************************************************
 #
 #
 #	introduction
 #	------------
 #
 #	    the following routines perform all of the conversions
 #	between the vax floating representations and the internal 
 #	representation used by the emulator. the unpack routines
 #	convert from the vax representation to the internal 
 #	representation and the pack routines perform the opposite
 #	conversion. these routines perform all of the necessary
 #	rounding and check for reserved values, underflow, and 
 #	overflow.
 #
 #
 #	the unpack routines
 #	-------------------
 #
 #	    the unpack routines convert a value in one of the vax
 #	floating representations to our internal representation.
 #	the value to be converted is assumed to be contained in
 #	the registers starting at r0. for floating and double 
 #	floating values the available unpack routines only place
 #	the converted value in operand1. for gfloat and hfloat routines
 #	are available which place the result in all of the operand
 #	areas.
 #
 #	    the unpack routines all check for a reserved floating
 #	value (sign bit set and biased exponent equal to zero) and
 #	signal a reserved operand exception if one is found.
 #
 #
 #	the pack routines
 #	-----------------
 #
 #	    the pack routines convert a value in the internal 
 #	representation to one of the vax floating representations.
 #	the value to be converted is assumed to be in one of the
 #	operand areas and the value must be in operand1 if the value
 #	is to be converted to floating or double floating. for gfloat
 #	and hfloat routines are available to convert from each of the
 #	operand areas. the routines always leave the result in the
 #	registers starting at r0.
 #
 #	    before the value is converted the rounding bit (the first
 #	bit of the fraction which will not appear in the converted
 #	result) is tested and if it is set the value is rounded by
 #	adding one to the next higher bit (the lowest one that will
 #	appear in the converted result) and processing any carries
 #	that occur. when the conversion is performed the biased

 #	exponent is checked for possible overflow or underflow. if an 
 #	overflow condition is detected, then the condition is
 #	signaled. if an underflow condition is detected, then the
 #	condition is signaled only if the fu bit is set in the user's
 #	psl. if the bit is not set then a value of zero is returned.
 #	if a nonzero value is converted to zero because of underflow,
 #	the source value in operand area will be marked as zero so
 #	condition code determination will still work properly.
 #

 #
 #	unpack_float1 - unpack a floating value to operand1
 #
 unpack_float1:
 	movab	operand1(fp), r4	# operand area address
 	brb	unpack_float
 
 #
 #	unpack_float2 - unpack a floating value to operand2
 #
 unpack_float2:
 	movab	operand2(fp), r4	# operand area address
 	brb	unpack_float
 
 #
 #	unpack_float3 - unpack a floating value to operand3
 #
 unpack_float3:
 	movab	operand3(fp), r4	# operand area address
 #brb	unpack_float
 
 unpack_float:
 	caseb	*op_index(fp),$typ_f,$(typ_h-typ_f)	# 003
 
 1:
	.word	unpack_ffloat-1b	# 6 - f_floating
 	.word	unpack_dfloat-1b	# 7 - d_floating
 	.word	unpack_gfloat-1b	# 8 - g_floating
 	.word	unpack_hfloat-1b	# 9 - h_floating

 #
 #	unpack_ffloat - unpack a floating value 
 #
 #		entered by subroutine branching
 #
 #		parameter:	r0 = input floating value
 #
 #		returns with	(r4) = converted value
 #
 #		uses r0-r5
 #
 unpack_ffloat:				# entrance
 	clrl	r1			# make f look like d
 #brb	unpack_dfloat		; use d_floating unpack
 #

 #
 #	unpack_dfloat - unpack a double floating value 
 #
 #		entered by subroutine branching
 #
 #		parameter:	r0,r1 = input double floating value
 #
 #		returns with	(r4) = converted value
 #
 #		uses r0-r5
 #
 unpack_dfloat:				# entrance
 	clrl	(r4)			# clear the zero and sign flags
 	extzv	$7,$8,r0,r5		# r5 = biased exponent
 
 	bneq	2f			# it's not zero - bypass
 	bbc	$15,r0,1f		# no sign bit - skip
 	brw	operand_fault		# double floating value is reserved
 1:	incb	zero(r4)		# indicate a zero value
 	rsb				# return
 2:	bbc	$15,r0,3f		# no sign bit - skip
 	incb	sign(r4)		# indicate a negative value
 3:	movab	-128(r5),power(r4)	# store the unbiased exponent
 	rotl	$16,r0,r0		# r0 = leading bits of the fraction
 	bbss	$23,r0,4f		# set the hidden bit
 4:	insv	r0,$8,$24,fraction+12(r4)# store bits 40-63 of the fraction
 
 	rotl	$16,r1,r1		# r1 = trailing bits of the fraction
 	movl	r1,fraction+9(r4)	# store bits 8-39 of the fraction
 	clrb	fraction+8(r4)	 	# clear bits 0-7 of the fraction
 	clrq	fraction(r4)		# extend the fraction to 128 bits
 	rsb				# return
 #

 #
 #	unpack_gfloat- unpack a g_floating floating value 
 #
 #		entered by subroutine branching
 #
 #		parameter:	r0,r1 = input g_floating floating value
 #
 #		returns with 	(r4) = converted value
 #
 #		uses r0-r5
 #
 unpack_gfloat:				# entrance
 	clrl	(r4)			# clear the zero and sign flags
 	extzv	$4,$11,r0,r5		# r5 = biased exponent
 
 	bneq	2f			# it's not zero - bypass
 	bbc	$15,r0,1f		# no sign bit - skip
 	brw	operand_fault		# g_floating floating value is reserved
 1:	incb	zero(r4)		# indicate a zero value
 	rsb				# return
 2:	bbc	$15,r0,3f		# no sign bit - skip
 	incb	sign(r4)		# indicate a negative value
 3:	movab	-1024(r5),power(r4)	# store the unbiased exponent
 
 	rotl	$16,r0,r0		# r0 = leading bits of the fraction
 	bbss	$20,r0,4f		# set the hidden bit
 4:	insv	r0,$11,$21,fraction+12(r4)# store bits 43-63 of the fraction
 
 	rotl	$16,r1,r1		# r1 = trailing bits of the fraction
 	insv	r1,$11,$32,fraction+8(r4)# store bits 11-42 of the fraction
 
 	insv	$0,$0,$11,fraction+8(r4)# clear bits 0-10 of the fraction
 
 	clrq	fraction(r4)		# extend the fraction to 128 bits
 	rsb				# return
 #

 #
 #	unpack_hfloat - unpack a hfloat floating value 
 #
 #		entered by subroutine branching
 #	
 #		parameter:	r0,r1,r2,r3 = input hfloat value
 #
 #		returns with	(r4) = converted value
 #
 #		uses r0-r5
 #
 #
 unpack_hfloat:				# entrance
 	clrl	(r4)			# clear the zero and sign flags
 	extzv	$0,$15,r0,r5		# r5 = biased exponent
 
 	bneq	2f			# it's not zero - bypass
 	bbc	$15,r0,1f		# no sign bit - skip
 	brw	operand_fault		# hfloat floating value is reserved
 1:	incb	zero(r4)		# indicate a zero value
 	rsb				# return
 2:	bbc	$15,r0,3f		# no sign bit - skip
 	incb	sign(r4)		# indicate a negative value
 3:	movab	-16384(r5),power(r4)	# store the unbiased exponent
 
 	rotl	$16,r0,r0		# r0 = leading bits of the fraction
 	bbss	$16,r0,4f		# set the hidden bit
 4:	insv	r0,$15,$17,fraction+12(r4)# store bits 111-127 of the fraction
 
 	rotl	$16,r1,r1		# r1 = next bits of the fraction
 	insv	r1,$15,$32,fraction+8(r4)# store bits 79-110 of the fraction
 
 	rotl	$16,r2,r2		# r2 = next bits of the fraction
 	insv	r2,$15,$32,fraction+4(r4)# store bits 47-78 of the fraction
 
 	rotl	$16,r3,r3		# r3 = next bits of the fraction
 	insv	r3,$15,$32,fraction(r4) # store bits 15-46 of the fraction
 
 	insv	$0,$0,$15,fraction(r4)	# clear bits 0-14 of the fraction
 
 	rsb				# return
 #

 #
 #	pack_float1 - pack a floating value to operand1
 #
 pack_float1:
 	movab	operand1(fp), r4	# operand area address
 	brb	pack_float
 
 #
 #	pack_float2 - pack a floating value to operand2
 #
 pack_float2:
 	movab	operand2(fp), r4	# operand area address
 	brb	pack_float
 
 #
 #	pack_float3 - pack a floating value to operand3
 #
 pack_float3:
 	movab	operand3(fp), r4	# operand area address
 #brb	pack_float
 
 pack_float:
 	caseb	*op_index(fp),$typ_f,$(typ_h-typ_f)
 1:
	.word	pack_ffloat-1b		# 6 - f_floating
 	.word	pack_dfloat-1b		# 7 - d_floating
 	.word	pack_gfloat-1b		# 8 - g_floating
 	.word	pack_hfloat-1b		# 9 - h_floating
 

 #
 #	pack_ffloat - pack an f_floating value 
 #
 #		entered by subroutine branching
 #
 #		parameter:	(r4) = source value
 #
 #		returns with	r0 = converted floating value
 #
 pack_ffloat:				# entrance
 	blbc	zero(r4),2f		# value is not zero - bypass
 1:	clrl	r0			# clear the value
 	rsb				# return
 2:	bbc	$7,fraction+12(r4),3f	# rounding bit is zero - bypass
 	addl2	$1<<8,fraction+12(r4)	# round the value
 
 	bcc	3f			# no carry out of fraction - bypass
 	incl	power(r4)		# increment the exponent
 	clrl	r0			# clear the fraction bits
 	brb	4f			# bypass
 3:	rotl	$8,fraction+12(r4),r0	# load the fraction
 
 4:	addl3	$128,power(r4),r1	# r1 = biased exponent
 
 	bgtr	5f			# it's greater than zero - bypass
 	movl	$1,(r4) 		# mark the original value as zero
 	bbc	$psl_fu,psl(fp),1b	# no fault enabled - return zero
 	brw	underflow		# process the floating underflow
 5:	cmpl	$255,r1 		# is the exponent too large ?
 
 	bgeq	6f			# no - skip
 	brw	overflow		# process the floating overflow
 6:	insv	r1,$7,$9,r0		# insert exponent and clear sign
 
 	blbc	sign(r4),7f		# is the value negative ?
 	bbss	$15,r0,7f		# yes - set the sign bit
 7:	rsb				# return
 #

 #
 #	pack_dfloat - pack a d_floating value 
 #
 #		entered by subroutine branching
 #
 #		parameter:	(r4)= source value
 #
 #		returns with	r0,r1 = converted double value
 #
 pack_dfloat:				# entrance
 	blbc	zero(r4),2f		# value is not zero - bypass
 1:	clrq	r0			# clear the value
 	rsb				# return
 2:	bbc	$7,fraction+8(r4),3f	# rounding bit is zero - bypass
 	addl2	$1<<8,fraction+8(r4)	# round the value
 
 	adwc	$0,fraction+12(r4)	# propagate any carry
 	bcc	3f			# no carry out of fraction - bypass
 	incl	power(r4)		# increment the exponent
 	clrq	r0			# clear the fraction bits
 	brb	4f			# bypass
 3:	rotl	$8,fraction+12(r4),r0	# load the first part of the fraction
 
 	rotl	$16,fraction+9(r4),r1	# load the second part of the fraction
 
 4:	addl3	$128,power(r4),r2	# r2 = biased exponent
 
 	bgtr	5f			# it's greater than zero - bypass
 	movl	$1,(r4)		 	# mark the original value as zero
 	bbc	$psl_fu,psl(fp),1b	# no fault enabled - return zero
 	brw	underflow		# process the floating underflow
 5:	cmpl	$255,r2 		# is the exponent too large ?
 
 	bgeq	6f			# no - skip
 	brw	overflow		# process the floating overflow
 6:	insv	r2,$7,$9,r0		# insert exponent and clear sign
 
 	blbc	sign(r4),7f		# is the value negative ?
 	bbss	$15,r0,7f		# yes - set the sign bit
 7:	rsb				# return
 #

 #
 #	pack_gfloat - pack a g_floating value
 #
 #		entered by subroutine branching
 #
 #		parameter:	r4 = location of source value
 #
 #		returns with 	r0,r1 = converted g_floating value
 #
 pack_gfloat:				# entrance
 	blbc	zero(r4),2f		# value is not zero - bypass
 1:	clrq	r0			# clear the value
 	rsb				# return
 2:	bbc	$10,fraction+8(r4),3f	# rounding bit is zero - bypass
 	addl2	$1<<11,fraction+8(r4)	# round the value
 
 	adwc	$0,fraction+12(r4)	# propagate any carry
 	bcc	3f			# no carry out of fraction - bypass
 	incl	power(r4)		# increment the exponent
 	clrq	r0			# clear the fraction bits
 	brb	4f			# bypass
 3:	rotl	$5,fraction+12(r4),r0	# load the first part of the fraction
 
 	extv	$11,$32,fraction+8(r4),r1 # load second part of the fraction
 
 	rotl	$16,r1,r1		# unscramble the bits
 4:	addl3	$1024,power(r4),r3	# r3 = biased exponent
 
 	bgtr	5f			# it's greater than zero - bypass
 	movl	$1,(r4) 		# mark the original value as zero
 	bbc	$psl_fu,psl(fp),1b	# no fault enabled - return zero
 	brw	underflow		# process the floating underflow
 5:	cmpl	$2047,r3		# is the exponent too large ?
 
 	bgeq	6f			# no - skip
 	brw	overflow		# process the floating overflow
 6:	insv	r3,$4,$12,r0		# insert exponent and clear sign
 
 	blbc	sign(r4),7f		# is the value negative ?
 	bbss	$15,r0,7f		# yes - set the sign bit
 7:	rsb				# return
 #

 #
 #	pack_hfloat - pack an h_floating value
 #
 #		entered by subroutine branching
 #
 #		parameter:	r4 = location of source value
 #
 #		returns with	r0,r1,r2,r3 = converted hfloat value
 #
 pack_hfloat:				# entrance
 	blbc	zero(r4),2f		# value is not zero - bypass
 1:	clrq	r0			# clear the first part of the value
 	clrq	r2			# clear the second part of the value
 	rsb				# return
 2:	bbc	$14,fraction(r4),3f	# rounding bit is zero - bypass
 	addl2	$1<<15,fraction(r4)	# round the value
 
 	adwc	$0,fraction+4(r4)	# propagate carry into third part
 	adwc	$0,fraction+8(r4)	# propagate carry into second part
 	adwc	$0,fraction+12(r4)	# propagate carry into first part
 	bcc	3f			# no carry out of fraction - bypass
 	incl	power(r4)		# increment the exponent
 	clrq	r0			# clear first part of the fraction
 	clrq	r2			# clear second part of the fraction
 	brb	4f			# bypass
 3:	ashl	$1,fraction+12(r4),r0	# load first part of the fraction
 
 	extv	$15,$32,fraction+8(r4),r1 # load second part of the fraction
 
 	rotl	$16,r1,r1		# reverse the words
 	extv	$15,$32,fraction+4(r4),r2 # load third part of the fraction
 
 	rotl	$16,r2,r2		# reverse the words
 	extv	$15,$32,fraction(r4),r3 # load	third part of the fraction
 
 	rotl	$16,r3,r3		# reverse the words
 4:	addl3	$16384,power(r4),r5	# r5 = biased exponent
 
 	bgtr	5f			# it's greater than zero - bypass
 	movl	$1,(r4) 		# mark the original value as zero
 	bbc	$psl_fu,psl(fp),1b	# no fault enabled - return zero
 	brw	underflow		# process the floating underflow
 5:	cmpl	$32767,r5		# is the exponent too large ?
 
 	bgeq	6f			# no - skip
 	brw	overflow		# process the floating overflow
 6:	movw	r5,r0			# insert exponent and clear sign
 	blbc	sign(r4),7f		# is the value negative ?
 	bbss	$15,r0,7f		# yes - set the sign bit
 7:	rsb				# return
 #

  
 #
 #	store_operand - move result to destination
 #
 #	entered by bsbw
 #
 #	arguments:	r0-r3 contain operand to store
 #			r11 contains address of destination
 #			op_index(fp) contains pointer to type code
 #
 
 store_operand:
 	caseb	*op_index(fp),$typ_b,$(typ_h-typ_b)
 1:
	.word	2f-1b			# 1 - byte
 	.word	3f-1b			# 2 - word
 	.word	4f-1b			# 3 - longword
 	.word	6f-1b			# 4 - quadword
 	.word	5f-1b			# 5 - octaword
 	.word	4f-1b			# 6 - f_floating
 	.word	6f-1b			# 7 - d_floating
 	.word	6f-1b			# 8 - g_floating
 	.word	5f-1b			# 9 - h_floating
 
 2:	movb	r0,(r11)		# byte
 	rsb				# 
 3:	movw	r0,(r11)		# word
 	rsb				# 
 4:	movl	r0,(r11)		# longword
 	rsb				# 
 5:	movq	r2,8(r11)		# octaword
 6:	movq	r0,(r11)		# quadword
 	rsb				# 
 	

	#	****************************************************************
	#	*							       *
 #	*							       *
 #	*		      arithmetic routines		       *
 #	*							       *
 #	*							       *
 #	****************************************************************
 #
 #
 #	introduction
 #	------------
 #
 #	    the routines which follow perform the actual floating
 #	arithmetic operations of the emulator. these routines all
 #	work with the internal floating representation so only one
 #	routine is needed for each type of operation. however, since
 #	multiplication and division are comparatively slow operations
 #	separate routines have been included for the gfloat and hfloat
 #	versions of these operations so the gfloat operation will not
 #	be slowed to the speed of the hfloat operation.
 #
 #	    the algorithms for the individual routines will be
 #	described in the routines themselves. the following discussion
 #	will be limited to a description of our internal floating 
 #	format.
 #
 #
 #	internal floating representation
 #	--------------------------------
 #
 #	    all of the floating arithmetic operations used by the 
 #	emulator are performed using an internal floating format
 #	which is much easier to work with than any of the hardware
 #	floating representations and which is sufficiently accurate
 #	to represent all of the hardware representations. the format
 #	is also used as an intermediate representation for emulating
 #	the conversion instructions.
 #
 #	    the internal representation has the following four fields:
 #
 #
 #		zero		is a one byte field whose low order
 #				bit indicates that the represented
 #				value is nonzero.
 #
 #		sign		is a one byte field whose low order
 #				bit indicates that the represented
 #				value is negative. if the low order
 #				bit of zero is set then this field
 #				must be zero.
 #
 #		power		is a longword field which contains the
 #				exponent of the power of two which
 #				is used to scale the fraction
 #
 #		fraction	is a 128 bit field (four longwords)
 #				which hold the fraction as a single

 #				128 bit value. the decimal point is
 #				assumed to be at the end of the 
 #				fraction next to the high order bit.
 #				the fraction is considered to be a
 #				a positive value and is normalized
 #				if the high order bit is one.
 #
 #
 #	three areas operand1, operand2, operand3 are available for
 #	holding values in the internal representation. the name of
 #	of a field of one of these areas is found by appending the
 #	trailing digit of the area name to the field name. thus
 #	power2 is the power field of operand2.
 #

 #
 #	negate_real - negate a real value
 #
 #		entered by subroutine branching
 #
 #		parameter:	operand1 = the floating value
 #
 #		returns with 	operand1 = the negated result
 #
 #	discussion
 #	
 #	    if the value is nonzero, then the sign of the value
 #	is complemented.
 #
 negate_real:				# entrance
 	blbs	zero1(fp),1f		# don't negate zero
 	xorb2	$1,sign1(fp)		# complement the sign
 1:	rsb				# return
 #
 #	float_long - convert a longword to a floating value
 #
 #		entered by subroutine branching
 #
 #		parameter:	r0 = the longword value
 #
 #		returns with	operand1 = the converted value
 #
 #	discussion
 #
 #	    the longword is converted to double floating using the
 #	hardware and then to the internal representation by one of
 #	the unpack routines.
 #
 float_long:				# entrance
 #*
 # the original code used cvtld, which we can no longer assume is supported
 # in hardware.  the action of a cvtld r0,r0 is therefore emulated using
 # non-floating instructions.
 #
 #	cvtld	r0,r0			; convert the value to double floating
 #*
 	movl	$(128+32),r2		# set initial biased exponent
 
 	clrl	r1			# zero "low" longword
 	tstl	r0			# test sign of value
 	beql	3f			# skip if zero
 	bgtr	2f			# skip if positive
 	mnegl	r0,r0			# get |r0|
 	bisw2	$0x100,r2		# remember that it is negative
 2:	decl	r2			# decrement binary exponent
 	ashl	$1,r0,r0		# shift value left one bit
 	bvc	2b			# repeat until bit 31 set
 	rotl	$8,r0,r0		# rearrange into floating format
 	bicw3	$0x00ff,r0,r1		# move low 8 bits into place in r1
 
 	insv	r2,$7,$9,r0		# move sign+exponent into place
 

 3:	movab	operand1(fp),r4		# set operand address
 	bsbw	unpack_dfloat		# unpack the value
 	rsb				# return
 #
 

 #
 #	fix_real - convert a floating value to a longword (truncated)
 #
 #		entered by subroutine branching
 #
 #		parameter:	operand1 = the floating value
 #
 #		returns with	r0 = longword result
 #
 #	discussion
 #
 #	    the exponent is used to determine where in the fraction
 #	the decimal point lies and any part of the integer part that
 #	exists within the signed fraction is extracted. if the
 #	fraction contains bits of higher order than those extracted,
 #	then the v bit is set in the user's psl to indicate an integer
 #	overflow.
 #
 fix_real:				# entrance
 	clrl	r0			# clear the returned value
 	blbs	zero1(fp),2f		# the value is zero - return
 	mnegl	power1(fp),r1		# r1 = negated exponent
 	bgeq	2f			# value is less than one - return
 	cmpl	$32,power1(fp)		# is the decimal point deep inside ?
 	blss	3f			# yes - bypass
 	extzv	r1,power1(fp),fraction1+16(fp),r0 # extract leading bits
 
 	blbc	sign1(fp),1f		# the value is positive - skip
 	mnegl	r0,r0			# negate the value
 1:	rotl	$1,r0,r1		# position the sign bit
 	xorb2	sign1(fp),r1		# complement it if negative value
 	blbc	r1,2f			# the sign is correct - skip
 	bisl2	$pslm_v,psl(fp) 	# indicate an integer overflow
 2:	rsb				# return
 3:	bisl2	$pslm_v,psl(fp) 	# indicate an integer overflow
 	movab	160(r1),r1		# switch origin to previous longword
 	bleq	2b			# no nonzero bits - return
 	extzv	r1,$32,fraction1-4(fp),r0 # extract 32 bits from the fraction
 
 	subl3	r1,$32,r1		# compute the bits to clear
 	bleq	4f			# no bits to clear - bypass
 	insv	$0,$0,r1,r0		# clear some low order bits
 
 4:	blbc	sign1(fp),2b		# the value is positive - return
 	mnegl	r0,r0			# complement the extracted bits
 	rsb				# return
 #

 #
 #	round_real - convert a floating value to a longword (rounded)
 #
 #		entered by subroutine branching
 #
 #		parameter:	operand1 = the floating value
 #
 #		returns with	r0 = the longword result
 #
 #	discussion
 #
 #	    the exponent of the floating value is used to determine
 #	where the decimal point goes within the signed fraction and
 #	whatever part of the integer part exists within the fraction
 #	is extracted. if the bit immediatly below the decimal point is
 #	nonzero, then the integer part is rounded by adding a value
 #	of one with the same sign as the floating value. if the value
 #	contains significant bits of higher order than those in the
 #	fraction or if overflow occured during the rounding operation
 #	then the v bit is set in the user's psl to indicate an integer
 #	overflow.
 #
 round_real:				# entrance
 	clrl	r0			# clear the returned value
 	blbs	zero1(fp),3f		# the value is zero - return
 	mnegl	power1(fp),r1		# r1 = negated exponent
 	bgtr	3f			# the value is less than 0.5 - return
 	cmpl	$32,power1(fp)		# is the decimal point deep inside ?
 	blss	4f			# yes - bypass
 	extzv	r1,power1(fp),fraction1+16(fp),r0 # extract some leading bits
 
 	addl2	$63,r1			# *** equivalent sequence to ***
 	bbc	r1,fraction1+8(fp),1f	# *** get around hardware problem ***
 #	decl	r1			; compute the rounding position
 #	bbc	r1,fraction1+16(fp),1$	; rounding bit is clear - skip
 	incl	r0			# round the extracted bits
 	bcc	1f			# no carry - skip
 	bisl2	$pslm_v,psl(fp) 	# indicate an integer overflow
 1:	blbc	sign1(fp),2f		# is the floating value negative
 	mnegl	r0,r0			# yes - complement the value
 2:	rotl	$1,r0,r1		# position the sign bit
 	xorb2	sign1(fp),r1		# complment it if negative value
 	blbc	r1,3f			# the sign is correct - skip
 	bisl2	$pslm_v,psl(fp) 	# indicate an integer overflow
 3:	rsb				# return
 4:	bisl2	$pslm_v,psl(fp) 	# indicate an integer overflow
 	movab	160(r1),r1		# switch origin to previous longword
 	bleq	3b			# no nonzero bits - return
 	extzv	r1,$32,fraction1-4(fp),r0 # extract 32 bits from the fraction
 
 	subl3	r1,$32,r2		# compute the bits to clear
 	blss	5f			# possible rounding - skip
 	insv	$0,$0,r2,r0		# clear some low order bits
 
 	brb	6f			# bypass
 5:	decl	r1			# compute the rounding bit
 	bbc	r1,fraction1-4(fp),6f	# the rounding bit is clear - skip

 	incl	r0			# round the extracted bits
 6:	blbc	sign1(fp),3b		# the value is positive - return
 	mnegl	r0,r0			# negate the value
 	rsb				# return
 #

 #
 #	fraction_real - isolate the fraction part of a floating value
 #
 #		entered by subroutine branching
 #
 #		parameter:	operand1 = the floating value
 #
 #		returns with	operand1 = the fractional part
 #
 #	discussion
 #
 #	    the exponent is used to determine the position of the
 #	decimal point within the fraction and all of the bits of
 #	the fraction above the decimal point are cleared. the result
 #	is then normalized.
 #
 fraction_real:				# entrance
 	blbs	zero1(fp),1f		# the value is zero - return
 	movl	power1(fp),r0		# r0 = the exponent
 	bleq	1f			# the value is all fraction - return
 	extzv	$0,$5,r0,r1		# r1 = bits to clear in last longword
 
 	ashl	$-5,r0,r0		# r0 = number of longwords to clear
 
 	cmpl	$4,r0			# will we clear the whole value ?
 	bgtr	2f			# no - bypass
 	movl	$1,operand1(fp) 	# mark the value as zero
 1:	rsb				# return
 2:	subl3	r1,$32,r2		# compute the last clear position
 	moval	fraction1+16(fp),r3	# r3 = clear index
 	brb	4f			# enter the clear loop
 3:	clrl	-(r3)			# clear a longword of the fraction
 4:	sobgeq	r0,3b			# more longwords to clear - loop
 	insv	$0,r2,r1,-4(r3) 	# perform the last clear
 
 	bsbw	normalize		# normalize the result
 	rsb				# return
 #

 #
 #	add_real - add floating values
 #
 #		entered by subroutine branching
 #
 #		parameters:	operand1 = first floating operand
 #				operand2 = second floating operand
 #
 #		returns with	operand1 = the floating result
 #
 #	discussion
 #
 #	    this routine performs the addition of floating values
 #	in the internal representation in such a way that the sum is
 #	the exact sum truncated to 127 or 128 significant bits. this
 #	precision is sufficient for performing g_floating and hfloat addition
 #	since these operations are based on truncating the exact sum
 #	to smaller numbers of significant digits.
 #
 #	    after preliminary checks for zero operands, the general
 #	addition is performed by first identifying a primary and a
 #	secondary operand with the primary operand being sufficiently
 #	large that it will not need to be shifted to align the values.
 #	this choice is made by examining the exponents. if the 
 #	operands have opposite signs, the fractions are further 
 #	compared so the magnitude of the primary operand is larger 
 #	than the magnitude of the secondary operand. the primary and
 #	secondary operand fractions are loaded into groups of 
 #	registers and the primary operand is shifted to the right one
 #	bit to allow for overflows. the secondary operand fraction is
 #	shifted to line it up with the primary operand fraction. if
 #	the signs of the operands are not the same then a record is 
 #	made if any significant bits are lost during the alignment of
 #	the secondary operand fraction. the resulting fractions are
 #	added or subtracted and an additional one is subtracted if
 #	lost bits were detected in the test made above. the result
	#	is then normalized.
 #
 add_real:				# entrance
 	movab	operand1(fp),r0 	# r0 = location of first operand
 	movab	operand2(fp),r1 	# r1 = location of second operand
 	blbs	zero(r1),3f		# second operand is zero - bypass
 	blbc	zero(r0),1f		# first operand is not zero - bypass
 	movl	operand2(fp),operand1(fp) # copy the sign and zero flags
 	movl	power2(fp),power1(fp)	# copy the exponent
 	movq	fraction2(fp),fraction1(fp) # copy second half of fraction
 	movq	fraction2+8(fp),fraction1+8(fp) # copy first half of fraction
 	rsb				# done
 1:	cmpl	power(r0),power(r1)	# compare the exponents
 	bgtr	5f			# first is greater - bypass
 	blss	4f			# second is greater - bypass
 	cmpb	sign(r0),sign(r1)	# compare the signs
 	beql	5f			# they're equal - bypass
 	movab	fraction+16(r0),r2	# r2 = position past first fraction
 	movab	fraction+16(r1),r3	# r3 = position past second fraction
 	movl	$4,r4			# r4 = loop counter
 2:	cmpl	-(r2),-(r3)		# compare two fraction longwords

 	bgtru	5f			# first is greater - bypass
 	blssu	4f			# second is greater - bypass
 	sobgtr	r4,2b			# more longwords to compare - loop
 	movl	$1,operand1(fp) 	# mark the result as zero
 3:	rsb				# return
 4:	movl	r0,r1			# r1 = secondary operand location
 	movab	operand2(fp),r0 	# r0 = primary operand location
 5:	subl3	power(r1),power(r0),r2	# r2 = exponent difference
 
 	addl3	$1,power(r0),power1(fp) # store the result exponent
 
 	xorb3	sign(r0),sign(r1),r3	# r3 = subtraction flag
 
 	movl	(r0),operand1(fp)	# store the result sign and zero flag
 	ashq	$-1,fraction(r1),r4	# r4 = last shifted secondary longword
 
 	ashq	$-1,fraction+4(r1),r5	# r5 = previous shifted longword
 
 	ashq	$-1,fraction+8(r1),r6	# r6,r7 = first two shifted longwords
 
 	bbcc	$31,r7,6f		# clear the high order bit
 6:	ashq	$-1,fraction(r0),fraction1(fp) # shift fourth result longword
 
 	ashl	$1,fraction1+4(fp),fraction1+4(fp) # position third longword
 
 	ashq	$-1,fraction+4(r0),fraction1+4(fp) # shift third longword
 
 	ashl	$1,fraction1+8(fp),fraction1+8(fp) # position second longword
 
 	ashq	$-1,fraction+8(r0),fraction1+8(fp) # shift first two longwords
 
 	bbcc	$31,fraction1+12(fp),7f # clear the high order bit
 7:	movl	$1,r8			# r8 = negation adjustment
 	cmpl	$127,r2 		# is the shift count large ?
 
 	bgeq	8f			# no - skip
 	movzbl	$127,r2 		# yes - use a smaller one
 8:	tstl	r2			# is the shift count zero ?
 	beql	2f			# yes - bypass
 	cmpl	$32,r2			# is the shift more than a longword ?
 	bgeq	0f			# no - bypass
 	tstl	r4			# is the last longword zero ?
 	beql	9f			# no - skip
 	clrl	r8			# clear the negation adjustment
 9:	subl2	$32,r2			# decrement the shift count
 	movq	r5,r4			# shift the last two longwords
 	movl	r7,r6			# shift the previous longword
 	clrl	r7			# clear the leading longword
 	brb	8b			# try again
 0:	mnegl	r2,r9			# r9 = - shift count
 	cmpzv	$0,r2,r4,$0		# are the low order bits zero ?
 
 	beql	1f			# yes - skip
 	clrl	r8			# clear the negation adjustment
 1:	ashq	r9,r4,r4		# shift the last longword
 	ashl	r2,r5,r5		# position the previous longword
 	ashq	r9,r5,r5		# shift the previous longword

 	ashl	r2,r6,r6		# position the previous longword
 	ashq	r9,r6,r6		# shift the first two longwords
 2:	blbc	r3,3f			# not subtraction - bypass
 	mcoml	r7,r7			# complement first longword
 	mcoml	r6,r6			# complement second longword
 	mcoml	r5,r5			# complement third longword
 	mcoml	r4,r4			# complement last longword
 	addl2	r8,r4			# add the negation adjustment
 	adwc	$0,r5			# propagate any carry
 	adwc	$0,r6			# propagate any carry
 	adwc	$0,r7			# propagate any carry
 3:	addl2	r4,fraction1(fp)	# add the fourth longwords
 	adwc	r5,fraction1+4(fp)	# add the third longwords
 	adwc	r6,fraction1+8(fp)	# add the second longwords
 	adwc	r7,fraction1+12(fp)	# add the leading longwords
 	bsbw	normalize		# normalize the result
 	rsb				# return
 #

 
 #
 #	multiply_float - multiply two floating values
 #
 #		entered by subroutine branching
 #
 #		parameters:	operand2 = first floating factor
 #				operand3 = second floating factor
 #
 #		returns with	operand1 = the floating product
 #				r0 = normalization shift count
 #
 #		see mulyiply_xfloat routines for more information.
 #
 
 multiply_float:
 	caseb	*op_index(fp),$typ_f,$(typ_h-typ_f)
 1:
	.word	multiply_ffloat-1b	# f_floating
 	.word	multiply_dgfloat-1b	# d_floating
 	.word	multiply_dgfloat-1b	# g_floating
 	.word	multiply_hfloat-1b	# h_floating

 
 #	discussion
 #
 #	    this routine forms the product of two floating values 
 #	in the internal representation and deliberately limits the
 #	accuracy to 32 bits. only the high order 32 bits of each of
 #	the operand fractions is used and the result is the high
 #	order 32 bits of the exact product. the remaining bits of the
 #	fraction are zero. upon return the register r0 contains the
 #	distance the product was shifted during normalization.
 #
 
 multiply_ffloat:
 	movl	$1,operand1(fp) 	# mark the result as zero
 	clrl	r0			# clear the shift count
 	blbs	zero2(fp),2f		# first operand is zero - return
 	blbs	zero3(fp),2f		# second operand is zero - return
 	clrb	zero1(fp)		# clear the zero flag
 	movl	$1,r0			# r0 = number of longwords to multiply
 	movab	fraction2+12(fp),r1	# r1 = location of first factor
 	movab	fraction3+12(fp),r2	# r2 = location of second factor
 	movab	fraction1+8(fp),r3	# r3 = location for product
 	bsbw	multiply		# multiply the quadwords
 	clrl	r0			# clear the shift count
 	addl3	power2(fp),power3(fp),power1(fp) # compute the exponent
 
 	xorb3	sign2(fp),sign3(fp),sign1(fp) # compute the sign
 
 	bbs	$31,fraction1+12(fp),1f # 001 - result is normalized - bypass
 	incl	r0			# set the shift count to one
 	decl	power1(fp)		# decrement the exponent
 	ashl	$1,fraction1+12(fp),fraction1+12(fp) # normalize the fraction
 
 	bbc	$31,fraction1+8(fp),1f	# low order bit should be clear - skip
 	bisl2	$1,fraction1+12(fp)	# set the low order bit
 1:	clrq	fraction1(fp)		# extend the fraction to an octaword
 	clrl	fraction1+8(fp)		#
 2:	rsb				# return
 #

 
 #	discussion
 #
 #	    this routine forms the product of two floating values 
 #	in the internal representation and deliberately limits the
 #	accuracy to 64 bits. only the high order 64 bits of each of
 #	the operand fractions is used and the result is the high
 #	order 64 bits of the exact product. the remaining bits of the
 #	fraction are zero. upon return the register r0 contains the
 #	distance the product was shifted during normalization.
 #
 multiply_dgfloat: 			# entrance
 	movl	$1,operand1(fp) 	# mark the result as zero
 	clrl	r0			# clear the shift count
 	blbs	zero2(fp),2f		# first operand is zero - return
 	blbs	zero3(fp),2f		# second operand is zero - return
 	clrb	zero1(fp)		# clear the zero flag
 	movl	$2,r0			# r0 = number of longwords to multiply
 	movab	fraction2+8(fp),r1	# r1 = location of first factor
 	movab	fraction3+8(fp),r2	# r2 = location of second factor
 	movab	fraction1(fp),r3	# r3 = location for product
 	bsbw	multiply		# multiply the quadwords
 	clrl	r0			# clear the shift count
 	addl3	power2(fp),power3(fp),power1(fp) # compute the exponent
 
 	xorb3	sign2(fp),sign3(fp),sign1(fp) # compute the sign
 
 	bbs	$31,fraction1+12(fp),1f # result is normalized - bypass
 	incl	r0			# set the shift count to one
 	decl	power1(fp)		# decrement the exponent
 	ashq	$1,fraction1+8(fp),fraction1+8(fp) # normalize the fraction
 
 	bbc	$31,fraction1+4(fp),1f	# low order bit should be clear - skip
 	bisl2	$1,fraction1+8(fp)	# set the low order bit
 1:	clrq	fraction1(fp)		# extend the fraction to an octaword
 2:	rsb				# return
 #

 
 #
 #	discussion
 #	
 #	    this routine computes the product of two floating values
 #	in the internal representation. the fraction of the result 
 #	consists of the high order 128 bits of the exact product.
 #	upon return the register r0 contains the distance the product
 #	was shifted during normalization.
 #
 multiply_hfloat:
 	movl	$1,operand1(fp) 	# mark the result as zero
 	clrl	r0			# clear the shift count
 	blbs	zero2(fp),2f		# first operand is zero - return
 	blbs	zero3(fp),2f		# second operand is zero - return
 	clrb	zero1(fp)		# clear the zero flag
 	movl	$4,r0			# r0 = number of longwords to multiply
 	movab	fraction2(fp),r1	# r1 = location of first factor
 	movab	fraction3(fp),r2	# r2 = location of second factor
 	movab	temp(fp),r3		# use temporary area for result
 	bsbw	multiply		# perform the multiplication
 	clrl	r0			# clear the shift count
 	addl3	power2(fp),power3(fp),power1(fp) # compute the exponent
 
 	xorb3	sign2(fp),sign3(fp),sign1(fp) # compute the sign
 
 	movq	temp+16(fp),fraction1(fp) # insert second part of fraction
 	movq	temp+24(fp),fraction1+8(fp) # insert first part of fraction
 	blss	2f			# fraction is normalized - bypass
 	incl	r0			# set the shift count to one
 	decl	power1(fp)		# decrement the exponent
 	ashq	$1,fraction1+8(fp),fraction1+8(fp) # normalize the first part
 
 	bbc	$31,fraction1+4(fp),1f	# low order bit should be clear - skip
 	bisl2	$1,fraction1+8(fp)	# set the low bit in the first part
 1:	ashq	$1,fraction1(fp),fraction1(fp) # normalize the second part
 
 	bbc	$31,temp+12(fp),2f	# low order bit should be clear - skip
 	bisl2	$1,fraction1(fp)	# set the low bit in the second part
 2:	rsb				# return
 #

 
 #
 #	divide_float - divide two floating values
 #
 #		entered by subroutine branching
 #
 #		parameters:	operand2 = the floating dividend
 #				operand3 = the floating divisor
 #	
 #		returns with	operand1 = floating quotient
 #
 #	see divide_xfloat routines for more information.
 #
 
 divide_float:
 	caseb	*op_index(fp),$typ_f,$(typ_h-typ_f)
 1:
	.word	divide_ffloat-1b	# f_floating
 	.word	divide_dgfloat-1b	# d_floating
 	.word	divide_dgfloat-1b	# g_floating
 	.word	divide_hfloat-1b	# h_floating

 
 #	discussion
 #	
 #	    this routine computes the quotient of two floating values
 #	in the internal representation. the fractions of the two input
 #	values consist of the high order 32 bits of the two operand 
 #	fractions and the fraction of the quotient consists of the
 #	high order 31 or 32 bits of the exact quotient. the remaining
 #	bits of the fraction are set to zero. if the divisor is zero
 #	then a floating division by zero fault is signaled.
 #
 divide_ffloat:				# entrance
 	blbc	zero3(fp),1f		# divisor is not zero - skip
 	brw	divide_fault		# process the floating divide fault
 1:	movl	$1,operand1(fp) 	# mark the result as zero
 	blbs	zero2(fp),3f		# dividend is zero - bypass
 	ashl	$-1,fraction2+12(fp),fraction2+12(fp) # normalize for division
 
 	bbcc	$31,fraction2+12(fp),2f # clear the high order bit
 2:	incl	power2(fp)		# increment the exponent
 	movl	$1,r0			# r0 = number of longwords in divisor
 	movab	fraction2+8(fp),r1	# r1 = dividend location
 	movab	fraction3+12(fp),r2	# r2 = divisor location
 	movab	fraction1+12(fp),r3	# r3 = quotient area location
 	bsbw	divide			# perform the division
 	clrb	zero1(fp)		# indicate a nonzero result
 	subl3	power3(fp),power2(fp),power1(fp) # compute the exponent
 
 	xorb3	sign3(fp),sign2(fp),sign1(fp) # compute the sign
 
 	clrq	fraction1(fp)		# extend the quotient to 128 bits
 	bbs	$31,fraction1+12(fp),3f # the result is normalized - bypass
 	ashl	$1,fraction1+12(fp),fraction1+12(fp) # normalize the quotient
 
 	decl	power1(fp)		# increment the exponent
 3:	rsb				# return
 #

 
 #	discussion
 #	
 #	    this routine computes the quotient of two floating values
 #	in the internal representation. the fractions of the two input
 #	values consist of the high order 64 bits of the two operand 
 #	fractions and the fraction of the quotient consists of the
 #	high order 63 or 64 bits of the exact quotient. the remaining
 #	bits of the fraction are set to zero. if the divisor is zero
 #	then a floating division by zero fault is signaled.
 #
 divide_dgfloat:
 	blbc	zero3(fp),1f		# divisor is not zero - skip
 	brw	divide_fault		# process the floating divide fault
 1:	movl	$1,operand1(fp) 	# mark the result as zero
 	blbs	zero2(fp),3f		# dividend is zero - bypass
 	ashq	$-1,fraction2+8(fp),fraction2+8(fp) # normalize for division
 
 	bbcc	$31,fraction2+12(fp),2f # clear the high order bit
 2:	incl	power2(fp)		# increment the exponent
 	movl	$2,r0			# r0 = number of longwords in divisor
 	movab	fraction2(fp),r1	# r1 = dividend location
 	movab	fraction3+8(fp),r2	# r2 = divisor location
 	movab	fraction1+8(fp),r3	# r3 = quotient area location
 	bsbw	divide			# perform the division
 	clrb	zero1(fp)		# indicate a nonzero result
 	subl3	power3(fp),power2(fp),power1(fp) # compute the exponent
 
 	xorb3	sign3(fp),sign2(fp),sign1(fp) # compute the sign
 
 	clrq	fraction1(fp)		# extend the quotient to 128 bits
 	bbs	$31,fraction1+12(fp),3f # the result is normalized - bypass
 	ashq	$1,fraction1+8(fp),fraction1+8(fp) # normalize the quotient
 
 	decl	power1(fp)		# increment the exponent
 3:	rsb				# return
 #

 
 #	discussion
 #	
 #	    this routine computes the quotient of two floating values
 #	in the internal representation. the fraction of the quotient
 #	consists of the high order 127 or 128 bits of the exact 
 #	quotient. if the divisor is zero, then a floating divide by
 #	zero fault is signaled.
 #
 divide_hfloat:
 	blbc	zero3(fp),1f		# the divisor is not zero - skip
 	brw	divide_fault		# process the floating divide fault
 1:	movl	$1,operand1(fp) 	# mark the result as zero
 	blbs	zero2(fp),6f		# dividend is zero - bypass
 	clrq	temp(fp)		# clear the last octaword of dividend
 	clrq	temp+8(fp)		# clear the last octaword of dividend
 	ashq	$-1,fraction2(fp),temp+16(fp) # move last part of dividend
 
 	ashq	$-1,fraction2+8(fp),temp+24(fp) # move first part of dividend
 
 	incl	power2(fp)		# increment the exponent
 	bbcc	$31,temp+20(fp),2f	# clear a sign extension bit
 2:	blbc	fraction2+8(fp),3f	# should the bit have been set ?
 	bbss	$31,temp+20(fp),3f	# yes - set it
 3:	bbcc	$31,temp+28(fp),4f	# clear the high order bit of dividend
 4:	movl	$4,r0			# r0 = number of longwords in divisor
 	movab	temp(fp),r1		# r1 = location of dividend
 	movab	fraction3(fp),r2	# r2 = location of divisor
 	movab	fraction1(fp),r3	# r3 = location for quotient
 	bsbw	divide			# perform the division
 	clrb	zero1(fp)		# mark the result as nonzero
 	subl3	power3(fp),power2(fp),power1(fp) # compute the exponent
 
 	xorb3	sign3(fp),sign2(fp),sign1(fp) # compute the sign
 
 	bbs	$31,fraction1+12(fp),6f # the result is normalized - bypass
 	ashq	$1,fraction1+8(fp),fraction1+8(fp) # normalize the first part
 
 	bbc	$31,fraction1+4(fp),5f	# should the low order bit be set ?
 	bisl2	$1,fraction1+8(fp)	# yes - set the bit
 5:	ashq	$1,fraction1(fp),fraction1(fp) # normalize the second part
 
 	decl	power1(fp)		# decrement the exponent
 6:	rsb				# return
 #

 #
 #	normalize - normalize a floating value
 #
 #		entered by subroutine branching
 #
 #		parameter:	operand1 = the unnormalized value
 #
 #		returns with	operand1 = the normalized result
 #
 #	discussion
 #
 #	    this routine normalizes a floating value in the internal
 #	representation so that the high order bit of the fraction is
 #	one. this is done by locating the high order significant bit
 #	of the fraction and then by shifting the fraction so that the
 #	bit appears in the proper position. the shift count is 
 #	subtracted from the exponent so the value does not change.
 #
 normalize:				# entrance
 	blbs	zero1(fp),2f		# the value is zero - return
 1:	tstl	fraction1+12(fp)	# test the first longword
 	blss	2f			# value is already normalized - return
 	beql	3f			# first longword is zero - bypass
 	clrl	r1			# set intitial shoft count
 	movl	fraction1+12(fp),r0	# get high longword of fraction
 7:	incl	r1			# increment shift count
 	ashl	$1,r0,r0		# shift one more bit
 	bvc	7b			# repeat until high bit set
 	mnegl	r1,r0			# r0 = -shift count
 #*
 # the previous six instructions are a replacement for the following four
 # instructions.  we can no longer guarantee that cvtld is supported.
 #
 #	cvtld	fraction1+12(fp),r0	; use hardware to find shift count
 #	extzv	$7,$6,r0,r0		; r0 = high order bit position + 1
 #	subl2	$32,r0			; r0 = - shift count
 #	mnegl	r0,r1			; r1 = shift count
 #*
 	ashq	r1,fraction1+8(fp),fraction1+8(fp) # position first longword
 
 	ashl	r0,fraction1+8(fp),fraction1+8(fp) # get second parts together
 
 	ashq	r1,fraction1+4(fp),fraction1+4(fp) # position second longword
 
 	ashl	r0,fraction1+4(fp),fraction1+4(fp) # get other parts together
 
 	ashq	r1,fraction1(fp),fraction1(fp) # position last two longwords
 
 	subl2	r1,power1(fp)		# increment the exponent
 2:	rsb				# return
 3:	subl2	$32,power1(fp)		# decrement the exponent
 	tstl	fraction1+8(fp) 	# test the second longword
 	beql	4f			# it's zero - bypass
 	movq	fraction1+4(fp),fraction1+8(fp) # shift first two longwords
 	movl	fraction1(fp),fraction1+4(fp) # shift third longword
 	clrl	fraction1(fp)		# clear the final longword
 	brb	1b			# finish up

 4:	subl2	$32,power1(fp)		# decrement the exponent
 	tstl	fraction1+4(fp) 	# test the third longword
 	beql	5f			# it's zero - bypass
 	movq	fraction1(fp),fraction1+8(fp) # position first two longwords
 	clrq	fraction1(fp)		# clear the last two longwords
 	brb	1b			# finish up
 5:	subl2	$32,power1(fp)		# decrement the exponent
 	tstl	fraction1(fp)		# test the fourth longword
 	beql	6f			# it's zero - bypass
 	movl	fraction1(fp),fraction1+12(fp) # position the first longword
 	clrl	fraction1+8(fp) 	# clear the second longword
 	clrq	fraction1(fp)		# clear the last two longwords
 	brw	1b			# finish up
 6:	movl	$1,operand1(fp) 	# mark the value as zero
 	rsb				# return
 #

 #
 #	multiply - unsigned multiple length integer multiply
 #
 #		entered by subroutine branching
 #
 #		parameters:	r0 = size of inputs in longwords
 #				r1 = location of first factor
 #				r2 = location of second factor
 #				r3 = location of destination area
 #
 #	discussion
 #
 #	    this routine computes the product of two multiple length
 #	unsigned integers and stores the unsigned product in a 
 #	specified area. the parameter r0 contains the number of 
 #	longwords in each of the input factors and the number of 
 #	longwords in the product is twice the value of r0. the 
 #	parameters r1 and r2 contain the locations of the input 
 #	factors and the parameter r3 contains the location of the
 #	area for the product.
 #
 #
 #	the algorithm
 #
 #	    the algorithm used is perfectly straightforward. the
 #	second factor is multiplied by each of the unsigned longwords
 #	of the first factor and the aligned products are added to the
 #	destination area. the multiplications and additions are
 #	performed by a series of emul instructions in which the two
 #	factors are longwords from each of the factors and the added
 #	operand is formed by adding target longword of the result area
 #	and from carryover information from the previous iteration
 #	of the emul loop. the carryover information is formed by 
 #	adding the high order bits of the previous product, the 
 #	opposite factor for each factor longword which is negative
 #	from the previous multiplication, a one if the previous 
 #	carryover longword was negative, and a one if the previous
 #	additive operand was negative. most of these contributions are
 #	compensations for the fact that the emul instruction assumes
 #	that the operands are signed.
 #
 #	    to show that the algorithm is correct the major step is
 #	to show that the emul operations do not loose information
 #	because of overflow. to show this we make use of the fact that
 #	for two's complemented addition and multiplication information
 #	only moves in the direction of the high order bits. therefore,
 #	if the product fits into two unsigned longwords it is correct.
 #	the unsigned information input to each emul step is 
 #
 #		first factor <= 2^32-1
 #		second factor <= 2^32-1
 #		longword from result area <= 2^32-1
 #		unsigned carryover information <= 2^32-1
 #
 #	the output of the step is the product of the first two values
 #	plus the second two values. this does not exceed
 #	

 #		(2^32-1)^2+2*(2^32-1) = 2^64-1
 #
 #	which is representable in two unsigned longwords so the 
 #	output carryover information fits into an unsigned longword.
 #	consequently no information can be lost during the emul steps.
 #	
 #
 multiply:				# entrance
 	clrl	r4			# clear the loop index
 1:	clrl	(r3)[r4]		# clear a longword of the result
 	aoblss	r0,r4,1b		# more longwords to clear - loop
 	clrl	r4			# clear the loop index
 2:	clrl	r5			# clear the inner loop index
 	movl	(r1)+,r6		# r6 = next value from first factor
 	moval	(r3)+,r7		# r7 = area of product being affected
 	clrl	r9			# clear the carryover information
 3:	clrl	r10			# clear the cell to take the carry
 	addl2	(r7),r9 		# include value so far in carryover
 	adwc	$0,r10			# remember the carry
 	movl	(r2)[r5],r8		# r8 = next value from second factor
 	bgeq	4f			# it's not negative - skip
 	addl2	r6,r10			# make unsigned by adding other factor
 4:	bbc	$31,r6,5f		# first factor is not negative - skip
 	addl2	r8,r10			# make unsigned by adding other factor
 5:	bbc	$31,r9,6f		# carryover is not negative - skip
 	incl	r10			# make unsigned by adding one
 6:	emul	r6,r8,r9,r8		# multiply factors including carryover
 
 	movl	r8,(r7)+		# accumulate the product
 	addl2	r10,r9			# form the new carryover
 	aoblss	r0,r5,3b		# partial product not complete - loop
 	movl	r9,(r7) 		# store the last part of the product
 	aoblss	r0,r4,2b		# full product not complete - loop
 	rsb				# return
 #

 #
 #	divide - unsigned multiple length integer divide
 #
 #		entered by subroutine branching
 #
 #		parameters:	r0 = size of the divisor in longwords
 #				r1 = location of the dividend
 #				r2 = location of the divisor
 #				r3 = location of the quotient area
 #	
 #	discussion
 #	
 #	    this routine performs unsigned multiple length division
 #	and develops a quotient and a remainder. the number of
 #	longwords in the divisor and in the quotient area is given
 #	by the parameter r0. the number of longwords in the dividend
 #	area is twice the value of r0. the parameter r1 is the 
 #	location of the dividend, r2 is the location of the divisor,
 #	and r3 is the location for the quotient. the remainder is
 #	formed in the low order r0 longwords of the dividend area.
 #	it is assumed that the high order bit of the divisor is one
 #	and that the high order bit of the dividend is zero. these
 #	conditions insure that the quotient will fit into the quotient
 #	area.
 #
 #
 #	the algorithm
 #
 #	    the algorithm used is a variation of the classical divide
 #	and correct method which has been adapted for the above 
 #	specifications. the algorithm has been implemented using words
 #	rather than longwords because the word version is much easier
 #	to verify for correctness since there are no problems with 
 #	using signed arithmetic operations to perform unsigned
 #	arithmetic.
 #
 #	    we let a[0..2n-1] denote the dividend as an array of words
 #	with a[0] being the low order word, and n being twice the
 #	value of r0. similarly we let b[0..n-1] denote the divisor and
 #	c[0..n-1] the quotient. The remainder will be developed in the
 #	array a[0..n-1]. the algorithm may be given as follows:
 #
 #
 #		Step 0. Let I = N.
 #
 #		step 1.	let i = n-1 and a[2n] = 0.
 #
 #			{ the use of a[2n] is only a simplification,
 #			  it does not really appear in the program. }
 #
 #		step 2. let q = entier(a[i+n-1..i+n+1]/(b[n-1]+1)) and
 #			let r be the remainder from the division.
 #
 #			{ this operation is performed by a single
 #			  ediv instruction. }
 #
 #		step 3. let x = b*b[n-1]+b[n-2]+1 and
 #			Y = -Q*B[N-2]+b*R+A[I+N-2]
 #			  =  Q*(b-B[N-2]-1)+b*R+A[I+N-2].
 #
 #
 #			{ here b denotes 2^16 which is the "base" of
 #			  the number system we are using and b-B[N-2]-1
 #			  is the ones complement of -B[N-2]. These
 #			  values are used to correct the quotient. }
 #
 #		step 4. let y = y-x. if  y >= 0 then let q = q+1 and
 #			repeat this step.
 #
 #			{ when this step is complete the value of q is
 #
 #			   entier(a[i+n-2..i+n+1]/(b[n-2..n-1]+1) }
 #
 #		step 5. let a[i..i+n] = a[i..i+n]-q*b[0..n-1].
 #
 #		step 6. let c[i] = q and if q is too large then add
 #		 	the overflow to c[i+1..n-1]. if i > 2 then
 #			go to step 2.
 #
 #		step 7. if b[0..n-1] <= a[0..n] then let
 #			c[0..n-1] = c[0..n-1]+1 and 
 #			a[0..n-1] = a[0..n-1]-b[0..n-1].
 #			the division is complete.
 #
 #
 divide: 				# entrance
 	ashl	$1,r0,r0		# convert the longword count to words
 	movaw	(r1)[r0],r1		# r1 = current position in dividend
 	movaw	(r2)[r0],r4		# r4 = position above divisor
 	movaw	(r3)[r0],r3		# r3 = position above quotient area
 	movzwl	-2(r4),r9		# r9 = leading word of divisor
 	incl	r9			# form the trial divisor
 	movl	-4(r4),r10		# r10 = leading longword of divisor
 	incl	r10			# form the correction divisor
 	mcomw	-4(r4),r11		# r11 = complemented second word
 	movzwl	r11,r11 		# form the correction multiplier
 	movl	r0,r4			# r4 = loop counter
 	clrl	r6			# clear the carryover information
 Lone:	subl2	$2,r1			# r1 = current position in dividend
 	subl2	$2,r3			# r3 = current position in quotient
 	movaw	(r1)[r0],r5		# r5 = location of next dividend word
 	movl	-2(r5),r5		# r5 = leading longword of dividend
 	ediv	r9,r5,r5,r6		# r5 = quotient, r6 = remainder
 
 	clrl	r8			# clear the double length adjustment
 	ashl	$16,r6,r6		# position the remainder
 	bgeq	2f			# is the value negative ?
 	incl	r8			# yes - the sum will need adjusting
 2:	movw	-4(r1)[r0],r6		# include next word from dividend
 	emul	r5,r11,r6,r6		# form the correction remainder
 
 	addl2	r8,r7			# adjust the second longword
 3:	clrl	r8			# clear the subtraction adjustment
 	bbs	$31,r10,4f		# is the correction divisor negative ?
 	incl	r8			# yes - difference will need adjusting
 4:	subl2	r10,r6			# subtract the first longwords
 	sbwc	r8,r7			# subtract the second longwords
 	blss	5f			# result is negative - bypass
 	incl	r5			# correct the quotient

 	brb	3b			# try for another correction
 5:	movl	r3,r6			# r6 = current word in quotient
 	clrw	(r6)			# clear the word
 	addl2	r5,(r6)+		# add the current quotient into it
 6:	adwc	$0,(r6)+		# propagate any carry
 	bcs	6b			# another carry - loop
 	mnegl	r5,r5			# negate the quotient
 	clrl	r6			# clear the carryover information
 	clrl	r8			# clear the loop index
 7:	movzwl	(r1)[r8],r7		# r7 = next word from dividend
 	addl2	r7,r6			# add it to the carryover
 	movzwl	(r2)[r8],r7		# r7 = next word from divisor
 	emul	r5,r7,r6,r6		# form next word of dividend
 
 	movw	r6,(r1)[r8]		# store it
 	ashq	$-16,r6,r6		# position the carryover information
 
 	aoblss	r0,r8,7b		# remainder is not complete - loop
 	movzwl	(r1)[r0],r7		# r7 = high order word of remainder
 	addl2	r7,r6			# add it to the carryover
	bgeq	go_on
	clrl	r6			# the carry can not be negative
go_on:
 	sobgtr	r4,Lone			# division is not complete - loop
 	ashl	$-1,r0,r0		# restore the count to longwords
 
 	tstl	r6			# is the carryover nonzero ?
 	bneq	9f			# yes - bypass
 	subl3	$1,r0,r4		# r4 = loop index
 8:	cmpl	(r1)[r4],(r2)[r4]	# compare remainder and divisor
 	blssu	2f			# less than - bypass
 	bgtru	9f			# greater than - skip
 	sobgeq	r4,8b			# more longwords to compare - loop
 9:	clrl	r4			# clear the loop index
 	bicpsw	$pslm_c 		# clear the carry bit
 0:	sbwc	(r2)+,(r1)+		# subtract corresponding longwords
 	aoblss	r0,r4,0b		# more lonwords to subtract - loop
 	incl	(r3)+			# increment the quotient
 1:	adwc	$0,(r3)+		# propagate any carry
 	bcs	1b			# another carry to propagate - loop
 2:	rsb				# return
 #

 #	****************************************************************
 #	*							       *
 #	*							       *
 #	*	       condition code processing routines	       *
 #	*							       *
 #	*							       *
 #	****************************************************************
 #
 #
 #	introduction
 #	------------
 #
 #	    in order that condition code information be usable 
 #	directly by the code of the emulator as well as be available
 #	for use in the emulated psl, the routines which perform tests
 #	and compares set the hardware condition codes. the routine
 #	set_condition is used to move the hardware condition codes
 #	to the emulated psl.
 #
 #	    the routines of this portion of the emulator are extremely
 #	simple so the descriptions of routines are included with the
 #	routines. here we will just discuss the general policy on 
 #	condition codes within the emulator.
 #
 #
 #	general policy on condition codes
 #	---------------------------------
 #
 #	    in general it is the responsibility of each of the
 #	instruction emulation routines to insure that the condition
 #	codes are correct. since for most of the instructions
 #	presently emulated the condition codes reflect the floating
 #	value that appears in operand1, the routine set_condition1
 #	is available for checking the value and setting the condition
 #	codes in the emulated psl. in other cases these operations 
 #	must be done in line.
 #
 #	    for those instructions which return an integer result
 #	the v bit is used to indicate whether or not an integer 
 #	overflow took place. because of this it is also checked in
 #	normal_exit in order to determine if a integer overflow trap
 #	should be signaled. for this reason it is cleared when the
 #	instruction emulation is started in emulator.
 #

 #
 #	set_condition - capture the condition codes n and z in the psl
 #
 #		entered by subroutine branching
 #	
 #		no parameters
 #
 #	discussion
 #
 #	    this routine sets the n and z bits in the emulated psl
 #	equal to those bits in psl available on entry to the routine.
 #
 set_condition:				# entrance
 	blss	1f			# less than - bypass
 	bgtr	2f			# greater than - bypass
 	bicl2	$pslm_nz,psl(fp)	# clear the n bit and z bit in the psl
 	bisl2	$pslm_eql,psl(fp)	# specify equals in the psl
 	rsb				# return
 1:	bicl2	$pslm_nz,psl(fp)	# clear the n bit and z bit in the psl
 	bisl2	$pslm_lss,psl(fp)	# specify less than in the psl
 	rsb				# return
 2:	bicl2	$pslm_nz,psl(fp)	# clear the n bit and z bit in the psl
 	bisl2	$pslm_gtr,psl(fp)	# specify greater than in the psl
 	rsb				# return
 #
 #	set_condition1 - test a floating value setting the psl
 #
 #		entered by subroutine branching
 #	
 #		parameter:	operand1 = the floating value
 #
 #	discussion
 #
 #	    this routine tests the floating value in operand1 and
 #	sets the n and z bits in the emulated psl according to the
 #	outcome of the test. the v and c bits in the emulated psl
 #	are cleared.
 #
 set_condition1: 			# entrance
 	movab	operand1(fp),r1 	# r1 = location of operand1
 	bsbb	test_real		# test the value
 	bsbb	set_condition		# set the condition codes
 	bicl2	$pslm_vc,psl(fp)	# clear the v bit and c bit in the psl
 	rsb
 #

 #
 #	test_real - test all floating types
 #
 #		entered by subroutine branching
 #	
 #		parameter:	r1 = floating value location
 #
 #	discussion
 #
 #	    this routine tests the floating value in the internal 
 #	representation that is addressed by r1 and sets the hardware
 #	condition codes accordingly. these settings are available
 #	when the routine returns.
 #
 test_real:				# entrance
 	blbs	zero(r1),test_eql	# value is zero - bypass
 	blbc	sign(r1),test_gtr	# value is positive - bypass
 	brb	test_lss		# value is negative - bypass
 #
 #	test_octa - test an octaword in operand1
 #
 #		entered by subroutine branching
 #	
 #		parameter:	operand1 = 128 bit octaword value
 #
 #	discussion
 #
 #	    this routine tests the octaword value which occupies 
 #	128 bits and starts at operand1 (it is not in the internal
 #	floating representation) and sets the hardware condition
 #	codes according to the outcome of the test. these settings
 #	are available when the routine returns.
 #
 test_octa:				# entrance
 	movl	$3,r0			# initialize the index
 	tstl	operand1(fp)[r0]	# test the first longword
 	bgeq	2f			# it's not negative - bypass
 	rsb				# return indicating negative value
 1:	tstl	operand1(fp)[r0]	# test the next longword
 2:	bneq	test_gtr		# value is positive - bypass
 	sobgeq	r0,1b			# more longwords to examine - loop
 	brb	test_eql		# value is zero - bypass
 #

 #
 #	compare_real - compare internal format floating values 
 #
 #		entered by subroutine branching
 #
 #		parameters:	r1 = location of first floating value
 #				r2 = locaiton of second floating value
 #
 #	discussion
 #	
 #	    this routine compares the two floating values addressed
 #	by r1 and r2 and sets the hardware condition codes according
 #	to the outcome of the comparison. these settings are available
 #	when the routine returns.
 #
 compare_real:				# entrance
 	cmpb	sign(r1),sign(r2)	# compare the sign indicators
 	bneq	3f			# not equal - bypass
 	cmpb	zero(r2),zero(r1)	# compare the zero indicators
 	bneq	2f			# not equal - bypass
 	blbs	zero(r1),test_eql	# both are zero and equal - bypass
 	cmpl	power(r1),power(r2)	# compare the exponents
 	blss	4f			# condition was less than - bypass
 	bgtr	3f			# condition was greater - bypass
 	movl	$3,r0			# r0 = loop index
 1:	cmpl	fraction(r1)[r0],fraction(r2)[r0] # compare corresponding longwords
 					# from the fractions
 	bneq	2f			# not equal - bypass
 	sobgeq	r0,1b			# more longwords to examine - loop
 	brb	test_eql		# arrange an equals return
 2:	blssu	4f			# condition was less than - bypass
 3:	blbc	sign(r1),test_gtr	# condition is greater than - bypass
 	brb	test_lss		# condition is less than - bypass
 4:	blbc	sign(r1),test_lss	# condition is less than - bypass
 	brb	test_gtr		# condition is greater than - bypass
 #

 #
 #	test_lss - set the condition codes to specify less than
 #
 #		entered by subroutine branching
 #
 #		no parameters
 #
 #	discussion
 #
 #	    this routine sets the hardware condition codes to specify
 #	a "less than" outcome. this setting is available when the 
 #	routine returns.
 #
 test_lss:				# entrance
 	tstb	$-1			# set the condition codes
 	rsb				# return
 #
 #	test_eql - set the condition codes to specify equals
 #
 #		entered by subroutine branching
 #
 #		no parameters
 #
 #	discussion
 #
 #	    this routine sets the hardware condition codes to specify
 #	an "equals" outcome. this setting is available when the 
 #	routine returns.
 #
 test_eql:				# entrance
 	tstb	$0			# set the condition codes
 	rsb				# return
 #
 #	test_gtr - set the condition codes to specify greater than
 #
 #		entered by subroutine branching
 #
 #		no parameters
 #
 #	discussion
 #
 #	    this routine sets the hardware condition codes to specify
 #	a "greater than" outcome. this setting is available when the
 #	routine returns.
 #
 test_gtr:				# entrance
 	tstb	$1			# set the condition codes
 	rsb				# return
 #

 #	****************************************************************
 #	*							       *
 #	*							       *
 #	*		exception processing routines		       *
 #	*							       *
 #	*							       *
 #	****************************************************************
 #
 #
 #	introduction
 #	------------
 #
 #	    in order to simplify the design of the emulator, it was
 #	decided that whenever fault conditions were detected during
 #	instruction emulation, that control would branch immediatly
 #	to the signaling routine rather than using status codes to
 #	inform some outer routine of the condition. because of this
 #	some care was necessary in the ordering of operations so that
 #	the emulator is always in the correct state when faults are
 #	detected. the only trap supported is the integer overflow
 #	trap and since this condition is only signaled when the 
 #	instruction emulation is complete, there is no problem with
 #	the flow of control.
 #
 #	    for each of the exceptions recognized, there is a routine
 #	which is branched to (except for access violations in which
 #	a subroutine branch is used instead) as soon as the condition
 #	is detected. this routine pushes a shortened version of the
 #	signal array onto the stack and branches to signal_start which
 #	builds the signal and mechanism arrays in the proper place in
 #	memory and enters the signal dispatcher to search for handlers
 #	to process the condition. if the exception was a fault, the
 #	routine fault_reset is called to restore the registers to
 #	their values when the instruction was started.
 #
 #
 #	access violations
 #	-----------------
 #
 #	    the routines read_fault and write_fault are called by
 #	subroutine branching when memory probes of read and write
 #	access fail during instruction emulation. the register r11 is
 #	assumed to contain the location of the area being probed
 #	and the register r10 is assumed to contain its length. the
 #	routine tries to produce the fault under controlled conditions
 #	and returns if it can not produce the fault. if it can produce
 #	the fault the the fault is signaled with the reason mask being
 #	the reason mask from the attempt to produce the fault and with
 #	the violation address as the address of the first byte of the
 #	area for which the access violation occurs.
 #
 #	
 #	the signal dispatcher
 #	---------------------
 #
 #	    the emulator presently contains all of the code necessary
 #	for signaling the condition since it is necessary that the

 #	emulator build the signal and mechanism arrays itself and
 #	since there is no "back door" to either the signal dispatcher
 #	in the common rtl or the one in vms. the version contained in
 #	the emulator is a copy with minor modifications of the one in
 #	lib$signal.
 #

 #
 #	read_fault - process a read access violation fault
 #
 #		entered by subroutine branching
 #
 #		parameters:	r10 = size of area being read
 #				r11 = location of area being read
 #
 read_fault:				# entrance
 	pushr	$0x07			# save r0,r1,r2
 	movl	r11,r2			# r2 = probed address
 	prober	mode(fp),$1,(r2)	# is the first byte readable ?
 
 	beql	1f			# no - bypass
 	prober	mode(fp),$1,-1(r2)[r10]	# is the last byte readable ?
 
 	bneq	1f			# yes - bypass
 	movab	-1(r2)[r10],r2		# r2 = address of last byte
 	bicw2	$511,r2			# compute address of first bad byte
 1:	calls	$0,read_reason		# get the reason mask
 	blbs	r0,2f			# the read went all right - bypass
 	bsbw	fault_reset		# reinitialize registers and clear tp
 	movab	short_local(fp),sp	# shorten the frame
 	pushl	r2			# push the bad address
 	pushl	r1			# push the reason mask
 	pushl	$ss$_accvio		# push the condition code
 	pushl	$3			# push the number of arguments
 	brw	signal_start		# signal the condition
 2:	popr	$0x7			# restore r0,r1,r2
 	rsb				# get back
 #
 #	read_reason - get the reason mask for a read access violation
 #
 #		parameter:	r2 = address for which probe failed
 #
 #		returns with	r0 = status of access attempt
 #				r1 = reason mask if unsuccessful
 #
 read_reason:				# entrance
 	.word	0			# entry mask
 	movab	reason_handler,(fp)	# set up the condition handler
 	tstb	(r2)			# touch the location
 	movl	$1,r0			# indicate a successful read
 	ret				# return
 #
 #	reason_handler - condition handler for reason routines
 #
 #		parameters:	p1 = signal array location
 #				p2 = mechanism array location
 #
 #		returns with 	r0 = condition response
 #
 reason_handler:				# entrance
 	.word	0			# entry mask
 	movq	4(ap),r0		# r0 and r1 = location of arrays
 	tstl	8(r1)			# condition from establisher frame ?
 	bneq	1f			# no - bypass

 # 	cmpcond	ss$_accvio,4(r0)	# access violation condition ?
	 cmpzv	$3,$26,4(r0),$ss$_accvio<<-3
 	bneq	1f			# no - bypass
 	clrl	12(r1)			# return zero status in r0
 	movl	8(r0),16(r1)		# return the reason mask in r1
 	clrq	-(sp)			# default pc and level for unwind
 	calls	$2,*$exe$unwind		# unwind the reason routine frame
 
 1:	cvtwl	$ss$_resignal,r0	# specify condition not handled
 	ret				# return
 #

 #
 #	write_fault - process a write access violation fault
 #
 #		entered by subroutine branching
 #
 #		parameters:	r10 = size of area being written
 #				r11 = location of area being written
 #
 write_fault:				# entrance
 	pushr	$0x7			# save r0,r1,r2
 	movl	r11,r2			# r2 = probed address
 	probew	mode(fp),$1,(r2)	# is the first byte writeable ?
 
 	beql	1f			# no - bypass
 	probew	mode(fp),$1,-1(r2)[r10]	# is the last byte writeable ?
 
 	bneq	1f			# yes - bypass
 	movab	-1(r2)[r10],r2		# r2 = address of last byte
 	bicw2	$511,r2			# compute address of first bad byte
 1:	calls	$0,write_reason	# get the reason mask
 	blbs	r0,2f			# the write went all right - bypass
 	bsbw	fault_reset		# reinitialize registers and clear tp
 	movab	short_local(fp),sp	# shorten the frame
 	pushl	r2			# push the bad address
 	pushl	r1			# push the reason mask
 	pushl	$ss$_accvio		# push the condition code
 	pushl	$3			# push the number of arguments
 	brw	signal_start		# signal the condition
 2:	popr	$0x07			# restore r0,r1,r2
 	rsb				# get back
 #
 #	write_reason - get the reason mask for write access violation
 #
 #		parameter:	r2 = address for which probe failed
 #
 #		returns with	r0 = status of access attempt
 #				r1 = reason mask if unsuccessful
 #
 write_reason:				# entrance
 	.word	0			# entry mask
 	movab	reason_handler,(fp)	# set up the condition handler
 	addb2	$0,(r2)			# try to change the location
 	movl	$1,r0			# indicate a successful write
 	ret				# return
 #

 #
 #	opcode_fault - process an opcode reserved to digital fault
 #
 #		entered by branching
 #
 #		no parameters
 #
 opcode_fault:				# entrance
 	bsbw	fault_reset		# reinitialize registers and clear tp
 	movab	short_local(fp),sp	# shorten the frame
 	movzwl	$ss$_opcdec,-(sp)	# push the condition code
 	pushl	$1			# push the number of arguments
 	brw	signal_start		# signal the condition
 #
 #	address_fault - process an invalid addressing mode fault
 #
 #		entered by branching
 #
 #		no parameters
 #
 address_fault:				# entrance
 	bsbw	fault_reset		# reinitialize registers and clear tp
 	movab	short_local(fp),sp	# shorten the frame
 	movzwl	$ss$_radrmod,-(sp)	# push the condition code
 	pushl	$1			# push the number of arguments
 	brw	signal_start		# signal the condition
 #
 #	operand_fault - processed a reserved operand fault
 #
 #		entered by branching
 #	
 #		no parameters
 #
 operand_fault:				# entrance
 	bsbw	fault_reset		# reinitialize registers and clear tp
 	movab	short_local(fp),sp	# shorten the frame
 	movzwl	$ss$_roprand,-(sp)	# push the condition code
 	pushl	$1			# push the number of arguments
 	brw	signal_start		# signal the condition
 #
 #	underflow - process a floating underflow fault
 #
 #		entered by branching
 #
 #		no parameters
 #
 underflow:				# entrance
 	bsbw	fault_reset		# reinitialize registers and clear tp
 	movab	short_local(fp),sp	# shorten the frame
 	movzwl	$ss$_fltund_f,-(sp)	# push the condition code
 	pushl	$1			# push the number of arguments
 	brw	signal_start		# signal the condition
 #
 #	overflow - process a floating overflow fault
 #
 #		entered by branching
 #

 #		no parameters
 #
 overflow:				# entrance
 	bsbw	fault_reset		# reinitialize registers and clear tp
 	movab	short_local(fp),sp	# shorten the frame
 	movzwl	$ss$_fltovf_f,-(sp)	# push the condition code
 	pushl	$1			# push the number of arguments
 	brw	signal_start		# signal the condition
 #
 #	divide_fault - process a floating divide by zero fault
 #
 #		entered by branching
 #
 #		no parameters
 #
 divide_fault:				# entrance
 	bsbw	fault_reset		# reinitialize registers and clear tp
 	movab	short_local(fp),sp	# shorten the frame
 	movzwl	$ss$_fltdiv_f,-(sp)	# push the condition code
 	pushl	$1			# push the number of arguments
 	brw	signal_start		# signal the condition
 #
 #	int_overflow - process an integer overflow trap
 #
 #		entered by branching
 #
 #		no parameters
 #
 int_overflow:				# entrance
 	movab	short_local(fp),sp	# shorten the frame
 	movzwl	$ss$_intovf,-(sp)	# push the condition code
 	pushl	$1			# push the number of arguments
 	brw	signal_start		# signal the condition
 #

 #
 #	fault_reset - perform reinitialization operations for a fault
 #
 #		entered by subroutine branching
 #	
 #		no parameters
 #
 #	discussion
 #
 #	    this routine subtracts the sign-extended value of each
 #	of the register modification bytes from the corresponding
 #	emulated register and clears the trace pending bit in the
 #	psl.
 #
 fault_reset:				# entrance
 	clrl	r0			# clear the index
 1:	cvtbl	regmod_r0(fp)[r0],r1	# r1 = modifications to r[r0]
 	subl2	r1,reg_r0(fp)[r0]	# unmodify the register
 	aobleq	$15,r0,1b		# more registers to reset - loop
 	bbcc	$psl_tp,psl(fp),2f	# clear the trace pending bit
 2:	rsb				# return
 #

 #
 #	signal_start - build the parameter blocks for signal
 #
 #		entered by branching
 #
 #		parameters:	(sp) = truncated signal array size (m)
 #				4(sp) = condition code
 #				8(sp) = first signal argument
 #				  .
 #				  .
 #				  .
 #				4*<m-1>(sp) = last signal argument
 #
 #	discussion
 #
 #	    this routine builds the signal and mechanism arrays
 #	for a condition generated by the emulator. it is entered
 #	with the signal array for the condition except for the 
 #	pc and psl pair pushed onto the emulator's stack (with the
 #	pushed array length correspondingly shortened). the signal
 #	array, mechanism array, and the handler parameter block
 #	are then constructed on the user's emulated stack. the routine
 #	then removes the emulator frame from the stack and enters
 #	the signal dispatching loop at signal.
 #
 #	notes:	1. the precise format of the information pushed onto
 #		   the user's stack is given in the description of
 #		   signal below.
 #
 #		2. the method of getting out of the emulator used in
 #		   this routine is essentially the same as that used
 #		   in normal_exit.
 #
 signal_start:				# entrance
 	movl	(sp)+,r7		# r7 = number of signal parameters
 	ashl	$2,r7,r8		# r8 = size of the signal parameters
 	addl3	$52,r8,r0		# r0 = size of signal information
 	bsbw	test_frame		# make sure we have room for it
 	movl	reg_sp(fp),r6		# r6 = user's stack pointer
 	movq	reg_pc(fp),-(r6)	# push the pc, psl pair
 	subl2	r8,r6			# make room for the signal parameters
 	movc3	r8,(sp),(r6)		# push the signal parameters
 	addl3	$2,r7,-(r6)		# push the signal array length
 	movl	$1,-(r6)		# push code for signal (vs. stop)
 	movq	reg_r0(fp),-(r6)	# push user's r0 and r1
 	mnegl	$3,-(r6)		# push -3 (depth number)
 	movl	reg_fp(fp),-(r6)	# push the user's fp
 	movl	$4,-(r6)		# push the mechanism array length
 	movl	r6,-(r6)		# push the mechanism array location
 	movab	28(r6),-(r6)		# push the signal array location
 	movl	$2,-(r6)		# push the handler parameter count
 	movq	reg_ap(fp),save_ap(fp)	# put the user's pc, psl pair back
 	movab	signal,save_pc(fp)	# store the return point
 	movab	frame_end+4(fp),r0	# r0 = location of end of frame
 	subl2	r0,r6			# r6 = distance of user sp from it
 	extzv	$0,$2,r6,r1		# r1 = stack alignment
 

 	insv	r1,$mask_align,$2,save_mask(fp) # store it into the frame
 
 	addl2	r1,r0			# compute the parameter area location
 	ashl	$-2,r6,-4(r0)		# store the parameter count
 
 	ret				# return (to signal)
 #

 #
 #	signal - signal the condition
 #
 #		entered by branching
 #
 #		parameters:	( described in note 3 )
 #	
 #	discussion
 #
 #		   following is a description of the information which
 #		   is assumed to be pushed onto the stack when the
 #		   routine signal is entered. the values are all
 #		   longwords.
 #
 #		   handler parameter block:
 #
 #			(sp)	2 (handler parameter block length)
 #			4(sp)	signal array location
 #			8(sp)	mechanism array location
 #
 #		   mechanism array:
 #
 #			12(sp)	4 (mechanism array length)
 #			16(sp)  user's fp (establisher frame)
 #			20(sp)	-3 (establisher depth)
 #			24(sp)	user's r0
 #			28(sp)	user's r1
 #
 #		   information not part of any array:
 #
 #			32(sp)	1 (code for signal rather than stop)
 #
 #		   signal array:
 #
 #			36(sp)	signal array length m
 #			40(sp)	condition code
 #			44(sp)	first signal argument
 #			  .
 #			  .
 #			  .
 #			<4*m>+28(sp) last signal argument
 #			<4*m>+32(sp) user's pc
 #			<4*m>+36(sp) user's psl
 #
 #		   the user's stack pointer should coincide with the
 #		   address <4*m>+40(sp).
 #
 #	we now jump to the special entry point in vms to start
 #	the search for handlers.  execution will not return to us.
 #-
 
 signal: 				# entrance
 	jmp	*$exe$srchandler
 

 #	************************************************************************
 #	*								       *
 #	*								       *
 #	*	   end of emulate$ vax instruction subset emulator	       *
 #	*								       *
 #	*								       *
 #	************************************************************************
 

