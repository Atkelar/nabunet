; Low level screen subroutines


; Initializes the screen functions to "text mode", clears the screen and enables cursor logic.
; MUST be called after the interrupt setup!
setup_screen:
	ld hl,.init_vdp_table
	ld b,008h		        ;   Byte count for init table
	ld c,IO_VDP_CONTROL       ;   base address VDP

.vdp_init_loop:
	outi		            ;   copy table to VDP latch
	ld a,b
	or 080h
	out (IO_VDP_CONTROL),a    ;   VDP latch write high bit set: target register, loop count-1
	and 07fh
	jr nz,.vdp_init_loop		;   loop the output...

    ld a, SCREEN_MODE_TEXT
    ld (SCREEN_MODE), a
    ld a, 40
    ld (SCREEN_WIDTH), a
    ld a, 24
    ld (SCREEN_HEIGHT), a

    ld a, VDP_COLOR_WHITE << 4 | VDP_COLOR_DARK_BLUE
    call clear_screen

    ret


; Fills the current line (cursor X/Y) with spaces until the right edge of the screen, 
; not changing the current cursor location
clear_eol:
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; we don't "print" in MC mode...

    ; TODO: temporary disable cursor...

    ; initialize starting address in VDP...
    ld a, (CURSOR_POSITION_Y)
    ld b, a
    ld a, (CURSOR_POSITION_X)
    ld c, a
    push bc
    call .calculate_screen_offset
    pop bc

    ; set target address...
    ld de, 800h
    add hl, de
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; set "address selection bit"
    out (IO_VDP_CONTROL), a

    ld a, (SCREEN_WIDTH)
    sub c

    ld c, IO_VDP_DATA
    ld d, 20h   ; fill char...

.clear_eol_loop:
    ; normal character.
    out (c), d
    dec a
    jr z, .clear_eol_done
    jr .clear_eol_loop

.clear_eol_done:

    ; TODO: enable cursor...
    ret

; fills the current screen with "blanks" (character index 32) in text/gfx1/gfx2 modes, zero in MC mode.
;   foreground/background color in "a" will be used to setup color according to the screen mode.

clear_screen:
    push af
    push de
    push bc

    ld b, a
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_TEXT
    jr z, .textmode_clear
  

.textmode_clear:
    ; write color code to register 7
    ld a, b
    out (IO_VDP_CONTROL), a
    ld a, 87h
    out (IO_VDP_CONTROL), a
    
    jr .common_clear


.common_clear:

    ld a, 0
    ld (CURSOR_POSITION_X), a
    ld (CURSOR_POSITION_Y), a
    ld (CURSOR_ORIGINAL_CHAR), a    ; none yet.

    ;call .prepare_cursor_bitmap

    ld a, 0
    out (IO_VDP_CONTROL), a
    ld a, 048h
    out (IO_VDP_CONTROL), a
    ld hl, 0fc40h
    ld a, 020h
    ld de, 1
.clear_mem_loop:
    out (IO_VDP_DATA), a
    add hl, de
    jr nc, .clear_mem_loop
 
    pop bc
    pop de
    pop af
    ret

; input: HL = address of string, 0-terminated.
; handles "cr" (0x0A) as CR/LF and does scrolling if needed.
; keeps track of cursor X/Y...
print:
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; we don't "print" in MC mode...

    ; TODO: temporary disable cursor...

    ; initialize starting address in VDP...

    push hl

    ld a, (CURSOR_POSITION_Y)
    ld b, a
    ld a, (CURSOR_POSITION_X)
    ld c, a
    push bc
    call .calculate_screen_offset
    pop bc

    ld de, 800h
    add hl, de
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; set "address selection bit"
    out (IO_VDP_CONTROL), a
    pop hl

    ld a, (SCREEN_WIDTH)
    ld d, a
    ld a, (SCREEN_HEIGHT)
    ld e, a

.print_loop:
    ld a, (hl)
    inc hl
    or a
    jr z, .print_done
    cp 0ah
    jr z, .linefeed_now
    ; TODO: tab... backspace... beep...?

    ; normal character.
    out (IO_VDP_DATA), a
    ;push hl
    ld a, c
    inc a
    cp d
    jr z, .linefeed_now
    ld c, a

    jr .print_loop

.linefeed_now:
    ld a, b
    inc a
    cp e
    jr nz, .no_scroll

    ; TODO: call "scroll screen up one..."

    dec a   ; stay at bottom line...
.no_scroll:
    ld b, a
    xor a
    ld c, a

    push hl
    push bc
    push de
    call .calculate_screen_offset
    ld de, 800h
    add hl, de
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; set "address selection bit"
    out (IO_VDP_CONTROL), a
    pop de
    pop bc
    pop hl

    jr .print_loop

   
