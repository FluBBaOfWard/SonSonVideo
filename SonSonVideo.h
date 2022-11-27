// SonSon Video Chip emulation

#ifndef SONSONVIDEO_HEADER
#define SONSONVIDEO_HEADER

#ifdef __cplusplus
extern "C" {
#endif

/** Game screen height in pixels */
#define GAME_HEIGHT (240)
/** Game screen width in pixels */
#define GAME_WIDTH  (240)

typedef struct {
	u32 scanline;
	u32 nextLineChange;
	u32 lineState;

	u32 frameIrqFunc;
	u32 latchIrqFunc;

// sonVRegs						// 0-4
	u8 scrollXReg;				// Scroll X
	u8 flipReg;					// Flip screen
	u8 latchReg;				// Sound latch
	u8 padding0[1];

	u8 chrMemReload;
	u8 sprMemReload;
	u8 padding1[2];

	u32 chrMemAlloc;
	u32 sprMemAlloc;

	u32 chrRomBase;
	u32 chrGfxDest;
	u32 spriteRomBase;

	u8 dirtyTiles[4];
	u8 *gfxRAM;
	u32 chrBlockLUT[512];
	u32 bgBlockLUT[512];
	u32 sprBlockLUT[512];
} SonVideo;

void sonVideoReset(void *frameIrqFunc(), void *latchIrqFunc());

/**
 * Saves the state of the SonVideo chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The SonVideo chip to save.
 * @return The size of the state.
 */
int sonSaveState(void *destination, const SonVideo *chip);

/**
 * Loads the state of the SonVideo chip from the source.
 * @param  *chip: The SonVideo chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int sonLoadState(SonVideo *chip, const void *source);

/**
 * Gets the state size of a SonVideo.
 * @return The size of the state.
 */
int sonGetStateSize(void);

void convertChrTileMap(void *destination);
void convertSpritesSonSon(void *destination);
void doScanline(void);

#ifdef __cplusplus
}
#endif

#endif // SONSONVIDEO_HEADER
