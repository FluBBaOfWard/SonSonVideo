// SonSon Video Chip emulation

#ifdef __arm__

#ifdef GBA
#include "../Shared/gba_asm.h"
#elif NDS
#include "../Shared/nds_asm.h"
#endif
#include "../Shared/EmuSettings.h"
#include "SonSonVideo.i"

	.global sonVideoInit
	.global sonVideoReset
	.global sonSaveState
	.global sonLoadState
	.global sonGetStateSize
	.global doScanline
	.global copyScrollValues
	.global convertChrTileMap
	.global convertSpritesSonSon
	.global sonLatchR
	.global sonScrollXW
	.global sonLatchW
	.global sonFlipW


	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
sonVideoInit:				;@ Only need to be called once
;@----------------------------------------------------------------------------
	mov r1,#0xffffff00			;@ Build bg tile decode tbl
	ldr r2,=CHR_DECODE
ppi:
	ands r0,r1,#0x01
	movne r0,#0x10000000
	tst r1,#0x02
	orrne r0,r0,#0x01000000
	tst r1,#0x04
	orrne r0,r0,#0x00100000
	tst r1,#0x08
	orrne r0,r0,#0x00010000
	tst r1,#0x10
	orrne r0,r0,#0x00001000
	tst r1,#0x20
	orrne r0,r0,#0x00000100
	tst r1,#0x40
	orrne r0,r0,#0x00000010
	tst r1,#0x80
	orrne r0,r0,#0x00000001
	str r0,[r2],#4
	adds r1,r1,#1
	bne ppi

	bx lr
;@----------------------------------------------------------------------------
sonVideoReset:				;@ r0=frameIrqFunc, r1=latchIrqFunc, r2=ram
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r2,lr}

	mov r0,sonptr
	ldr r1,=sonVideoSize/4
	bl memclr_					;@ Clear VDP state

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#-1
	stmia sonptr,{r0-r2}		;@ Reset scanline, nextChange & lineState

