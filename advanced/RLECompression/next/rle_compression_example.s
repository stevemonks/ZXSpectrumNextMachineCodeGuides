

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
PALETTE_SELECT_TILEMAP_1 = %00110000


TILEMAP_CLIP_PORT = $1b                  ; write here to adjust clip window, 1st write=left, 2nd=right, 3rd=top, 4th=bottom
TILEMAP_CONTROL_PORT = $6b
TILEMAP_DISABLE = $0
TILEMAP_40_NOATTR = %10100000
TILEMAP_40_ATTR   = %10000000
TILEMAP_ULA_CONTROL_PORT = $68
TILEMAP_ATTR_PORT = $6c

TILEMAP_BASE_ADDR_PORT = $6e            ; base addr of tile map
TILEMAP_PATTERN_BASE_ADDR_PORT = $6f    ; base addr of tile patterns

TILEMAP_TRANSPARENCY_PORT = $4c

TILEMAP_OFFSET_X_MSB_PORT = $2f
TILEMAP_OFFSET_X_LSB_PORT = $30
TILEMAP_OFFSET_Y_PORT = $31

GLOBAL_TRANS_COLOUR = $14           ; 8 bit transparent colour rrrgggbb, defaults to $e3


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
    ld bc,32*24
    ld e,0
AttrLp:
    ld (hl),e
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,AttrLp

; *****************************************************
; tilemap hardware setup
; *****************************************************

    nextreg TILEMAP_CONTROL_PORT,TILEMAP_40_NOATTR  ; configure tilemap as 40 column byte per tile (no attribute bytes)
    nextreg TILEMAP_ATTR_PORT,$0                    ; set global tile attr (using 8 bit rather than 16 bit tiles)
    nextreg TILEMAP_TRANSPARENCY_PORT,$0            ; select palette entry 0 as the transparent colour
    nextreg TILEMAP_ULA_CONTROL_PORT,$0             ; ULA enabled and ULA/Sprite blend mode

    ; configure tilemap clipping
    nextreg TILEMAP_CLIP_PORT,16            ; left
    nextreg TILEMAP_CLIP_PORT,143           ; right 
    nextreg TILEMAP_CLIP_PORT,32            ; top
    nextreg TILEMAP_CLIP_PORT,223           ; bottom

    ; set the tilemap hardware to point to our memory buffer
    ; (see tile_map_data defined in candm.asm)
    nextreg TILEMAP_BASE_ADDR_PORT,tile_map_data/256

    ; point tilemap hardware at our tile patterns in memory
    ; (see tile_map_patterns defined in candm.asm)
    nextreg TILEMAP_PATTERN_BASE_ADDR_PORT,tile_map_patterns/256

    ; Horizontal scroll range, 0-320.
    ; The tilemap normally begins 32 pixels above and to the left of the ULA
    ; screen as it's 320x256 pixels compared to the ULA screen which is 256x192.
    ; We want to compensate for this, so we need to scroll in the X by -32 pixels.
    ; However, the x scroll register has a range of 0 to 319, so -32 is effectively
    ; 320-32 = 288. The X scroll register is 16 bits split over two 8 bit ports,
    ; so in hex, 288 = $0120
    nextreg TILEMAP_OFFSET_X_MSB_PORT,$01
    nextreg TILEMAP_OFFSET_X_LSB_PORT,$20

    ; The Y scroll is simpler as it's just an 8 bit port
    nextreg TILEMAP_OFFSET_Y_PORT,-32

; *****************************************************
; set up tilemap palette 0
; The hardware cannot make use of palettes in
; main memory, so we have to copy our sprite palette 
; to palette memory by sending it a byte at a time to
; port $41
; *****************************************************

    nextreg PALETTE_CONTROL_PORT, PALETTE_SELECT_TILEMAP_1   ; select palette to edit
    nextreg PALETTE_INDEX_PORT,0                            ; select index to edit

    ld b,16
    ld hl,maze_tiles_palette
SetPaletteLoop:
    ld a,(hl)
    inc hl
    nextreg PALETTE_VALUE_9BIT_PORT, a                           ; $44 - write colour to palette entry low byte
    ld a,(hl)
    inc hl
    nextreg PALETTE_VALUE_9BIT_PORT, a                           ; $44 - write colour to palette entry high byte
    djnz SetPaletteLoop

