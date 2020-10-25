

; *****************************************************
; Register definitions - while you could just use the
; register addresses in your code, it's easier to read
; if you give them meaningful names and use those instead
; *****************************************************

TBBLUE_REGISTER_SELECT			equ $243B
TURBO_MODE_PORT equ $07                             ; $0 = 3.5MHz, $1 = 7MHz, $2 = 14MHz, $3 = 28MHz (possibly, not documented)

PALETTE_INDEX_PORT = $40            ; write index for palette
PALETTE_VALUE_PORT = $41            ; r/w value of palette at current index
PALETTE_CONTROL_PORT = $43          ; bit 7 - disable palette write auto inc
PALETTE_VALUE_9BIT_PORT equ $44                     ; r/w value of 9 bit palette at current index
PALETTE_SELECT_LAYER2_1  = %00010000

; Layer 2 Access Port
; bit   function
; 0     Write enable. (banks in 16K from $0000-$3fff or $0000-$bfff if all 3 banks are paged in)
; 1     layer 2 visible
; 2     layer 2 read only paging
; 4     Layer 2 behind spectrum screen
; 6-7   16K bank to be paged into $0000-$3ffff for writing 

LAYER2_ACCESS_PORT = $123b                  ; controls write access and enabling of layer2
LAYER2_ACCESS_DISABLE_NONE  = %00000000     ; disable layer2 screen and disable for write
LAYER2_ACCESS_DISABLE_BANK0 = %00000001     ; disable layer2 screen and select bank 0 for write
LAYER2_ACCESS_DISABLE_BANK1 = %01000001     ; disable layer2 screen and select bank 1 for write
LAYER2_ACCESS_DISABLE_BANK2 = %10000001     ; disable layer2 screen and select bank 2 for write
LAYER2_ACCESS_DISABLE_ALL   = %11000001     ; disable layer2 screen and select all 3 banks for write (address 0000-bfff)

LAYER2_ACCESS_ENABLE_NONE  = %00000010     ; enable layer2 screen but disable write access
LAYER2_ACCESS_ENABLE_BANK0 = %00000011     ; enable layer2 screen and select bank 0 for write
LAYER2_ACCESS_ENABLE_BANK1 = %01000011     ; enable layer2 screen and select bank 1 for write
LAYER2_ACCESS_ENABLE_BANK2 = %10000011     ; enable layer2 screen and select bank 2 for write
LAYER2_ACCESS_ENABLE_ALL   = %11000011     ; enable layer2 screen and select all 3 banks for write (0000-bffff)
LAYER2_ACCESS_READWRITE_ENABLE_ALL   = %11000111     ; enable layer2 screen and select all 3 banks for write (0000-bffff) and all 3 banks for read
LAYER2_RAM_BANK = $12                      ; 16K bank address where layer 2 begins, note this works with the shadowing for write mentioned above
LAYER2_SCROLL_X_PORT = $16          
LAYER2_SCROLL_Y_PORT = $17
LAYER2_CLIP_PORT = $18              ; write here to adjust clip window, 1st write=left, 2nd=right, 3rd=top, 4th=bottom

GLOBAL_TRANS_COLOUR = $14           ; 8 bit transparent colour rrrgggbb, defaults to $e3

; *****************************************************
; Macros to control Layer2
; *****************************************************

; this macro does the following;
; * makes layer 2 visible
; * enables write access to layer2 memory between $0000-$bfff
; * disables read access to layer 2 memory (restores normal operation)
ShowLayer2WriteAll macro()
    ld bc,LAYER2_ACCESS_PORT
    ld a,LAYER2_ACCESS_ENABLE_ALL
    out (c),a
    mend


; this macro does the following;
; * makes layer 2 visible
; * enables write access to layer2 memory between $0000-$bfff
; * enables read access to layer2 memory between $0000-$bfff
ShowLayer2ReadWriteAll macro()
    ld bc,LAYER2_ACCESS_PORT
    ld a,LAYER2_ACCESS_READWRITE_ENABLE_ALL
    out (c),a
    mend


; this macro does the following;
; * makes layer 2 visible
; * disables write access to layer 2 memory (restores normal operation)
; * disables read access to layer 2 memory (restores normal operation)
ShowLayer2 macro()
    ld bc,LAYER2_ACCESS_PORT
    ld a,LAYER2_ACCESS_ENABLE_NONE
    out (c),a
    mend


; this macro does the following;
; * makes layer 2 visible
; * enables write access to layer2 memory between $0000-$bfff
; * disables read access to layer 2 memory (restores normal operation)
HideLayer2WriteAll macro()
    ld bc,LAYER2_ACCESS_PORT
    ld a,LAYER2_ACCESS_DISABLE_ALL
    out (c),a
    mend


; this macro does the following;
; * makes layer 2 invisible
; * disables write access to layer 2 memory (restores normal operation)
; * disables read access to layer 2 memory (restores normal operation)
HideLayer2 macro()
    ld bc,LAYER2_ACCESS_PORT
    ld a,LAYER2_ACCESS_DISABLE_NONE
    out (c),a
    mend
    

; takes a 16K page address and assigns this to layer 2.
; the hardware will display the memory at this address
; and any read / write access to layer 2 will also be directed
; to this address.
SetLayer2Bank macro(bank)
    nextreg LAYER2_RAM_BANK,bank
    mend



; *****************************************************
; System initialisation
; *****************************************************
    nextreg TURBO_MODE_PORT, $2                     ; $07 - cpu to 28 mhz because, why not?


