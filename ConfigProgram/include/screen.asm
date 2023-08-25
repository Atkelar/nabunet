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

    xor a
    ld (CURSOR_OFFSET), a
    ld (CURSOR_POSITION_X), a
    ld (CURSOR_POSITION_Y), a
    ld (CURSOR_ORIGINAL_CHAR), a

    ld a, VDP_COLOR_WHITE << 4 | VDP_COLOR_DARK_BLUE
    call clear_screen

    ld a, CURSOR_DEFAULT_STYLE
    call set_cursor_style

    ld a,1  ; 1 => visible
    call set_cursor_visible

    ret

; Overall concepts:
;  Screen modes GFX1, GFX2 and TEXT have "text mode" features. The "Multicolor" mode (MC) is not
;  really designed for characters on screen, so we don't support it in any of the "text" based
;  outputs.

; "goto_xy" - put the cursor to location X/Y on the screen.

; "print" - print 0-terminated string to current cursor location. Includes handling for \n and 
;           similar control characters.

; "clear_eol" - clears the remaining line - current cursor position to the end of the line,
;               the cursor is NOT moved though.

; "clear_screen" - clears the entire screen, positions the cursor to the top left corner (0/0)

; "load_font" - loads a character set into screen memory. Can be a partial charset too.

; "set_cursor_style" - configures the cursor style: line width.

; "set_cursor_visible" - enables/disables the cursor on screen.

; Cursor concept: The VDP doesn't support a hardware cursor. To compensate for that, we take the
; character underneath the current cursor location, pick out the bitmap from the charset ROM,
; invert the lines that make up the cursor, and save that as "charcter 0". To blink the cursor,
; all that's needed is to flip the current character between 0 and whatever it was.
; This requires that the cursor is carefully controlled: 
;   * disable interrupts during enable/disable operations to prevent racing the flip code.
;   * update cursor bitmap whenever the cursor location changes to a different character.
; Internally, there's a "save/restore" cursor procedure available to properly disable and
; re-enable the cursor and prevent run ins with the interrupt code, so that lengthy
; operations (like print, or clear screen) don't have to disable the interrupts
; and still can rely on a proper result.


; a -> low nibble: line count -1, 0->7 for 1->8 lines
;      high nibble: top skip lines: 0-7.
set_cursor_style:
    push af
    call .disable_cursor_for_screen_proc
    pop af

    and 077h    ;  both values max out at 3-bits.

    ld b, a
    and 070h
    ld c, a
    ld a, b
    and 7
    sla a
    or c
    ld b, a
    di
    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_BLINKON ; | CURSOR_FLAG_VISIBLE visible flag should certainly be off here...
    or b
    ld (CURSOR_FLAGS), a
    xor a
    ld (CURSOR_ORIGINAL_CHAR), a    ; make sure we re-compute the current bitmap on next "enable"
    ei
    
    call .enable_cursor_for_screen_proc
    ret

set_cursor_visible:
    ; check if  we need to toggle anything, shortcut if we don't.
    or a
    jr z, .set_cursor_invisible
    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_VISIBLE
    ret nz  ; already visible...
    jr .cursor_enable_now   
.set_cursor_invisible:
    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_VISIBLE
    ret z  ; already invisble...

    ; when enabling the cursor, we need to check and possibly update the bitmap, when disabling, we can ignore that.
    ; we disable the cursor: reset the current code. Importent: read/update needs to be guarded,
    ; since an enabled cursor might be handled by the interrupt at any time.
    di
    ld a, (CURSOR_FLAGS)
    and ~CURSOR_FLAG_VISIBLE
    ld (CURSOR_FLAGS), a
    ei

    and CURSOR_FLAG_BLINKON ; check if we currently have the "inverted" char on screen...
    ret z   ; no, all done.    
    ; set target address...
    ld hl, (CURSOR_OFFSET)
    ld de, VDP_SCREEN_BASE
    add hl, de
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; set "address selection bit"
    out (IO_VDP_CONTROL), a
    ld a, (CURSOR_ORIGINAL_CHAR)
    out (IO_VDP_DATA), a    ; write original character.
    ret

.cursor_enable_now:
   ; 1.: compute cursor offset for simplification of flip code later.
    ld a, (CURSOR_POSITION_Y)
    ld b, a
    ld a, (CURSOR_POSITION_X)
    ld c, a
    push bc
    call .calculate_screen_offset
    pop bc
    ld (CURSOR_OFFSET), hl  ; save for later use too.
    ; 2.: read current character from screen and remember.
    ld de, VDP_SCREEN_BASE
    add hl, de
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    out (IO_VDP_CONTROL), a
    in a, (IO_VDP_DATA) ; read current code.
    or a    ; did we accidentally end up at a zero char?
    jr nz, .cursor_original_nonzero
    ld a, 020h  ; we update "0" to space!
