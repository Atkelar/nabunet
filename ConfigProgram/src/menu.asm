; Some simple - but recurring - menu handling things...

; erase the lower four lines of the screen, draw a "nice" frame and put a title with the provided question.
;   hl -> question string (zero-term)
;   a -> 0 = force yes/no - 1 = allow "ESC".
;   return: a = 0 yes, 1 no, 2 cancel. also: z if yes, nz if "not yes".
prompt_yes_no:

    push af
    push hl
    ld b, 20
    ld c, 0
    call goto_xy
    ld hl, .headline
    call print
    ld b, 20
    ld c, 2
    call goto_xy

    ; TODO: cancel?
    ld hl, .prompt_title
    call print

    ld b, 21
    ld c, 0
    call goto_xy
    call clear_eol
   

    ld b, 23
    ld c, 0
    call goto_xy
    call clear_eol
    ld b, 22
    ld c, 0
    call goto_xy
    call clear_eol
    ld b, 22
    ld c, 3
    call goto_xy
    pop hl
    call print

    pop af
    ld e, a

.prompt_key_loop:
    call get_key
    cp KBD_VKEY_YES
    jr z, .prompt_yes
    cp KBD_VKEY_NO
    jr z, .prompt_no
    ; TODO: Cancel handle only IF is allowed!
    cp 01bh ;  ESC
    jr z, .prompt_cancel

    jr .prompt_key_loop

.prompt_yes:
    xor a
    ret

.prompt_no:
    ld a, 1
    or a
    ret

.prompt_cancel:
    ld a, 2
    or a
    ret

.prompt_title_cancel:
    defb    0B5h
    defb    " Confirm (or cancel) ", 0C6h, 0
.prompt_title:
    defb    0B5h
    defb    " Confirm ", 0C6h, 0

.headline:
    defs 40, 0CDh
    defb 0