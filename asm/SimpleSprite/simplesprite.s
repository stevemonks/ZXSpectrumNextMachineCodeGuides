
; *****************************************************
; Register definitions
; *****************************************************

TBBLUE_REGISTER_SELECT			equ $243B

TURBO_MODE_PORT equ $07                             ; $0 = 3.5MHz, $1 = 7MHz, $2 = 14MHz, $3 = 28MHz (possibly, not documented)
SPRITE_SLOT_PORT equ $303b
SPRITE_LAYERS_CONTROL_PORT equ $15
SPRITE_NUMBER_PORT equ $34
SPRITE_ATTR_PORT equ $57
SPRITE_PATTERN_PORT equ $5b
SPRITE_TRANS_PORT equ $4b

PALETTE_INDEX_PORT equ $40                          ; write index for palette
PALETTE_VALUE_PORT equ $41                          ; r/w value of palette at current index
PALETTE_CONTROL_PORT equ $43                        ; bit 7 - disable palette write auto inc
PALETTE_SELECT_SPRITE_1  equ %00100000


; *****************************************************
; System initialisation
; *****************************************************
    nextreg TURBO_MODE_PORT, $2                     ; $07 - cpu to 28 mhz because, why not?

; *****************************************************
; fill ULA attr with colour bars - this just gives
; us a background to draw our sprite over by filling the
; screen attribute buffer with some colour values
; *****************************************************

    ld hl,16384+6144
    ld b,24
AttrRowLp:
    ld a,0
AttrColLp:
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    add a,%00001000
    and a,%00111000
    jr nz,AttrColLp
    dec b
    jr nz, AttrRowLp


; *****************************************************
; global sprite setup
; *****************************************************
    nextreg SPRITE_LAYERS_CONTROL_PORT,%00000001    ; $15 - enable sprites

; *****************************************************
; set sprite 0 attributes
; *****************************************************

    sub a,a                     ; select sprite 0 to modify
    ld bc,SPRITE_SLOT_PORT      ; $303b - write to this port to set the current sprite
    out (c),a

    ld bc,SPRITE_ATTR_PORT      ; $0057 - write to this port to set each sprite attribute

    ld a,32                     ; set sprite position. The top left of the screen is 0,0. 32,32 is the top left of the standard ZX Spectrum screen display area.
    out(c),a                    ; write attribute #0 - the first write sets the low 8 bits of the sprites x coordinate
    out(c),a                    ; write attribute #1 - the second write sets the sprites y coordinate
    ld a,0                      ; set the palette index (0), no mirroring and no rotation
    out(c),a                    ; write attribute #2

    ld a,%11000000              ; enable the sprite (make it visible), enable attribute #4 and set the high 6 bits of the pattern index
    out(c),a                    ; write attribute #3

    ld a,%10000000              ; make this a 4 bit sprite and write the low bit of the pattern select
    out(c),a

; *****************************************************
; Set sprite pattern in pattern memory
; The sprite hardware cannot access main memory, so we
; have to copy our sprite pattern data to special
; sprite pattern memory, this is done by copying it
; a byte at a time to port $5b
; *****************************************************

    ld bc,SPRITE_SLOT_PORT          ; $303b
    sub a,a
    out (c),a                       ; select pattern to write to (index 0 in this case)

    ld hl, sprite_pattern			; address of our sprite pattern data
    ld bc, SPRITE_PATTERN_PORT      ; $5b
    ld de,128                       ; each byte of a 16 colour sprite encodes 2 pixels per byte. So a 16x16 pixel sprite is 16x16x2 = 128 bytes long
SetSpritePatternLoop:
    ld a,(hl)						; fetch byte of pattern data
    inc hl							; step to next byte
    out(c),a						; write byte of pattern data to pattern memory
    dec de							; decrement count
    ld a,e
    or a,d							; if d and e are both zero the count has run out
    jr nz,SetSpritePatternLoop

; *****************************************************
; set up sprite palette 0
; Similarly, the hardware cannot make use of palettes in
; main memory, so we have to copy our sprite palette 
; to palette memory by sending it a byte at a time to
; port $41
; *****************************************************

    nextreg SPRITE_TRANS_PORT, 0                            ; $4b - colour ix 0 is the transparent colour
    nextreg PALETTE_CONTROL_PORT, PALETTE_SELECT_SPRITE_1   ; $43 - select palette to edit
    nextreg PALETTE_INDEX_PORT,0                            ; $40 - select index to edit

    ld b,16
    ld hl,sprite_palette
SpritePaletteLoop:
    ld a,(hl)
    inc hl
    nextreg PALETTE_VALUE_PORT, a                           ; $41 - write colour to palette entry
    djnz SpritePaletteLoop


; *****************************************************
; "game" loop
; *****************************************************

Wait:
    ; halt stops the CPU. The CPU remains stopped until the next interrupt occurs
    ; and these start at the beginning of each frame, so this is really simple
    ; way to synchronise your game loop with the V-Sync of the display.
    halt
    jr Wait


sprite_pattern:
	db $0, $70, $0, $0, $0, $0, $7, $0
	db $7, $f7, $0, $0, $0, $0, $7f, $70
	db $f, $f7, $7, $77, $77, $70, $7f, $f0
	db $7, $ff, $77, $77, $77, $77, $ff, $70
	db $7, $ff, $77, $77, $77, $77, $ff, $70
	db $7, $ff, $77, $87, $78, $77, $ff, $70
	db $0, $7f, $77, $77, $77, $77, $f7, $0
	db $0, $7, $f7, $77, $77, $7f, $70, $0
	db $0, $0, $7f, $77, $77, $f7, $0, $0
	db $0, $7, $77, $f8, $8f, $77, $70, $0
	db $0, $77, $77, $78, $87, $77, $77, $0
	db $7, $77, $77, $77, $77, $77, $77, $70
	db $f, $77, $77, $77, $77, $77, $77, $70
	db $0, $f7, $77, $f7, $7f, $77, $77, $0
	db $0, $f, $77, $f, $f0, $f7, $70, $0
	db $f, $f7, $77, $0, $0, $ff, $f7, $70

sprite_palette:
	db 0,3,224,227,28,31,252,255,0,2,160,162,20,22,180,182
