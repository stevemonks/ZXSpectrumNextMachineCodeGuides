
; *****************************************************
; Register definitions - while you could just use the
; register addresses in your code, it's easier to read
; if you give them meaningful names and use those instead
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
PALETTE_VALUE_9BIT_PORT equ $44                     ; r/w value of 9 bit palette at current index
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

    ld hl,16384+6144    ; start of attribute buffer
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
; Set sprite pattern in pattern memory
; The sprite hardware cannot access main memory, so we
; have to copy our sprite pattern data to special
; sprite pattern memory, this is done by copying it
; a byte at a time to port $5b
; *****************************************************

    ld bc,SPRITE_SLOT_PORT          ; $303b
    sub a,a
    out (c),a                       ; select pattern to write to (index 0 in this case)

    ld hl, sprite_pattern0			; address of our sprite pattern data
    ld bc, SPRITE_PATTERN_PORT      ; $5b
    ld de,128*NUM_SPRITE_PATTERNS	; each byte of a 16 colour sprite encodes 2 pixels per byte. So a 16x16 pixel sprite is 16x16x2 = 128 bytes long
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

    nextreg SPRITE_TRANS_PORT, 0                            ; $4b - set colour ix 0 as the transparent colour
    nextreg PALETTE_CONTROL_PORT, PALETTE_SELECT_SPRITE_1   ; $43 - select the type of palette to edit (in this case, sprites)
    nextreg PALETTE_INDEX_PORT,0                            ; $40 - select index to edit

    ld b,16
    ld hl,sprite_palette
SpritePaletteLoop:
    ld a,(hl)
    inc hl
    nextreg PALETTE_VALUE_9BIT_PORT, a                           ; $44 - write colour to palette entry low byte
    ld a,(hl)
    inc hl
    nextreg PALETTE_VALUE_9BIT_PORT, a                           ; $44 - write colour to palette entry high byte
    djnz SpritePaletteLoop


; *****************************************************
; "game" loop
; *****************************************************

MainLoop:
    ; halt stops the CPU. The CPU remains stopped until the next interrupt occurs
    ; and these start at the beginning of each frame, so this is really simple
    ; way to synchronise your game loop with the V-Sync of the display.
    halt

    ld ix,sprite_x                          ; address of structure containing sprite x and y coordinates
    call ControlSpriteKeyboard              ; adjust the values in d and e if keys are pressed

    ; our sprite has two frames of animation and we want to alternate them periodically.
    ; To do this we have simple frame counter in memory that we increment every frame.
    ; We then filter out bit 3, which toggles between 1 and 0 every 8 frames (bit 2 would be every 4, bit 1 every 2 and bit 0 every frame)
    ; and use the value of that to select sprite pattern 0 or sprite pattern 1.

    ld a,(sprite_anim_counter)              ; update the frame counter
    inc a
    ld (sprite_anim_counter),a

    and a,8                                 ; mask off our control bit. a will contain either 0 or 8 depending on the value of the counter
    sub a,1                                 ; subtracting 1 will give us a carry if a=0 or no carry if a=8
    ld l,0                                  ; clear l, does not affect the carry flag
    rl l                                    ; rotate the carry bit into bit 0 of l, so that l now equals 1 or 0, this is our pattern index
    ld a,0                                  ; set the sprite index we want to update, for this example it's always sprite 0.
    call UpdateSprite                       ; update sprite 0 with the coordinates in d,e and the pattern index in l.
    jr MainLoop



sprite_x: dw 32                             ; the x position of the sprite. Range 0 to 255, this actually not enough to get us all the way across the screen as it's 320 pixels wide.
sprite_y: dw 32                             ; the y position of the sprite. Range 0 to 255, this covers the full height of the screen.
sprite_anim_counter: db 0                   ; storage for a counter that increments every frame (wrapping back to 0 when it passes 255) we use this to key the animation

;------------------------------------------------------------------------------------------
; ControlSpriteKeyboard
; takes the address of a data structure containing the current sprite position and modifies
; the data structure with input from the keyboard.
; keys are - Z = left, X = right, O = up, K = down.
;
; ix - points to a data structure containing;
; x position (16 bits)
; y position (16 bits) 
; 
;------------------------------------------------------------------------------------------