.cursor_original_nonzero:
    ld b, a
    ld a, (CURSOR_ORIGINAL_CHAR)
    ; 3.: if it is the same character that we already have (likely, probably space aynway)
    cp b
    jr z, .cursor_original_preset_ok    ; no change needed.

    ; different char now...
    ld a, b
    ld (CURSOR_ORIGINAL_CHAR), a

    ; 4.: now we need to read the bitmap info and save it back to the character set
    ;     since the VDP address is shared between read/write, we need to buffer the 8 bytes...

    ld d, 0     
    ld e, a     ; char index...
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d       ; offset * 8 for 8-bytes per char...
    ld hl, VDP_CHARSET_BASE
    add hl, de

    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    out (IO_VDP_CONTROL), a

    ld b, 8
    ld c, IO_VDP_DATA
    ld hl, CURSOR_BITMAP_BUFFER

    inir    ; load the 8 bytes.

    ; 5.: now, invert the bytes indexed between start/end line number...
    ld hl, CURSOR_BITMAP_BUFFER
    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_SKIP_MASK
    ld c, 8
.cursor_bitmap_skip_loop:
    or a
    jr z, .cursor_bitmap_skip_done
    inc hl
    dec c
    sub CURSOR_FLAG_SKIP_INC
    jr .cursor_bitmap_skip_loop
.cursor_bitmap_skip_done:

    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_HEIGHT_MASK
.cursor_bitmap_invert_loop:
    ld b, a

    ld a, (hl)
    cpl
    ld (hl), a
    inc hl

    ld a, b
    dec c
    jr z, .cursor_bitmap_invert_done

    or a
    jr z,.cursor_bitmap_invert_done ;   check post loop, so that 0=1, 7=8...
    sub a, CURSOR_FLAG_HEIGHT_INC
    jr .cursor_bitmap_invert_loop

.cursor_bitmap_invert_done:
    ld hl, VDP_CHARSET_BASE
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; set address selection bit
    out (IO_VDP_CONTROL), a

    ld b, 8
    ld c, IO_VDP_DATA
    ld hl, CURSOR_BITMAP_BUFFER

    otir    ; load the 8 bytes to the charset memory.

.cursor_original_preset_ok:

    ld a, (CURSOR_FLAGS)
    or CURSOR_FLAG_VISIBLE
    and ~CURSOR_FLAG_BLINKON & 0xFF    ; the next interrupt should flip to the inverted character now. We don't do it here, 
                                ; to avoid duplication.
    ld (CURSOR_FLAGS), a        ; no DI/EI requried, THIS is the only critical storage access, atomic anyway.   

    ret

.disable_cursor_for_screen_proc:
    ; disable the cursor IF it is currently enabled, memorizing the state in the screen buffer temp area.
    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_VISIBLE
    ld (CURSOR_BITMAP_BUFFER), a
    or a
    ret z       ; cursor already off.
    xor a
    call set_cursor_visible     ; turn off.
    ret

.enable_cursor_for_screen_proc:
    ; enable the cursor IF it is was previously enabled, as stored in the screen buffer temp area.
    ld a, (CURSOR_BITMAP_BUFFER)
    or a
    ret z   ; cursor was off...
    ld a, 1
    call set_cursor_visible     ; turn on
    ret


; Fills the current line (cursor X/Y) with spaces until the right edge of the screen, 
; not changing the current cursor location
clear_eol:
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; we don't "print" in MC mode...

    call .disable_cursor_for_screen_proc

    ; initialize starting address in VDP...
    ld a, (CURSOR_POSITION_Y)
    ld b, a
    ld a, (CURSOR_POSITION_X)
    ld c, a
    push bc
    call .calculate_screen_offset
    pop bc

    ; set target address...
    ld de, VDP_SCREEN_BASE
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

    call .enable_cursor_for_screen_proc
    ret

; fills the current screen with "blanks" (character index 32) in text/gfx1/gfx2 modes, zero in MC mode.
;   foreground/background color in "a" will be used to setup color according to the screen mode.

clear_screen:
    ld b, a
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z

    ld a, b
    push af
    call .disable_cursor_for_screen_proc
    pop af


.textmode_clear:
    ; write color code to register 7
    out (IO_VDP_CONTROL), a
    ld a, 87h
    out (IO_VDP_CONTROL), a
    
    jr .common_clear


.common_clear:
    xor a
    ld (CURSOR_POSITION_X), a
    ld (CURSOR_POSITION_Y), a
    ld (CURSOR_ORIGINAL_CHAR), a    ; none yet.

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

    call .enable_cursor_for_screen_proc

    ret

; input: HL = address of string, 0-terminated.
; handles "newline" (0x0A) as CR/LF and does scrolling if needed.
; keeps track of cursor X/Y...
print:
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; we don't "print" in MC mode...

    push hl
    call .disable_cursor_for_screen_proc
    pop hl

    di  ; we might be thrown off by IRQ code...

    ; initialize starting address in VDP...

    push hl

    ld a, (CURSOR_POSITION_Y)
    ld b, a
    ld a, (CURSOR_POSITION_X)
    ld c, a
    push bc
    call .calculate_screen_offset
    pop bc

    ld de, VDP_SCREEN_BASE
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

    ; slightly complicated; we need to save our state...
    ; ...but the VDP write address is re-computed for the linefeed condition 
    ; downstairs anyaway, so we don't care if it gets hosed in the scroll code.
    push hl
    push af
    push de
    push bc
    ld a, 1
    ld b, 020h
    call .scroll_up
    pop bc
    pop de
    pop af
    pop hl

    dec a   ; stay at bottom line...
