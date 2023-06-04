; misc. config program utility functions...


; prints the "a" register as 2-digit hex code.
print_hex_8:
    ld b, a
    srl a
    srl a
    srl a
    srl a
    and 0fh
    ld hl, hexbuffer
    call .storehexdigit

    ld a, b
    and 0fh
    inc hl
    call .storehexdigit

    ld hl, hexbuffer

    call print
    ret

; prints the "bc" register as 2-digit hex code.
print_hex_16:
    push bc
    ld a, b
    call print_hex_8
    pop bc
    ld a, c
    call print_hex_8
    ret


.storehexdigit:
    cp 10
    jr c, .is_digit
    add 7
.is_digit:
    add '0'
    ld (hl),a
    ret

hexbuffer:  ; 3-bytes 0 for 2-ditig hex max
defb 0,0,0