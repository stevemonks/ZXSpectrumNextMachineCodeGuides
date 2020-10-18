;-------------------------------------------------------------------------
; UnpackRLE
; A RLE unpacker.The first byte of data is control byte is meaning is;
; byte > 0 - duplicate next n bytes, know as a copy-run
; byte < 0 - repeat next byte -n times known as a rep-run
; byte = 0 - end
;
; a copy-run byte is followed by 'n' bytes of data to copy
; a rep-run byte is followed by a single byte to replicate -'n' times
;
; This is followed by another control byte (unless its an 'end' control byte)
; in which case the process ends.

; enter with HL pointing to compressed data
; and de pointing to the buffer to unpack into
;-------------------------------------------------------------------------

UnpackRLE: proc
Lp:
    ld a,(hl)
    cp a,0
    jr nz,NotEnd

    ret

NotEnd:
    jp m,RepRun    ; negative value indicates rep run
    inc hl

    ; copy run
    ld c,a
    ld b,0
    ldir
    jr Lp

RepRun:
    ; rep run
    inc hl
    neg
    ld b,a
    ld a,(hl)
    inc hl
RepLp:
    ld (de),a
    inc de
    djnz RepLp

    jr Lp
    
    ret
    pend