ControlSpriteKeyboard:
    ld de,0
    ld l,(ix+2)     ; sprite y coordinate
    ld h,(ix+3)

    ld bc,$dffe
    in a,(c)       ; read in [P][O][I][U][Y]
    and a,$02      ; O key - a = 0 if pressed
    sub a,1     
    sbc hl,de

    ld bc,$bffe
    in a,(c)       ; read in [enter][L][K][J][H]
    and a,$04      ; k key - a = 0 if pressed
    sub a,1
    adc hl,de

    ld (ix+2),l
    ld (ix+3),h

    ld l,(ix)       ; sprite x coordinate
    ld h,(ix+1)

    ld bc,$fefe
    in a,(c)       ; read [CAPS SHIFT][Z][X][C][V]
    and a,$02      ; z key - a = 0 if pressed
    sub a,1
    sbc hl,de

    in a,(c)       ; read [CAPS SHIFT][Z][X][C][V]
    and a,$04      ; x key - a = 0 if pressed
    sub a,1
    adc hl,de

    ld (ix),l
    ld (ix+1),h

    ret


;------------------------------------------------------------------------------------------
; UpdateSprite
; sets the position and pattern number for the given sprite
;
; a  = sprite number - the sprite we are adjusting
; ix = address of a data structure containing the sprites coordinates
; l = pattern number - index of the pattern number used to draw the sprite
;------------------------------------------------------------------------------------------

UpdateSprite:
    ld bc,SPRITE_SLOT_PORT      ; $303b - write to this port to set the current sprite
    out (c),a

    ld bc,SPRITE_ATTR_PORT      ; $0057 - write to this port to set each sprite attribute

    ; set attribute #0 - sprite x coordinate (low byte)
    ld e,(ix)                   ; fetch the low 8 bits of the sprites x coordinate
    ; set sprite position. The top left of the screen is 0,0.
    ; 32,32 is the top left of the standard ZX Spectrum screen display area.
    out(c),e                    ; write attribute #0 - the first write sets the low 8 bits of the sprites x coordinate

    ; set attribute #1 - sprite y coordinate (low byte)
    ld d,(ix+2)                 ; fetch the low 8 bits of the sprites y coordinate
    out(c),d                    ; write attribute #1 - the second write sets the sprites y coordinate

    ; set attribute #2 - MSB of sprite x coordinate, palette index, mirroring and rotation
    ld a,(ix+1)                 ; fetch the high 8 bits of the sprites x coordinate
    and a,1                     ; mask off the high bit of the x coordinate
                                ; and set the palette index (0 in this simple example),
                                ; no mirroring and no rotation
    out(c),a                    ; write attribute #2

    ; set attribute #3 - sprite visible, enable attr 4, sprite pattern ix (bits 0 to 5)
    ld h,0                      ; pre clear h, this will receive the low order bit of the pattern index
    ld a,l                      ; load pattern index into a
    srl a                       ; shift pattern index right, moving low order bit into the carry flag
    rr h                        ; bring carry flag (low order bit of pattern index) into high order bit of h
    rr h                        ; move bit into correct position
    or a,%11000000              ; enable the sprite (make it visible), enable attribute #4 and set the high 6 bits of the pattern index
    out(c),a                    ; write attribute #3

    ; set attribute #4 - 16 colour sprite, bit 6 of pattern ix, magnification and MSB of sprite y coordinate
    ld a,(ix+3)                 ; fetch the high byte of the sprites y coordinate
    and a,1                     ; mask off just the LSB of this byte to set bit 0 of the register
    or a,%10000000              ; make this a 4 bit sprite by setting bit 7
    or a,h                      ; write the low bit of the pattern index into bit 6
    out(c),a                    ; write attribute #4
    ret

NUM_SPRITE_PATTERNS equ 2
sprite_pattern0:
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
	db $f, $77, $77, $77, $7f, $77, $77, $70
	db $0, $f7, $77, $f7, $7f, $77, $77, $0
	db $0, $f, $77, $f, $f0, $ff, $f7, $70
	db $f, $f7, $77, $0, $0, $0, $0, $0
sprite_pattern1:
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
	db $f, $77, $77, $f7, $77, $77, $77, $70
	db $0, $f7, $77, $f7, $7f, $77, $77, $0
	db $f, $ff, $77, $f, $f0, $f7, $70, $0
	db $0, $0, $0, $0, $0, $ff, $f7, $70

sprite_palette:
	db 0,0, 3,1, 224,0, 227,0, 28,0, 31,0, 252,0, 255,1, 0,0, 2,0, 160,0, 162,0, 20,0, 22,0, 180,0, 182,1 
