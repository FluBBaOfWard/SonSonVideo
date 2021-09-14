;@ ASM header for the SonSon Video emulator
;@

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (240)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (240)

	.equ CHRSRCTILECOUNTBITS,	12
	.equ CHRDSTTILECOUNTBITS,	10
	.equ CHRGROUPTILECOUNTBITS,	3
	.equ CHRBLOCKCOUNT,			(1<<(CHRSRCTILECOUNTBITS - CHRGROUPTILECOUNTBITS))
	.equ CHRTILESIZEBITS,		4

	.equ SPRSRCTILECOUNTBITS,	12
	.equ SPRDSTTILECOUNTBITS,	10
	.equ SPRGROUPTILECOUNTBITS,	3
	.equ SPRBLOCKCOUNT,			(1<<(SPRSRCTILECOUNTBITS - SPRGROUPTILECOUNTBITS))
	.equ SPRTILESIZEBITS,		5

	sonptr		.req r12
						;@ SonSonVideo.s
	.struct 0
scanline:		.long 0			;@ These 3 must be first in state.
nextLineChange:	.long 0
lineState:		.long 0

frameIrqFunc:	.long 0
latchIrqFunc:	.long 0

sonVideoState:					;@
sonVideoRegs:					;@ 0-4
scrollXReg:		.byte 0			;@
flipReg:		.byte 0			;@
latchReg:		.byte 0			;@
padding0:		.space 1

gfxReload:
chrMemReload:	.byte 0
sprMemReload:	.byte 0
padding1:		.space 2

chrMemAlloc:	.long 0
sprMemAlloc:	.long 0

chrRomBase:		.long 0
chrGfxDest:		.long 0
spriteRomBase:	.long 0

dirtyTiles:		.byte 0,0,0,0
gfxRAM:			.long 0
chrBlockLUT:	.space CHRBLOCKCOUNT*4
sprBlockLUT:	.space SPRBLOCKCOUNT*4

sonVideoSize:

;@----------------------------------------------------------------------------
