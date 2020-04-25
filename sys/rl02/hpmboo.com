!
! Load 'boot.' and boot the ULTRIX operating system.
!
! 'hp' MASSBUS drive type boot to multi user mode
!
!
SET SNAP ON		! Enable ERROR_HALT snapshots
SET FBOX OFF		! Ultrix will turn on Fbox
INIT			! SRM processor init
UNJAM 			! UNJAM SBIA's and enable master sbia interrupts
INIT/PAMM		! INIT physical address memory map
DEPOSIT CSWP 8		! Turn off the cache - Ultrix will enable cache

DEPOSIT R10 2000	! 'hp' drive 0 massbus 4 (first on sbia1)
DEPOSIT R11 0		! Software boot flags (multi user mode)

LOAD/START:0 BOOT.	! Load 'boot.' at memory location 0
START 2			! Start 'boot.' at the address 2