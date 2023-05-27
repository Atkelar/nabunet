; a simple menu framework...

; prints a menu on screen.
;    b/c = Y/X, hl => menu structure:
;       [# of entries] byte, 1..n
;       [address # text].. word, one per item, address of text to show, 0-terminated.

atkelar_menu_draw:

    ld a, (hl)
    or a
    ret z

    cp 10
    ret nc   ; support only up to 9 entries; 1..9

    ld d, a
    ld e, 1 ; start at menu item #1

    



    ret


.menu_separator:
defb ": ",0