.print_done:

    ld a, c
    ld (CURSOR_POSITION_X), a
    ld a, b
    ld (CURSOR_POSITION_Y), a

    ; TODO: enable cursor...
    ret

; input b = y, c = x
goto_xy:
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; we don't "print" in MC mode...

    ld hl, SCREEN_WIDTH
    ld a, c
    cp (hl)
    ret nc  ; width overflow

    ld hl, SCREEN_HEIGHT
    ld a, b
    cp (hl)
    ret nc  ; height overflow

    ; TODO: disable cursor...

    ; make sure we don't get blinking signals...
    ld (CURSOR_POSITION_Y), a
    ld a, c
    ld (CURSOR_POSITION_X), a
    ;call .prepare_cursor_bitmap 

    ; TODO: enable cursor...
    ret

; input b = y, c = x
; output hl = offset byte position
.calculate_screen_offset:
    ld hl, 0
    ld de, 0
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; not supported in multicolor mode.
    cp SCREEN_MODE_TEXT
    jr nz,.calculate_screen_32chars
    ; assume 40 for text.
    ld a, b
    or a
    jr z, .first_line
    ld e, b
    sla e
    sla e
    sla e   ; y * 8 is not in HL
.calculate_screen_32chars:
    ld a, b
    or a
    jr z, .first_line
    ld l, b
    sla l
    rl h
    sla l
    rl h
    sla l
    rl h
    sla l
    rl h
    sla l
    rl h
    add hl, de
.first_line:
    ld a, l
    add a, c
    ld l, a
    ret nc
    inc h
    ret

; take the character at the current curosr position and - if different than the current prepared one - make a new inverted bitmap in code 0
.prepare_cursor_bitmap:
    ; offset in screen ram = y * width + x... 
    ld a, (CURSOR_POSITION_Y)
    ld b,a
    ld a, (CURSOR_POSITION_X)
    ld c,a
    call .calculate_screen_offset
    ld de, 800h
    add hl, de
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    ; or 000h     ; "address selection bit" needs to be zero in read operation.
    out (IO_VDP_CONTROL), a
    in a, (IO_VDP_DATA)

    ; now we know the "active" character code in a.
    ld b, a
    ld a, (CURSOR_ORIGINAL_CHAR)
    cp b
    ret z   ; we already have the correct one!

    ld (CURSOR_ORIGINAL_CHAR), a    ; remember! (this will be used to flip the code between 0/<original> for blinking...)

    ; now, find the character definition in the "name table", read 8 bytes, invert the bottom "count" ones and store for character 0...
    ld hl, 0
    ld l, a
    sla l
    rl h
    sla l
    rl h
    sla l
    rl h   ; a * 8

    ld de, 0
    add hl, de
    

    ld b, 8
    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_HEIGHT
    cp b,c


    ret

; Load a (partial?) font definiton into the charset RAM
;  HL -> Pointer to font structure:
;           0x?? number of chars (max. 255, char 0 is reserved for cursor!)
;           0x?? first char in set (1..255, number + first must not exceed 256!)
load_font:
    ld a, (hl)
    or a
    ret z

    ld b, a
    inc hl
    ld a, (hl)
    or a
    ret z
    inc hl

    ld d, 0     
    ld e, a     ; first char index...
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d       ; offset * 8 for 8-bytes per char...
    push hl
    ld hl,0  ; base address of target charset buffer...
    add hl, de
    ; now we have HL -> target address, TOS -> source address. b -> # of chars

    ; setup data transfer in VDP... TODO: disable cursor temporarily... cursor blink might mess up the target address in VDP!
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    or a, 040h
    out (IO_VDP_CONTROL), a

    ; now, get the source address from the stack...
    pop hl
    inc hl  ; ??? why?
    ld c, IO_VDP_DATA   ; output port...
    ld d, b
    ld a, 8 ; 8 bytes per char...
.repeat_load:
    ld b, d
    otir ; HL -> #C, B times.
    dec a
    jr nz, .repeat_load

    ; TODO: enable cursor again...

    ret

.init_vdp_table:     ; table is register 7..0 for loop reasons.
    ; Color 1: F, Background/Color 0: 4
    ;       NABU starts off with white/light blue, we use white/dark blue to be similar, yet different.
    defb    0F4h
    ; No sprites in text mode, Pattern gen, attribute table, pattern gen, color table all zero
    defb    00h, 00h , 00h, 00h
    ; Name table address => 800h    (2 * 400h)
    defb    02h
    ; Flags 1: 16k, Enable, Interrupt Enable, Mode bits 10, Size = 8x8, Mag = 1*
    defb    0F0h
    ; Flags 0: mode bit 3=0, Esternal VDP disable.
    defb    00h

