; functions to test various low level things in the NABU

diagnostics_menu:
    ;ld a, 0e4h
    ld a, (VDP_COLOR_WHITE << 4) | VDP_COLOR_DARK_RED
    call clear_screen
    ld hl,.screen_header
    call print



.diag_menu_loop:    
    
    ld hl, .menu_items
    ld a, 1
    ld c, 8
    ld b, 4
    call screen_menu_run
    ret z
    ld hl, .menu_items
    call screen_menu_call

    jp diagnostics_menu


.keyboard_test:
    ld a, 0
    call set_cursor_visible
    ld c, 0
    ld b, 20
    call goto_xy
    call clear_eol
    ld hl, .keyboard_test_header
    call print
    ld c, 0
    ld b, 21
    call goto_xy
    call clear_eol
    ld c, 0
    ld b, 22
    call goto_xy
    call clear_eol
    ld b, 22
    ld c, 20
    call goto_xy
    ld hl, .keyboard_code_header
    call print
    ld c, 0
    ld b, 23
    call goto_xy
    call clear_eol
    ld b, a
    ld a, (.keyboard_test_last_char)

.keyboard_test_loop:
    call key_available
    jr z, .no_key_in_buffer

    ld c, 20
    ld b, 23
    call goto_xy

    call get_key
    cp 020h
    jr nz, .keyboard_loop_continue

    ld b, a
    ld a, (.keyboard_test_last_char)
    cp b
    jr z, .keyborad_test_done
    ld a, b
.keyboard_loop_continue:
    ld (.keyboard_test_last_char), a
    call print_hex_8

.no_key_in_buffer:

    ld c, 25
    ld b, 23
    call goto_xy
    call get_special_keys
    call print_hex_16

    ld c, 31
    ld b, 23
    call goto_xy
    call get_joystick_state
    call print_hex_16

    jr .keyboard_test_loop

.keyborad_test_done:
    ld a, 1
    call set_cursor_visible
    ret

.cursor_test:
    ld a, (VDP_COLOR_WHITE << 4) | VDP_COLOR_DARK_RED
    call clear_screen
    ld hl, .cursor_test_message
    call print
    ld b, 12
    ld c, 18
    call goto_xy
    ld hl, .cursor_test_area
    call print
    ld b, 12
    ld c, 20
    call goto_xy
    ld a, CURSOR_DEFAULT_STYLE
    ld (.cursor_test_style), a
    ld a, 1
    ld (.cursor_test_on), a

.cursor_test_loop:
    ld a,(.cursor_test_on)
    call set_cursor_visible

; a -> low nibble: line count -1, 0->7 for 1->8 lines
;      high nibble: top skip lines: 0-7.
    ld a, (.cursor_test_style)
    call set_cursor_style

.cursor_test_key_loop:
    call get_key
    cp KEY_CODE_ESC
    jp z, .cursor_test_done

    cp KEY_CODE_SPACE
    jp z, .cursor_toggle

    or KEY_CODE_MAKE_LOWER
    cp KEY_CODE_A_LOWER
    jr z, .cursor_start_minus
    cp KEY_CODE_S_LOWER
    jr z, .cursor_start_plus
    cp KEY_CODE_D_LOWER
    jr z, .cursor_len_minus
    cp KEY_CODE_F_LOWER
    jr z, .cursor_len_plus
    cp KEY_CODE_X_LOWER
    jr z, .cursor_show_data

    jp .cursor_test_key_loop

.cursor_show_data:
    ld b, 14
    ld c, 10
    call goto_xy
    ld hl,.cursor_test_info1
    call print
    ld a, (.cursor_test_style)
    call print_hex_8

    ld a, (.cursor_test_on)
    or a
    jr z, .cursor_is_invisible
    ld hl,.cursor_test_visible
    jr .cursor_info_done
.cursor_is_invisible:
    ld hl,.cursor_test_invisible
.cursor_info_done:
    call print
    ld b, 12
    ld c, 20
    call goto_xy
    jp .cursor_test_loop
