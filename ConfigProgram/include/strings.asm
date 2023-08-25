; some core utility functions for string handling...

; input: hl -> string start
; output: hl -> length in bytes
strlen:
    xor a
    ld b,a
    ld c,a
    cpir
    ld hl, 0ffffh
    sbc hl, bc
    ret

; input: hl -> source, de -> destination.
;   output: de/hl after the string operation, i.e. at the zero-byte AFTER the 0-byte.
strcpy:
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    or a
    jr nz, strcpy
    ret