; *****************************************************
; Layer2 setup
; *****************************************************
    ; the global transparency colour defaults to magenta, as we're going to be
    ; drawing text in this colour, we need to set it to something else that
    ; we're not going to use.
    nextreg GLOBAL_TRANS_COLOUR,254

    ; In order to write into Layer2 we're going to page all 48K of it into
    ; address space $0000 - $bfff for writing. As this includes the system
    ; variables we need to disable interrupts while we have Layer2 paged in
    di

    ; this macro makes Layer2 invisible while we set it up,
    ; and any writes in the range $0000-$bfff will be
    ; redirected to the Layer2 memory buffer
    HideLayer2WriteAll()

    ; Fill Layer2 memory with all the colours of the palette.
    ; Each 256 pixel wide row will be filled with all 256 colours of the palette.
    proc

    ld h,0      ; start at row 0
    ld e,0      ; initial colour to fill with
    ld a,192    ; first line off end of screen
RowLp:
    ld l,0      ; start row at column 0
ColLp:
    ; because each row of Layer2 is 256 bytes wide, we can simply use a
    ; register pair as x and y coordinates (high byte = y, low byte = x).
    ; Writing to the 16 bit address formed by the register pair will set
    ; the appropriate pixel.
    ld (hl),e   ; write the current colour to the current pixel
    inc e       ; increment the colour. As there are 256 colours, this will wrap at the end of each row
    inc l       ; increment the x coordinate.
    jr nz,ColLp ; continue until we're about to go off the end of the row

    inc h       ; increment the y coordinate.
    cp a,h      ; check we've not gone off the bottom of the screen
    jr nz,RowLp

    pend

    ; now draw some text in the standard Spectrum colours
    ld bc,0     ; screen coordinates to begin at b = y, c = x
    ld de,0     ; index of colour to draw with (see table below)

DrawTextLoop:
    push bc
    push de

    ; use index to look up colour from colours table
    ld hl,colours
    ld d,0
    add hl,de
    ld a,(hl)
    ld (pen_colour),a   ; set the pen colour used by the text drawing routine

    ld ix,message       ; message to write
    call PrintText8x8   ; print the message at the coordinates held in bc

    pop de
    inc e               ; increment the colour index
    ld a,7
    and a,e             ; make it wrap back to 0 when it exceeds 7
    ld e,a

    pop bc
    ld a,8              ; each row of text is 8 pixels high
    add a,b             ; step down to next text row
    ld b,a
    cp a,192            ; check if we've reached the bottom of the screen
    jr nz,DrawTextLoop

    ; This macro disables reads and writes to Layer2, but leaves it visible
    ShowLayer2()

    ; enable interrupts before entering main loop. Unless we do this
    ; the halt instruction will wait forever.
    ei

; *****************************************************
; "game" loop
; *****************************************************

MainLoop:
    ; halt stops the CPU. The CPU remains stopped until the next interrupt occurs
    ; and these start at the beginning of each frame, so this is really simple
    ; way to synchronise your game loop with the V-Sync of the display.
    halt

    jr MainLoop


message: db "Hello World",0

; By default the palette for Layer2 is set up so that the bit pattern
; for a byte in layer2 represents its colour. The format is;
; rrrgggbb. With this knowledge we can define the colours we want to
; draw our text in.

colours:    db %00000000    ; black
            db %00000011    ; blue
            db %11100000    ; red
            db %11100011    ; magenta
            db %00011100    ; green
            db %00011111    ; cyan
            db %11111100    ; yellow
            db %11111111    ; white




pen_colour: db 255  ; the colour used by the text print routine (below)

;-------------------------------------------------------------------------
; a = ASCII character to print
; hl = address to print at
; This function uses the "loop" directive to repeat code.
; It uses four repeats of a pair of unrolled loops.
; The first loop of each pair draws a pixel row of the character from left
; to right.
; The 2nd loop of each pair draws a pixel row of the character from right to left
; This saves us having to add a skew value to the x offset at the end of each
; row, making things slightly faster. Speed is also the reason to unroll the loops
; as it avoids a compare and jump instruction for each pixel plotted.
;-------------------------------------------------------------------------
PrintChar8x8: proc
    push hl
    ; address of ZX Spectrum font in ROM - this saves us including our own font
    ; Note, this assumes the standard 48K Spectrum ROM is paged in.
    ; If your text is displaying garbled it's probably because you've not got
    ; the ROM set up correctly.
    ld hl,15360
    ld e,a
    ld d,8
    mul
    add hl,de
    ex de,hl
    pop hl
    ld a,(pen_colour)
    ld c,a

    loop 4


    ; draw even row from left to right
    ld a,(de)
    inc de

    loop 8
    rla
    ; skip next instruction, this jumps 3 bytes forward from the current address
    ; we need to use this syntax as labels wont work inside the loop directive
    jr nc,.+3
    ld (hl),c
    ; previous jump should jump to here

    inc hl
    lend
    inc h

    ; draw odd row from right to left
    ld a,(de)
    inc de

    loop 8
    dec hl
    rra
    ; skip next instruction, this jumps 3 bytes forward from the current address
    ; we need to use this syntax as labels wont work inside the loop directive
    jr nc,.+3
    ld (hl),c
    ; previous jump should jump to here

    lend
    inc h

    lend

    ret
    pend


;-------------------------------------------------------------------------
; ix = text string (zero terminated)
; b = y coord (0 - 192)
; c = x coord (0 - 255)
; this routine expects the L2 screen to be paged in for writes at 0000-bffff
;-------------------------------------------------------------------------
PrintText8x8: proc
    ld hl,bc        ; screen is paged in at 0000, and 256 pixels wide, so, coords in BC are actually the address
Lp:
    ld a,(ix)
    or a,a
    ret z
    inc ix
    push hl
    call PrintChar8x8
    pop hl
    ld a,8
    add a,l
    ld l,a    
    jr Lp

    pend