.cursor_start_minus:
    ld a, (.cursor_test_style)
    ld b, a
    and 0f0h
    jp z, .cursor_test_loop
    ld a, b
    sub 010h
    ld (.cursor_test_style), a
    jp .cursor_test_loop

.cursor_len_minus:
    ld a, (.cursor_test_style)
    ld b, a
    and 0fh
    jp z, .cursor_test_loop
    ld a, b
    sub 01h
    ld (.cursor_test_style), a
    jp .cursor_test_loop

.cursor_start_plus:
    ld a, (.cursor_test_style)
    ld b, a
    and 0f0h
    cp 070h
    jp nc, .cursor_test_loop
    ld a, b
    add 010h
    ld (.cursor_test_style), a
    jp .cursor_test_loop

.cursor_len_plus:
    ld a, (.cursor_test_style)
    ld b, a
    and 0fh
    cp 07h
    jp nc, .cursor_test_loop
    ld a, b
    add 01h
    ld (.cursor_test_style), a
    jp .cursor_test_loop

.cursor_toggle:
    ld a, (.cursor_test_on)
    xor 1
    and 1
    ld (.cursor_test_on), a
    jp .cursor_test_loop
.cursor_test_done:
    ld a, CURSOR_DEFAULT_STYLE
    call set_cursor_style
    ld a, 1
    call set_cursor_visible
    ret

.print_test:
    ld a, (VDP_COLOR_WHITE << 4) | VDP_COLOR_DARK_RED
    call clear_screen
    ld hl, .print_test_header
    call print
    ld a, 1
    ld (.print_test_slow),a

    ld a, 120
    call delay_frames

.print_test_loop:
    ld hl, .print_test_message
    call print
    call key_available
    jr nz, .print_key_ready

    ld a, (.print_test_slow)
    or a
    jr z, .print_test_loop
    ld a, 15
    call delay_frames
    jr .print_test_loop
    
.print_key_ready:
    call get_key
    cp KEY_CODE_ESC
    ret z
    cp KEY_CODE_SPACE
    jr z, .toggle_print_test_speed
    jr .print_test_loop

.toggle_print_test_speed:
    ld a, (.print_test_slow)
    xor 1
    ld (.print_test_slow),a
    jr .print_test_loop

.menu_items:
    defb "1", 0
    defw .Opt1
    defw .keyboard_test

    defb "2", 0
    defw .Opt2
    defw .cursor_test

    defb "3", 0
    defw .Opt3
    defw .print_test

    defb 0

.Opt1:
defb "Keyboard",0
.Opt2:
defb "Cursor Test",0
.Opt3:
defb "Print to Screen",0

.print_test_header:
defb " User ESC to abort, SPACE to toggle",10
defb " slow/fast mode...", 10, 0
.print_test_message:    ; could be any short text, should NOT be a divisor of 40 to cause odd line breaks for testing!
defb "Hello World! ",0

.cursor_test_message:
defb " use the following keys to 'configure'",10
defb " the cursor:", 10
defb "  [space] -> on/off",10
defb "  A/S     -> start minus/plus",10
defb "  D/F     -> height minus/plus",10
defb "  X       -> show info",10
defb "  ESC     -> exit",0
.cursor_test_area:
defb "->X<-", 0
.cursor_test_info1:
defb "Style: ",0
.cursor_test_visible:
defb " - visible",0
.cursor_test_invisible:
defb " - invisible",0

.screen_header:
defb 0f4h, 0f5h, 0f6h, 0f7h, 0f2h, 0f3h
defb " NABUNET Diagnostics"
defb 0ah

defb 0f8h, 0f9h, 0fah, 0fbh
defb "   ", 0c0h
defs 31, 0c4h
defb 0ah

defb 0fch, 0fdh, 0feh, 0ffh, 0ah, 0

.keyboard_test_header:
defb "Type keys; to terminate, use space twice", 0
.keyboard_code_header:
defb "code spcl joys", 0

.keyboard_test_last_char:
    defb 0
.cursor_test_style:
    defb 0
.cursor_test_on:
    defb 0
.print_test_slow:
    defb 1