.no_scroll:
    ld b, a
    xor a
    ld c, a

    push hl
    push bc
    push de
    call .calculate_screen_offset
    ld de, VDP_SCREEN_BASE
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

    ei  ; we might be thrown off by IRQ code... enable interrupts again...

    call .enable_cursor_for_screen_proc
    ret

; Scroll the screen buffer UP (move lines from below to top)
; input: a => line count to scroll by...
;        b => character code to fill in for new line(s)
.scroll_up:
    or a
    ret z   ; nothign to do...
    ld c, a
    ld a, (SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; not supported..
    ld a, b
    ld (SCREEN_SCROLL_FILL), a
    ld a, c
    ld hl, SCREEN_HEIGHT
    cp (hl)
    jr c, .scroll_up_ok
    ret
.scroll_up_ok:
    ld a, (hl)
    sub c
    ld (SCREEN_SCROLL_COUNT), a
    ; source offset...
    push bc
    ld b, c
    ld c, 0
    ; input b = y, c = x
    call .calculate_screen_offset
    ; hl = source
    ld de, VDP_SCREEN_BASE
    add hl, de
    ld (SCREEN_SCROLL_SOURCE), hl
    ld hl, VDP_SCREEN_BASE
    ld (SCREEN_SCROLL_TARGET), hl

.scroll_up_loop:
    ; repeat until "count" is zero
    ld a, (SCREEN_SCROLL_COUNT)
    or a
    jr z, .scroll_up_fill_now
    dec a
    ld (SCREEN_SCROLL_COUNT), a

    ; read line from source,...
    ld hl,(SCREEN_SCROLL_SOURCE)
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    out (IO_VDP_CONTROL), a

    ld a, (SCREEN_WIDTH)
    ld b, a
    ld c, IO_VDP_DATA
    ld hl, SCREEN_SCROLL_BUFFER

    inir    ; load the x-dim bytes...
    ; ...write line to target...

    ld hl, (SCREEN_SCROLL_TARGET)
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; set "address selection bit"
    out (IO_VDP_CONTROL), a
    ld c, IO_VDP_DATA
    ld a, (SCREEN_WIDTH)
    ld b, a
    ld hl, SCREEN_SCROLL_BUFFER
    otir
    ; increment source, increment target
    ld a, (SCREEN_WIDTH)
    ld e, a
    ld d, 0
    ld hl, (SCREEN_SCROLL_SOURCE)
    add hl, de
    ld (SCREEN_SCROLL_SOURCE),hl
    ld hl, (SCREEN_SCROLL_TARGET)
    add hl, de
    ld (SCREEN_SCROLL_TARGET),hl

    jr .scroll_up_loop

.scroll_up_fill_now:
    ; target = must be the first "blank" line
    ld hl, (SCREEN_SCROLL_TARGET)
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; set "address selection bit"
    out (IO_VDP_CONTROL), a
    pop bc
    ld a, c
.scroll_up_fill_loop:
    or a
    ret z   ; done.
    dec a
    ld (SCREEN_SCROLL_COUNT), a ; fill "count" lines now...

    ld c, IO_VDP_DATA
    ld a, (SCREEN_WIDTH)
    ld b, a
    ld a, (SCREEN_SCROLL_FILL)
.scroll_up_fill_line_loop:
    out (IO_VDP_DATA), a
    dec b
    jr nz, .scroll_up_fill_line_loop
    ld a, (SCREEN_SCROLL_COUNT)
    jr .scroll_up_fill_loop
    
    ; fill end of screen with "filler" chars.
    ;SCREEN_SCROLL_BUFFER
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

    push bc
    ; make sure we don't get blinking signals...
    call .disable_cursor_for_screen_proc
    pop bc

    ld a, b
    ld (CURSOR_POSITION_Y), a
    ld a, c
    ld (CURSOR_POSITION_X), a

    call .enable_cursor_for_screen_proc
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
    add c
    ld l, a
    ret nc
    inc h
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
    ld c, a
    push bc
    push hl
    call .enable_cursor_for_screen_proc
    pop hl
    pop bc

    ld d, 0     
    ld e, c     ; first char index...
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
    or 040h
    out (IO_VDP_CONTROL), a

    ; now, get the source address from the stack...
    pop hl
    ;inc hl  ; ??? why?
    ld c, IO_VDP_DATA   ; output port...
    ld d, b
    ld a, 8 ; 8 bytes per char...
.repeat_load:
    ld b, d
    otir ; HL -> #C, B times.
    dec a
    jr nz, .repeat_load

    call .enable_cursor_for_screen_proc

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

