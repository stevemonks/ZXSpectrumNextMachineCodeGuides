; This is a basic template file for writing Spectrum code.
; It configures the assembler and jumps to the code.

AppFilename             equ "simpletilemapwithattr"     ; What we're called (for file generation)

AppFirst                equ $6000                       ; First byte of code

                        zeusemulate "Next","RAW"        ; Set the model


; Start planting code here. (When generating a tape file we start saving from here)

                        org AppFirst            ; Start of application
AppFirst:                                       ; First byte of code
tile_map_data:          ds 1280*2               ; reserve space for the 40x32x2 tilemap used by the hardware

; tile map patterns - these must start at a 256 byte aligned address.
; for convenience I'm sticking them immediately after the tilemap buffer
; which is 5x256 byte pages
; Note the tile patterns mustn't run beyond bank 5 (> $7fff) as the hardware
; will wrap back to the ULA screen.

tile_map_patterns:
                        include "multi_palette_tiles_rg.s" ; tiles 256 byte aligned immediately following tile map

AppEntry                nop                     ; start of executable code

                        include "simpletilemapwithattr.s"
                        include "multi_palette_tiles_rg_palette.s"
                        include "multi_palette_tiles_by_palette.s"
                        include "multi_palette_tiles_mw_palette.s"
                        include "multi_palette_tiles_lgc_palette.s"
                        jp AppEntry


; Stop planting code after this. (When generating a tape file we save bytes below here)
AppLast                 equ *-1                         ; The last used byte's address

; Generate some useful debugging commands

                        profile AppFirst,AppLast-AppFirst+1     ; Enable profiling for all the code

; Setup the emulation registers, so Zeus can emulate this code correctly

Zeus_PC                 equ AppEntry                            ; Tell the emulator where to start
Zeus_SP                 equ $FF40                               ; Tell the emulator where to put the stack

; These generate some output files

if zeusver >= 78
; for versions of Zeus that support it, output a .nex file as this is the preferred
; format for the Next.
                        output_nex AppFilename+".nex",Zeus_SP,Zeus_PC
else
; If using an older version output an snx file. This is essentially a SNA or Snapshot file,
; a standard Spectrum archive format. Attempting to load one of these on a ZX Spectrum Next
; disables all of the enhanced Next hardware to aid with compatibility, but using the SNX
; extension enables the Next's advanced hardware.
                        output_sna AppFilename+".snx"
endif
