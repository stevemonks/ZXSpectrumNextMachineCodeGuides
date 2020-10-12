
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
    nextreg PALETTE_VALUE_PORT, a                           ; $41 - write colour to palette entry
    djnz SpritePaletteLoop


; *****************************************************
; "game" loop
; *****************************************************

MainLoop:
    ; halt stops the CPU. The CPU remains stopped until the next interrupt occurs
    ; and these start at the beginning of each frame, so this is really simple
    ; way to synchronise your game loop with the V-Sync of the display.
    halt

    ld de,(sprite_x)                        ; load the current sprite position into de
    call ControlSpriteKeyboard              ; adjust the values in d and e if keys are pressed
    ld (sprite_x),de                        ; save the modified sprite position back to memory for next frame

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



sprite_x: db 32                             ; the x position of the sprite. Range 0 to 255, this actually not enough to get us all the way across the screen as it's 320 pixels wide.
sprite_y: db 32                             ; the y position of the sprite. Range 0 to 255, this covers the full height of the screen.
sprite_anim_counter: db 0                   ; storage for a counter that increments every frame (wrapping back to 0 when it passes 255) we use this to key the animation

;------------------------------------------------------------------------------------------
; ControlSpriteKeyboard
; takes the current sprite position in DE and modifies it with input from the keyboard.
; keys are - Z = left, X = right, O = up, K = down.
; the modified value is returned in DE.
;
; d = sprite Y - in pixels down from the top of the screen. 32 is the start of the border
; e = sprite X - in pixels across the screen. 32 is the start of the border
;------------------------------------------------------------------------------------------

ControlSpriteKeyboard:
    ld bc,$dffe
    in a,(c)       ; read in [P][O][I][U][Y]
    and a,$02       ; O key - a = 0 if pressed
    sub a,1     
    ld a,d
    sbc a,0
    ld d,a

    ld bc,$bffe
    in a,(c)       ; read in [enter][L][K][J][H]
    and a,$04       ; k key - a = 0 if pressed
    sub a,1
    ld a,d
    adc a,0
    ld d,a

    ld bc,$fefe
    in a,(c)       ; read [CAPS SHIFT][Z][X][C][V]
    and a,$02       ; z key - a = 0 if pressed
    sub a,1
    ld a,e
    sbc a,0
    ld e,a

    in a,(c)       ; read [CAPS SHIFT][Z][X][C][V]
    and a,$04       ; x key - a = 0 if pressed
    sub a,1
    ld a,e
    adc a,0
    ld e,a

    ret


;------------------------------------------------------------------------------------------
; UpdateSprite
; sets the position and pattern number for the given sprite
;
; a = sprite number - the sprite we are adjusting
; d = sprite Y - in pixels down from the top of the screen. 32 aligns with the start of the ULA screen
; e = sprite X - in pixels across the screen. 32 aligns with the start of the ULA screen
; l = pattern number - index of the pattern number used to draw the sprite
;------------------------------------------------------------------------------------------

UpdateSprite:
    ld bc,SPRITE_SLOT_PORT      ; $303b - write to this port to set the current sprite
    out (c),a

    ld bc,SPRITE_ATTR_PORT      ; $0057 - write to this port to set each sprite attribute

    ; set sprite position. The top left of the screen is 0,0. 32,32 is the top left of the standard ZX Spectrum screen display area.
    out(c),e                    ; write attribute #0 - the first write sets the low 8 bits of the sprites x coordinate
    out(c),d                    ; write attribute #1 - the second write sets the sprites y coordinate
    ld a,0                      ; set the palette index (0 in this simple example), no mirroring and no rotation
    out(c),a                    ; write attribute #2

    ld h,0                      ; pre clear h, this will receive the low order bit of the pattern index
    ld a,l                      ; load pattern index into a
    srl a                       ; shift pattern index right, moving low order bit into the carry flag
    rr h                        ; bring carry flag (low order bit of pattern index) into high order bit of h
    rr h                        ; move bit into correct position
    or a,%11000000              ; enable the sprite (make it visible), enable attribute #4 and set the high 6 bits of the pattern index
    out(c),a                    ; write attribute #3

    ld a,%10000000              ; make this a 4 bit sprite and write the low bit of the pattern select
    or a,h                      ; or in the low order bit of the sprite pattern index
    out(c),a
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
	db 0,3,224,227,28,31,252,255,0,2,160,162,20,22,180,182