; *****************************************************
; Now we're going to draw something into the tilemap,
; but first, we should clear it by filling it with the
; "empty" tile (tile 0 - see accompanying readme)
; *****************************************************


    ; fill tilemap with the "empty" tile (tile 0)

    ld hl,tile_map_data
    ld bc,1280
    ld e,0
clearTilemapLoop:
    ld (hl),e
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,clearTilemapLoop

; *****************************************************
; Unpack the RLE compressed tilemap
; *****************************************************

    ; note that our map compressor prefixes the width and height of the tilemap
    ; before the RLE data so we need to skip these, hence the "+2" in the source address.

    ld hl,example_map_map+2     ; source address of RLE compressed data

    ld de,tile_map_data         ; destination address we want to unpack to,
                                ; for simplicity we're going straight into the
                                ; hardware tilemap buffer
    call UnpackRLE              ; unpack the data



; *****************************************************
; "game" loop
; *****************************************************

    ; enable interrupts before entering main loop. Unless we do this
    ; the halt instruction will wait forever.
    ei

MainLoop:
    ; halt stops the CPU. The CPU remains stopped until the next interrupt occurs
    ; and these start at the beginning of each frame, so this is really simple
    ; way to synchronise your game loop with the V-Sync of the display.
    halt

    ld ix,ScrollPosX            ; get address of structure containing scroll values
    call ControlScrollKeyboard  ; read the keys and modify the scroll values

    ; set the hardware scroll registers from the current scroll values
    ld a,(ix+1)                         ; ScrollPosX (high byte)
    nextreg TILEMAP_OFFSET_X_MSB_PORT,a
    ld a,(ix)                            ; ScrollPosX (low byte)
    nextreg TILEMAP_OFFSET_X_LSB_PORT,a
    ld a,(ix+2)                          ; ScrollPosY
    nextreg TILEMAP_OFFSET_Y_PORT,a

    jr MainLoop

; structure containing the current scroll values. Note that the x scroll position
; is a 16 bit value, while the y scroll position is an 8 bit value.
ScrollPosX: dw 288  ; x range is 0-319, so -32 is effectively 320-32 = 288
ScrollPosY: db -32


;------------------------------------------------------------------------------------------
; ControlScrollKeyboard
; takes the address of a data structure containing the current scroll position and modifies
; the data structure with input from the keyboard.
; keys are - Z = scroll left, X = scroll right, O = scroll up, K = scroll down.
;
; ix - points to a data structure containing;
; x position (16 bits)
; y position (8 bits) 
; 
;------------------------------------------------------------------------------------------

ControlScrollKeyboard: proc
    ; update Y scroll value first
    ld de,0
    ld l,(ix+2)     ; y scroll
    ld h,0

    ld bc,$bffe
    in a,(c)       ; read in [enter][L][K][J][H]
    and a,$04      ; k key - a = 0 if pressed
    sub a,1     
    sbc hl,de

    ld bc,$dffe
    in a,(c)       ; read in [P][O][I][U][Y]
    and a,$02      ; O key - a = 0 if pressed
    sub a,1
    adc hl,de

    ld (ix+2),l     ; save updated y scroll value


    ; update X scroll value. This is a little more involved as
    ; it must be constrained between the values 0 and 319

    ld l,(ix)           ; x scroll
    ld h,(ix+1)

    ld bc,$fefe
    in a,(c)            ; read [CAPS SHIFT][Z][X][C][V]
    and a,$04           ; x key - a = 0 if pressed
    sub a,1
    sbc hl,de           ; decrement value
    jr nc,NoUnderflow   ; check if value has gone negative (carry flag will be set)

    ld hl,319           ; value went negative, so set it back to the upper limit

NoUnderflow:
    in a,(c)            ; read [CAPS SHIFT][Z][X][C][V]
    and a,$02           ; z key - a = 0 if pressed
    sub a,1
    adc hl,de           ; increment value

    ex de,hl            ; move calculated value into de
    or a                ; clear carry flag
    ld hl,319           ; upper limit we can scroll to
    sbc hl,de           ; subtract scroll amount from upper limit
    jr nc,NoOverflow    ; if no carry occurred, we've not exceeded the upper limit

    ld de,0             ; if a carry occurred, we've exceeded the upper limit, so set it to the lower limit

NoOverflow:
    ld (ix),e           ; save updated x scroll value
    ld (ix+1),d

    ret
    pend