//	mov r0,#-1
	str r0,[sonptr,#gfxReload]

	ldmfd sp!,{r0-r2,lr}
	cmp r0,#0
	adreq r0,dummyIrqFunc
	cmp r1,#0
	adreq r1,dummyIrqFunc
	str r0,[sonptr,#frameIrqFunc]
	str r1,[sonptr,#latchIrqFunc]
	str r2,[sonptr,#gfxRAM]

dummyIrqFunc:
	bx lr

;@----------------------------------------------------------------------------
sonSaveState:			;@ In r0=destination, r1=sonptr. Out r0=state size.
	.type   sonSaveState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r1				;@ Store sonptr (r1)
	mov r4,r0				;@ Store destination

	ldr r1,[r5,#gfxRAM]
	mov r2,#0x1800
	bl memcpy

	add r0,r4,#0x1800
	ldr r1,[r5,#gfxRAM]
	add r1,r1,#0x2000		;@ Sprite ram offset
	mov r2,#0x60
	bl memcpy

	ldr r0,=0x1860
	add r0,r4,r0
	add r1,r5,#sonVideoRegs
	mov r2,#4
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x1864
	bx lr
;@----------------------------------------------------------------------------
sonLoadState:			;@ In r0=sonptr, r1=source. Out r0=state size.
	.type   sonLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r0				;@ Store sonptr (r0)
	mov r4,r1				;@ Store source

	ldr r0,[r5,#gfxRAM]
	mov r2,#0x1800
	bl memcpy

	ldr r0,[r5,#gfxRAM]
	add r0,r0,#0x2000		;@ Sprite ram offset
	add r1,r4,#0x1800
	mov r2,#0x60
	bl memcpy

	add r0,r5,#sonVideoRegs
	ldr r1,=0x1860
	add r1,r4,r1
	mov r2,#4
	bl memcpy

	mov r0,#-1
	str r0,[r5,#gfxReload]
	mov sonptr,r5			;@ Restore sonptr (r12)
	bl endFrame

	ldmfd sp!,{r4,r5,lr}
;@----------------------------------------------------------------------------
sonGetStateSize:		;@ Out r0=state size.
	.type   sonGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	ldr r0,=0x1864
	bx lr

;@----------------------------------------------------------------------------
#ifdef GBA
	.section .ewram,"ax"
	.align 2
#endif
;@----------------------------------------------------------------------------
sonLatchR:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#0
	mov lr,pc
	ldr pc,[sonptr,#latchIrqFunc]
	ldrb r0,[sonptr,#latchReg]
	ldmfd sp!,{lr}
	bx lr
;@----------------------------------------------------------------------------
sonScrollXW:				;@ Register 0
;@----------------------------------------------------------------------------
	strb r0,[sonptr,#scrollXReg]
	bx lr
;@----------------------------------------------------------------------------
sonLatchW:					;@ Register 0x10
;@----------------------------------------------------------------------------
	strb r0,[sonptr,#latchReg]
	mov r0,#1
	ldr pc,[sonptr,#latchIrqFunc]
;@----------------------------------------------------------------------------
sonFlipW:					;@ Register 0x18
;@----------------------------------------------------------------------------
	strb r0,[sonptr,#flipReg]
//	tst r0,#0x01				;@ Screen flip bit
	bx lr

;@----------------------------------------------------------------------------
reloadChrTiles:
;@----------------------------------------------------------------------------
	mov r0,#1<<(CHRDSTTILECOUNTBITS-CHRGROUPTILECOUNTBITS)
	str r0,[sonptr,#chrMemAlloc]
	mov r1,#1<<(32-CHRGROUPTILECOUNTBITS)		;@ r1=value
	strb r1,[sonptr,#chrMemReload]	;@ Clear bg mem reload.
	mov r0,r9					;@ r0=destination
	mov r2,#CHRBLOCKCOUNT		;@ 512 tile entries
	b memset_					;@ Prepare LUT
;@----------------------------------------------------------------------------
convertChrTileMap:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}
	add r6,r0,#0x40				;@ Destination, skip first row

	ldr r9,=chrBlockLUT
	add r9,r9,sonptr
	ldrb r0,[sonptr,#chrMemReload]
	cmp r0,#0
	blne reloadChrTiles

	ldr r4,[sonptr,#gfxRAM]
	add r4,r4,#0x1000
	add r4,r4,#0x20				;@ Skip first row

	bl chrMapRender
	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
checkFrameIRQ:
;@----------------------------------------------------------------------------
	mov r0,#1
	ldr pc,[sonptr,#frameIrqFunc]
;@----------------------------------------------------------------------------
disableFrameIRQ:
;@----------------------------------------------------------------------------
	mov r0,#0
	ldr pc,[sonptr,#frameIrqFunc]
;@----------------------------------------------------------------------------
frameEndHook:
;@----------------------------------------------------------------------------
	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#0
	stmia sonptr,{r0-r2}		;@ Reset scanline, nextChange & lineState

//	mov r0,#0					;@ Must return 0 to end frame.
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
newFrame:					;@ Called before line 0
;@----------------------------------------------------------------------------
	bx lr

;@----------------------------------------------------------------------------
lineStateTable:
	.long 0, newFrame			;@ zeroLine
	.long 239, endFrame			;@ Last visible scanline
	.long 240, checkFrameIRQ	;@ frameIRQ on
	.long 264, disableFrameIRQ	;@ frameIRQ off
	.long 265, frameEndHook		;@ totalScanlines
;@----------------------------------------------------------------------------
#ifdef NDS
	.section .itcm						;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2
;@----------------------------------------------------------------------------
redoScanline:
	ldmfd sp!,{lr}
;@----------------------------------------------------------------------------
doScanline:
;@----------------------------------------------------------------------------
	ldmia sonptr,{r1,r2}		;@ Read scanLine & nextLineChange
	subs r0,r1,r2
	addmi r1,r1,#1
	strmi r1,[sonptr,#scanline]
	bxmi lr
;@----------------------------------------------------------------------------
executeScanline:
;@----------------------------------------------------------------------------
	ldr r2,[sonptr,#lineState]
	ldmia r2!,{r0,r1}
	stmib sonptr,{r1,r2}		;@ Write nextLineChange & lineState
	stmfd sp!,{lr}
	adr lr,redoScanline
	bx r0

;@----------------------------------------------------------------------------
chrMapRender:
	stmfd sp!,{lr}

	mov r7,#32*30				;@ Skip top and bottom row
chrTrLoop1:
	ldrb r5,[r4,#0x400]			;@ Read from SonSon Colormap RAM, cccccctt -> ccccxytt
	ldrb r0,[r4],#1				;@ Read from SonSon Charmap RAM,  tttttttt

	mov r5,r5,ror#2
	orr r0,r0,r5,lsr#22
	mov r1,r5,lsr#4
	orr r0,r0,r1,lsl#10			;@ Use top color bits as extra tile bits

	bl getCharsFromCache
	orr r0,r0,r5,lsl#12			;@ Palette

	strh r0,[r6],#2				;@ Write to NDS Tilemap RAM

	subs r7,r7,#1
	bne chrTrLoop1

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
charCacheFull:
	strb r2,[sonptr,#chrMemReload]
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
getCharsFromCache:			;@ Takes tile# in r0, returns new tile# in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#CHRGROUPTILECOUNTBITS		;@ Mask tile number
	bic r0,r0,r1,lsl#CHRGROUPTILECOUNTBITS
	ldr r2,[r9,r1,lsl#2]		;@ Check cache, uncached = 0x10000000
	orrs r0,r0,r2,lsl#CHRGROUPTILECOUNTBITS
	bxcc lr						;@ Allready cached
allocChars:
	ldr r2,[sonptr,#chrMemAlloc]
	subs r2,r2,#1
	bmi charCacheFull
	str r2,[sonptr,#chrMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r0,r2,lsl#CHRGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
renderChars:
	stmfd sp!,{r0,r4-r8,lr}
	ands r7,r1,#0x180			;@ Check color top bits
	beq noExtCol
	cmp r7,#0x100
	ldrmi r7,=0x44444444
	ldreq r7,=0x88888888
	ldrhi r7,=0xCCCCCCCC
noExtCol:
	bic r1,r1,#0x180
	ldr r6,=CHR_DECODE
#ifdef ARM9
	ldrd r4,r5,[sonptr,#chrRomBase]
#else
	ldr r4,[sonptr,#chrRomBase]
	ldr r5,[sonptr,#chrGfxDest]
#endif
	add r4,r4,r1,lsl#CHRGROUPTILECOUNTBITS+3
	add r5,r5,r2,lsl#CHRGROUPTILECOUNTBITS+5
	add r3,r4,#0x2000

renderCharsLoop:
	ldrb r0,[r4],#1				;@ Read 1st plane.
	ldrb r1,[r3],#1				;@ Read 2nd plane.
	ldr r0,[r6,r0,lsl#2]
	ldr r1,[r6,r1,lsl#2]
	orr r0,r0,r1,lsl#1
	orr r0,r0,r7
	str r0,[r5],#4

	tst r5,#0xfc				;@ #0x80 8 8x8 tiles
	bne renderCharsLoop

	ldmfd sp!,{r0,r4-r8,pc}
;@----------------------------------------------------------------------------
copyScrollValues:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,lr}

	mov r1,#5
	mov r3,#0
	bl scrollCopier
	mov r1,#0x1C
	ldrb r3,[sonptr,#scrollXReg]
	bl scrollCopier
	ldmfd sp!,{r4,pc}

scrollCopier:
	mov r2,r3
setScrlLoop:
	stmia r0!,{r2,r3}
	stmia r0!,{r2,r3}
	stmia r0!,{r2,r3}
	stmia r0!,{r2,r3}
	subs r1,r1,#1
	bne setScrlLoop
	bx lr

;@----------------------------------------------------------------------------
reloadSprites:
;@----------------------------------------------------------------------------
	mov r1,#1<<(32-SPRGROUPTILECOUNTBITS)	;@ r1=value
	strb r1,[sonptr,#sprMemReload]			;@ Clear spr mem reload.
	mov r0,r9								;@ r0=destination
	mov r2,#SPRBLOCKCOUNT					;@ Number of tile entries
	b memset_								;@ Prepare LUT
;@----------------------------------------------------------------------------
	.equ PRIORITY,	0x800		;@ 0x800=AGB OBJ priority 2
;@----------------------------------------------------------------------------
convertSpritesSonSon:		;@ In r0 = destination.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	mov r11,r0					;@ Destination
	mov r8,#24					;@ Number of sprites
//	ldrb r0,[sonptr,#scrollXReg+1]
//	tst r0,#0x80				;@ Sprites enabled?
//	beq dm7

	ldr r9,=sprBlockLUT
	add r9,r9,sonptr
	ldrb r0,[sonptr,#sprMemReload]
	cmp r0,#0
	blne reloadSprites

	ldr r10,[sonptr,#gfxRAM]
	add r10,r10,#0x2000

	ldr r7,=gScaling
	ldrb r7,[r7]
	cmp r7,#UNSCALED			;@ Do autoscroll
	ldreq r7,=0x01000000		;@ No scaling
//	ldrne r7,=0x00DB6DB6		;@ 192/224, 6/7, scaling. 0xC0000000/0xE0 = 0x00DB6DB6.
//	ldrne r7,=0x00B6DB6D		;@ 160/224, 5/7, scaling. 0xA0000000/0xE0 = 0x00B6DB6D.
	ldrne r7,=(SCREEN_HEIGHT<<21)/(GAME_HEIGHT>>3)		;@ 192/240, 4/5, scaling. 0xC0000000/0xF0 = 0x00DB6DB6.
	mov r6,#0
	ldreq r6,=yStart			;@ First scanline?
	ldrbeq r6,[r6]
//	add r6,r6,#0x08

	mov r5,#0x60000000			;@ 16x16 size + X-flip?
	orrne r5,r5,#0x0100			;@ Scaling

//	ldrb r4,[sonptr,#irqControl]
//	tst r4,#0x08				;@ Flip enabled?
//	orrne r5,#0x30000000		;@ flips
//	rsbne r7,r7,#0
//	rsbne r6,r0,#0xE8

dm5:
	ldr r4,[r10],#4				;@ SonSon OBJ, r4=Xpos,Tile,Attrib,Ypos.
	and r0,r4,#0xFF				;@ Mask Y
	cmp r0,#0xF8				;@ Check yPos 0
	beq skipSprite
	subpl r0,r0,#0x100			;@ Make negative.

	mov r1,r4,lsr#24			;@ XPos
	cmp r1,#0xF8				;@ Check xPos 0
	beq skipSprite
	eorpl r1,r1,#0x100			;@ Make negative.
//	tst r7,#0x80000000			;@ Is scaling negative (flip)?
	add r1,r1,#(SCREEN_WIDTH-256)/2
//	rsbne r1,r1,#(GAME_WIDTH-16)-(GAME_WIDTH-SCREEN_WIDTH)/2			;@ Flip Xpos
	mov r1,r1,lsl#23

	sub r0,r0,r6
	mul r0,r7,r0				;@ Y scaling
	sub r0,r0,#0x08000000		;@ -8
	add r0,r5,r0,lsr#24			;@ YPos + size + scaling
	orr r0,r0,r1,lsr#7			;@ XPos

	and r1,r4,#0x0000C000		;@ X/Yflip
	eor r0,r0,r1,lsl#14
	str r0,[r11],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	and r0,r4,#0xFF0000
	tst r4,#0x002000			;@ Tile bit 8
	orrne r0,r0,#0x1000000
	tst r4,#0x000100			;@ Use color bit 0 as extra tile nr
	orrne r0,r0,#0x2000000
	mov r0,r0,lsr#14			;@ Convert 16x16 tile nr to 8x8 tile nr.
	bl getSpriteFromCache		;@ Jump to spr copy, takes tile# in r0, gives new tile# in r0

	and r1,r4,#0x1E00			;@ Color
	orr r0,r0,r1,lsl#3
	orr r0,r0,#PRIORITY			;@ Priority
	strh r0,[r11],#4			;@ Store OBJ Atr 2. Pattern, prio & palette.
dm3:
	subs r8,r8,#1
	bne dm5
	ldmfd sp!,{r4-r11,pc}
skipSprite:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	b dm3

dm7:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	subs r8,r8,#1
	bne dm7
	ldmfd sp!,{r4-r11,pc}

;@----------------------------------------------------------------------------
spriteCacheFull:
	strb r2,[sonptr,#sprMemReload]
	mov r2,#1<<(SPRDSTTILECOUNTBITS-SPRGROUPTILECOUNTBITS)
	str r2,[sonptr,#sprMemAlloc]
	ldmfd sp!,{r4-r11,pc}
;@----------------------------------------------------------------------------
getSpriteFromCache:			;@ Takes tile# in r0, returns new tile# in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#SPRGROUPTILECOUNTBITS
	bic r0,r0,r1,lsl#SPRGROUPTILECOUNTBITS
	ldr r2,[r9,r1,lsl#2]
	orrs r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS		;@ Check cache, uncached = 0x20000000
	bxcc lr										;@ Allready cached
alloc16x16x2:
	ldr r2,[sonptr,#sprMemAlloc]
	subs r2,r2,#1
	bmi spriteCacheFull
	str r2,[sonptr,#sprMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
do16:
	stmfd sp!,{r0,r4-r8,lr}
	ldr r6,=CHR_DECODE
	ldr r0,=SPRITE_GFX			;@ r0=GBA/NDS SPR tileset
	add r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS+5	;@ x 128 bytes x 4 tiles x 2

	tst r1,#0x100
	bic r1,r1,#0x100
	ldr r2,[sonptr,#spriteRomBase]
	add r2,r2,r1,lsl#SPRGROUPTILECOUNTBITS+3 	;@ x 8 bytes x 4 tiles x 2
	add r3,r2,#0x4000
	add r4,r2,#0x8000
	bne spr16Loop2

spr16Loop:
	ldrb r1,[r2],#1				;@ Read 1st plane.
	ldrb r5,[r3],#1				;@ Read 2nd plane.
	ldr r1,[r6,r1,lsl#2]
	ldr r5,[r6,r5,lsl#2]
	orr r1,r1,r5,lsl#1
	ldrb r5,[r4],#1				;@ Read 3rd plane.
	ldr r5,[r6,r5,lsl#2]
	orr r1,r1,r5,lsl#2
	str r1,[r0],#4

	tst r0,#0x1c
	bne spr16Loop

	tst r0,#0x20
	addne r2,r2,#0x08
	addne r3,r3,#0x08
	addne r4,r4,#0x08
	bne spr16Loop

	tst r0,#0x40
	subne r2,r2,#0x10
	subne r3,r3,#0x10
	subne r4,r4,#0x10
	bne spr16Loop

	tst r0,#0x80				;@ Allways 2 16x16 tiles
	bne spr16Loop

	ldmfd sp!,{r0,r4-r8,pc}

spr16Loop2:
	ldrb r1,[r2],#1				;@ Read 1st plane.
	ldrb r5,[r3],#1				;@ Read 2nd plane.
	ldr r1,[r6,r1,lsl#2]
	orr r1,r1,r1,lsl#3
	ldr r5,[r6,r5,lsl#2]
	orr r1,r1,r5,lsl#1
	orr r1,r1,r5,lsl#3
	ldrb r5,[r4],#1				;@ Read 3rd plane.
	ldr r5,[r6,r5,lsl#2]
	orr r1,r1,r5,lsl#2
	orr r1,r1,r5,lsl#3
	str r1,[r0],#4

	tst r0,#0x1c
	bne spr16Loop

	tst r0,#0x20
	addne r2,r2,#0x08
	addne r3,r3,#0x08
	addne r4,r4,#0x08
	bne spr16Loop

	tst r0,#0x40
	subne r2,r2,#0x10
	subne r3,r3,#0x10
	subne r4,r4,#0x10
	bne spr16Loop

	tst r0,#0x80				;@ Allways 2 16x16 tiles
	bne spr16Loop

	ldmfd sp!,{r0,r4-r8,pc}

;@----------------------------------------------------------------------------

#ifdef GBA
	.section .sbss				;@ For the GBA
#else
	.section .bss
#endif
CHR_DECODE:
	.space 0x400

#endif // #ifdef __arm__
