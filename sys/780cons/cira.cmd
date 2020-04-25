!
!	CI PORT BOOT COMMAND FILE - CIRA.COM
!	BOOT FROM CI 
!
! THE DESIRED STATION ADDRESS OF REMOTE PORT MUST BE SET IN REGISTER 2
!	AND
! THE UNIT NUMBER MUST BE SET IN REGISTER 3 BEFORE EXECUTING THIS PROCEDURE.
!
HALT			! HALT PROCESSOR
UNJAM			! UNJAM SBI
INIT			! INIT PROCESSOR
DEPOSIT/I 11 20003800	! SET UP SCBB
DEPOSIT R0 20		! CI PORT DEVICE
DEPOSIT	R1 E		! CI TR=E
DEPOSIT R4 0		! BOOT BLOCK LBN (UNUSED)
DEPOSIT R5 1000B	! SOFTWARE BOOT FLAGS 
DEPOSIT FP 0		! SET NO MACHINE CHECK EXPECTED
START 20003000		! START ROM PROGRAM
WAIT DONE		! WAIT FOR COMPLETION
			! 
EXAMINE SP		! SHOW ADDRESS OF WORKING MEMORY+^X200
LOAD VMB.EXE/START:@	! LOAD PRIMARY BOOTSTRAP
START @			! AND START IT
