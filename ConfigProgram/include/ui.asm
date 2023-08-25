; Some common UI functions: get user input as text...

; input: b=>y, c=>x, hl=>text buffer, d=buffer max length, e=screen line length, c bit 7 set -> mask display "*" for passwords.
; output: Z if cancelled (ESC), NZ if confirmed (GO)
; NOTE: buffer content is edited in place, no matter what the outcome is!
; NOTE: Doesn't work in multicolor mode.
; NOTE: uses UI_BUFFER for "current visible line segment"
readline:
    ld a,(SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; signal cancellation implicitly

    ; sanity checks first...
    ; input needs to be at least 1 characters long
    ; input buffer length can be larger/smaller than display
    ; input needs to be fully on screen


    ld a, c
    and 080h
    jr z, .no_mask_requested
    ld a, 1
    ld (.input_masked),a
    ld a, c ; remove mask flag from x coordinate...
    and 07Fh
    ld c, a
    jr .do_sanity_check
.no_mask_requested:
    ld a, 0
    ld (.input_masked),a
.do_sanity_check:
    ld a, d
    or a
    jr z, .sanity_failed

    ld a, e
    or a
    jr z, .sanity_failed
    add c
    dec a

    ld (.input_target_buffer), hl

    ; TODO: reading to the bottom right corner will break things cause of scrolling (also TODO)
    ld hl, SCREEN_WIDTH
    ld a, c
    cp (hl)
    jr nc,.sanity_failed  ; width overflow

    ld hl, SCREEN_HEIGHT
    ld a, b
    cp (hl)
    jr nc,.sanity_failed  ; height overflow
    jr .is_sane

.sanity_failed:
    xor a
    ret
.is_sane:

    ; set up input line...
    ;  Left scroll position = 0
    ;  cursor position = end of existing input
    ;  "ensure cursor visible"
    ;  prepare buffer
    ;  gotoxy/print
    ;  gotoxy cursor position
    ; wait for key
    ;  left/right home/end -> move cursor, call "ensure cursor visible", call "prepare buffer" and print if moved, position cursor
    ;  esc -> report cancel
    ;  go -> report done    (TODO: validation callback so we don't lose our state?)
    ;  delete -> backspace
    ;  ctrl-x -> clear
    ;  other key between 0x20 -> 0x7f: insert key as character.

    ; variables needed - this is a complex functionallity, better not rely on enough registers...
    ;   scroll offset of text;
    ;   cursor offset inside text;
    ;   current length of text (to avoid counting every time)
    ;   target buffer location
    ld a, b
    ld (.input_screen_y), a
    ld a, c
    ld (.input_screen_x), a

    ld a, 0ffh
    ld (.input_scroll_offset), a    ; 100% too far right; this forces a re-location of the input line and proper redrawing without any additional flags/ifs.

    ld a, d
    ld (.input_max_length), a
    ld a, e
    ld (.input_screen_length), a

    ld hl, (.input_target_buffer)

    call strlen
    ld a, h
    or a
    jr nz, .sanity_failed   ; string longer than 255 chars...
    ld a, (.input_max_length)
    cp l
    jr c, .sanity_failed    ; string longer than max_length even...
    ld a, l
    ld (.input_current_length),a
    ld (.input_cursor_offset),a
.input_loop:
    call .ensure_cursor_visible
    call nz, .update_screen_buffer

    ld a, (.input_screen_x)
    ld c, a
    ld a, (.input_screen_y)
    ld b, a
    call goto_xy
    ld hl, UI_BUFFER
    call print
    ld a, (.input_scroll_offset)
    ld c, a
    ld a, (.input_cursor_offset)
    sub c
    ld c, a
    ld a, (.input_screen_x)
    add c
    ld c, a
    ld a, (.input_screen_y)
    ld b, a
    call goto_xy

    ;call .input_diagnostics_output

    call get_key    ; oooff... finally.


    cp 01bh ;  ESC
    jp z, .input_aborted

    cp 00dh ;  enter/go
    jp z, .input_accepted

    cp 07fh ; delete
    jr z, .backspace_or_delete

    cp 4 ; ctrl-d - clear all
    jp z, .clear_input

    cp 81h  ; cursor left
    jp z, .cursor_left

    cp 80h  ; cursor right
    jp z, .cursor_right
    
    cp 85h  ; left (home)
    jp z, .cursor_home

    cp 84h  ; right (end)
    jp z, .cursor_end

    cp 32
    jr c, .input_invalid
    cp 80h
    jr nc, .input_invalid

    ; if we are here, we got a regular character input...
    push af
    ; we need to make room for the new character
    ; beep if full...
    ld a, (.input_current_length)
    ld b, a
    ld a, (.input_max_length)
    cp b
    jr z, .input_full

    ld a, b
    inc a
    ld (.input_current_length), a
    ld hl, (.input_target_buffer)
    ld e, b
    ld d, 0
    add hl, de
    ld d, h
    ld e, l
    inc de

.loop_shift_chars:  ; run once at the least, because zero-term char...
    ld a, (hl)
    ld (de), a
    dec de
    dec hl
    ld a, (.input_cursor_offset)
    cp b
    jr z, .loop_shift_chars_done    ; are we at the target location?
    dec b
    jr .loop_shift_chars
.loop_shift_chars_done:

    pop af
    ld (de), a
    ld a, (.input_cursor_offset)
    inc a
    ld (.input_cursor_offset), a
    call .update_screen_buffer  ; might be called twice, but hey, it's text input...
    jp .input_loop

.input_full:
    pop af
    ; call beep?
    jp .input_loop

.input_invalid:
    ; call beep?
    jp .input_loop

.backspace_or_delete:
    ; sym-delete: delete char under cursor, normal: delete left

    ld bc, KBD_STATE_SYM
    call get_special_keys
    ; was "syn" key pressed?
    jr nz, .pretend_delete_key
    ; we are backspacing, delete char to the left of the cursor...
    ld a, (.input_cursor_offset)
    or a
    jr z, .input_invalid    ; beep, we are at the start of the line!
    dec a
    ld (.input_cursor_offset), a
    jr .delete_current_char_now

.pretend_delete_key:
    ; delete current character...
    ld a, (.input_current_length)
    ld b,a
    ld a, (.input_cursor_offset)
    cp b
    jr z, .input_invalid    ; end of line already...

.delete_current_char_now:
    ld hl, (.input_target_buffer)
    ld d, 0
    ld a, (.input_cursor_offset)
    ld e, a
    add hl, de
    ld d,h
    ld e,l
    inc hl
.delete_char_loop:
    ld a, (hl)
    ld (de),a
    inc hl
    inc de
    or a
    jr nz, .delete_char_loop
    ld a, (.input_current_length)
    dec a
    ld (.input_current_length), a
    call .update_screen_buffer  ; might be called twice, but hey, it's text input...
    jp .input_loop

.clear_input:
    xor a
    ld hl, (.input_target_buffer)
    ld (hl), a
    ld (.input_cursor_offset), a
    ld (.input_current_length), a
    jp .input_loop

.input_aborted:
    xor a
    ret
.input_accepted:
    ld a, 1
    or a
    ret

.cursor_left:
    ld a, (.input_cursor_offset)
    or a
    jp z, .input_loop
    dec a
    ld (.input_cursor_offset),a
    jp .input_loop

.cursor_home:
    xor a
    ld (.input_cursor_offset),a
    jp .input_loop

.cursor_end:
    ld a, (.input_current_length)
    ld (.input_cursor_offset),a
    jp .input_loop

.cursor_right:
    ld a,(.input_cursor_offset)
    ld b, a
    ld a, (.input_current_length)
    cp b
    jp z, .input_loop
    inc b
    ld a,b
    ld (.input_cursor_offset), a
    jp .input_loop


.update_screen_buffer:
    ; move string content from HL+.input_scroll_offset -> .UI_BUFFER, max or fill space to .screen_length
    ; use "*" instead of chars if "mask requested"
    ld a, (.input_screen_length)
    ld b, a
    ld hl, (.input_target_buffer)
    ld a, (.input_scroll_offset)
    ld e, a
    ld d, 0
    add hl, de
    ld de, UI_BUFFER
    ld a, (.input_masked)
    or a
    jr nz, .update_screen_buffer_masked_loop
.update_screen_buffer_loop:
    ld a, (hl)
    or a
    jr z, .fill_screen_buffer
    ld (de), a
    inc de
    inc hl
    dec b
    jr nz, .update_screen_buffer_loop
    jr .update_done_terminate

.fill_screen_buffer:
    ld a, 32
.fill_screen_buffer_loop:
    ld (de), a
    inc de
    dec b
    jr nz, .fill_screen_buffer_loop
    jr .update_done_terminate

.update_screen_buffer_masked_loop:
    ld a, (hl)
    or a
    jr z, .fill_screen_buffer
    ld a, "*"
    ld (de), a
    inc de
    inc hl
    dec b
    jr nz, .update_screen_buffer_masked_loop

.update_done_terminate:
    xor a
    ld (de), a
    ret



.ensure_cursor_visible:
    ; adjust ".input_scroll_offset" so that the cursor is within the visible screen area.
    ; that means: if the cursor is out to the left or right, scoot over by a few chars, limiting to 0 and max length
    ; return: z if unchanged, nz if the location has changed.
    ; Visualization:

    ;   0------|---C----|----E      Cursor OK, don't move.
    ;   0----C-|--------|----E      Cursor to the left. Move in chunks of 1/4th the length of the visibe area until C is fine again.
    ;   0------|--------|--C-E      Cursor to the right. Move in chunks of 1/4th the length of the visibe area until C is fine again.

    ; absolute limits:
    ;  0 for leftmost postion. Never go below zero!
    ;  maxlength - width, i.e. "rightmost visible character = maximum possible character"
    ld a, (.input_scroll_offset)
    ld b,a
    ld a, (.input_cursor_offset)
    cp b
    jr c, .cursor_out_left

    ld c, a
    ld a, (.input_screen_length)
    add b
    cp c
    jr c, .cursor_out_right

    xor a   ; neither is out, we are OK.
    ret

.cursor_out_left:
    ld a, (.input_screen_length)
    srl a
    srl a   ; div 4
    jr nz, .cursor_left_step_OK
    ld a, 1
.cursor_left_step_OK:
    ld d, a
.cursor_left_loop:
    ld a, (.input_scroll_offset)
    sub d
    jr nc, .cusror_left_OK
    xor a
.cusror_left_OK:
    ld (.input_scroll_offset), a
    ld b,a
    ld a, (.input_cursor_offset)
    cp b
    jr c, .cursor_left_loop
    jr .done_with_move

.cursor_out_right:
    ld a, (.input_screen_length)
    srl a
    srl a   ; div 4
    jr nz, .cursor_ight_step_OK
    ld a, 1
.cursor_ight_step_OK:
    ld d, a
.cursor_right_loop:
    ld a, (.input_scroll_offset)
    add d
    ld (.input_scroll_offset), a
    ld b,a
    ld a, (.input_cursor_offset)
    ld c, a
    ld a, (.input_screen_length)
    add b
    jr c, .cursor_right_overflow
    cp c
    jr c, .cursor_out_right
.done_with_move:
    ld a, 1
    or a
    ret

.cursor_right_overflow:
    ; limit to "maxlength - width"
    ld a, (.input_screen_length)
    ld b, a
    ld a, (.input_max_length)
    sub b
    jr c, .cursor_fixed_zero
    ld (.input_cursor_offset), a
    jr .done_with_move
.cursor_fixed_zero:    
    ld a, 0
    ld (.input_cursor_offset), a
    jr .done_with_move




; MENU handling - provide a simple centralized 1..n style menu
; input:        hl -> address of menu structure.
;               b = y position
;               c = x position  upper left section. One line per item.
;               a = default option
;
; conditions: not supported in multicolor mode.
; returns:  z -> cancelled (ESC)
;           nz -> selected option #x in A (1..n)

;
;   Menu structure: <key>  byte, key to bind to, needs to be A-Z, 0-9 range. Case is ignored on input, but needs definition as upper case! 0 = end of structure, 1 = empty line (rest is ignored), 2 = label only (no selection)
;                   <res>  byte, rserved for flags
;                   <addr> word, label address (0-term string)
;                   <addr> word, address for callback code
;                   
;

; Call: calls the a-th (1..n) entry in the HL provided menu structure, if there is a callback address provided. 
screen_menu_call:
    ld d, a

.screen_menu_call_loop:
    ld a, (hl)
    or a
    ret z
    inc hl
    inc hl
    inc hl
    inc hl
    dec d
    jr nz, .skip_item_call

    ; we are here!
    ld e, (hl)
    inc hl
    ld a, (hl)
    ld d,a 
    or e
    ret z   ; no target specified!
    push de
    ret     ; push/ret trick...

.skip_item_call:
    inc hl
    inc hl
    jr .screen_menu_call_loop



screen_menu_run:
    ld d, a
    ld a,(SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; signal cancellation implicitly
    ld a, d
    call .screen_menu_init  ; use this version for first call, to initialized variables.

    call .validate_position
    jr nz, .screen_menu_loop
    xor a
    ld (.input_cursor_offset), a
.screen_menu_loop:
    call .screen_menu_print_now
    call get_key

    cp KEY_CODE_ESC ; ESC
    jr z, .screen_menu_exit

    cp KEY_CODE_ENTER
    jr z, .screen_menu_select_current

    cp KEY_CODE_UP
    jr z, .screen_menu_move_up

    cp KEY_CODE_DOWN
    jr z, .screen_menu_move_down

    cp KEY_CODE_0
    jr c, .screen_menu_invalid_key

    cp KEY_CODE_9+1
    jr c, .find_menu_item_by_hotkey

    ; assume a-z
    and 0DFh ; bring to a-z upper case...
    cp KEY_CODE_A_UPPER
    jr c, .screen_menu_invalid_key
    cp KEY_CODE_Z_UPPER+1
    jr nc, .screen_menu_invalid_key
.find_menu_item_by_hotkey:
    ; now we have a = code to look for...
    ld c, 1
    ld b, a
    ld d, 0
    ld e, 6
    ld hl, (.input_target_buffer)
.find_menu_item_by_hotkey_loop:
    ld a, (hl)
    or a 
    jr z, .screen_menu_loop
    cp b
    jr nz, .find_menu_item_by_hotkey_next
    ld a, c
    or a
    ret
.find_menu_item_by_hotkey_next:
    add hl, de
    inc c
    jr .find_menu_item_by_hotkey_loop

.screen_menu_select_current:
    ld a, (.input_cursor_offset)
    inc a
    or a    ; must be non-zero here...
    ret
.screen_menu_exit:
    xor a   ; z and a=0
    ret

.screen_menu_move_up:
    ld a, (.input_cursor_offset)
    or a
    jr nz,.move_up_now  ; we are on top!
    ld a, (.input_current_length)
.move_up_now:
    dec a
    ld (.input_cursor_offset), a
    call .validate_position
    jr z, .screen_menu_move_up
    ; call beep
    jr .screen_menu_loop

.screen_menu_move_down:
    ld a, (.input_current_length)
    ld b, a
    ld a, (.input_cursor_offset)
    inc a
    cp b
    jr nz,.move_down_now  ; we are on top!
    xor a
.move_down_now:
    ld (.input_cursor_offset), a
    call .validate_position
    jr z, .screen_menu_move_down
    jr .screen_menu_loop

.screen_menu_invalid_key:
    ; call beep
    jr .screen_menu_loop

.validate_position:
    ; now we have a = code to look for...
    ld hl, (.input_target_buffer)

    ld a, (.input_cursor_offset)
    ld d, 0
    ld e, 6

.validate_next_position:
    or a
    jr z, .validate_this_position
    add hl, de
    dec a
    jr .validate_next_position
.validate_this_position:

    ld a, (hl)
    cp 3
    jr nc, .validate_is_valid_position

    xor a
    ret
    
.validate_is_valid_position:
    ld a, 1
    or a
    ret ; nz on valid


; MENU print the current menu; same parameters as the screen_menu_run method, but doesn't wait or handle any key input.
screen_menu_print:
    ld d, a
    ld a,(SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; signal cancellation implicitly
    ld a, d
    call .screen_menu_init  ; use this version for first call, to initialized variables.
    call .screen_menu_print_now
    ret

.screen_menu_init:
    or a
    jr z, .screem_menu_init_preselection_ok
    dec a   ; menu item is 1-based
.screem_menu_init_preselection_ok:
    ld (.input_cursor_offset), a
    ld a, b
    ld (.input_screen_y), a
    ld a, c
    ld (.input_screen_x), a
    ld (.input_target_buffer), hl

    xor a
    ld (.input_current_length), a

    ; step 1: count # of entries and limit to screen height for sanity...
    ld a, (SCREEN_HEIGHT)
    ld c, a
    ; b = y, increment until >= c
    ld d, 0
    ld e, 6 ; size of entry...
    
.count_items_loop:
    ld a, b
    cp c
    jr nc, .count_left_screen_or_done
    jr z, .count_left_screen_or_done
    ld a, (hl)
    or a
    jr z, .count_left_screen_or_done
    ld a, (.input_current_length)
    inc a
    ld (.input_current_length), a
    inc b
    add hl, de
    jr .count_items_loop

.count_left_screen_or_done:
    ret

; internal code to print the screen menu, based on initialized varaibales.
.screen_menu_print_now:
    ld hl, (.input_target_buffer)
    ld d, 0

.screen_menu_item_loop:

    ld a, (.input_screen_x)
    ld c, a
    ld a, (.input_screen_y)
    add d
    ld b, a
    push hl
    push de
    call goto_xy
    pop de
    pop hl

    ld a, (hl)
    or a
    ret z

    cp 1
    jr z, .menu_item_done    ; empty entry, no print...

    cp 2
    jr nz, .screen_menu_key_set
    ld a, 020h  ; whitespace...
.screen_menu_key_set:
    ld (.menu_key_buffer), a    ; push char...
    push hl
    push de
    ld hl, .menu_key_buffer
    call print
    pop de
    pop hl

    push hl
    push de
    ld hl, .menu_marker_unselected

    ld a, (.input_cursor_offset)
    cp d
    jr nz, .menu_marker_set
    ld hl, .menu_marker_selected

.menu_marker_set:
    call print
    pop de
    pop hl

    push hl
    push de

    inc hl
    inc hl

    ld e, (hl)
    inc hl
    ld d, (hl)
    push de
    pop hl

    call print

    pop de
    pop hl

.menu_item_done:
    inc hl
    inc hl
    inc hl
    inc hl
    inc hl
    inc hl

    inc d
    jr .screen_menu_item_loop

; .input_diagnostics_output:
;     ld b, 18
;     ld c, 2
;     call goto_xy
;     ld a, (.input_scroll_offset)
;     call print_hex_8
;     ld hl, .diag_spacer
;     call print

;     ld a, (.input_current_length)
;     call print_hex_8
;     ld hl, .diag_spacer
;     call print

;     ld a, (.input_cursor_offset)
;     call print_hex_8
;     ld hl, .diag_spacer
;     call print

;     ld a, (.input_screen_length)
;     call print_hex_8
;     ld hl, .diag_spacer
;     call print

;     ld a, (.input_max_length)
;     call print_hex_8
;     ld hl, .diag_spacer
;     call print

;     ld hl, (.input_target_buffer)
;     ld b,h
;     ld c,l
;     call print_hex_16
;     ld hl, .diag_spacer
;     call print

;     ld hl, .input_target_buffer
;     ld b,h
;     ld c,l
;     call print_hex_16

;     ret

;.diag_spacer: defb "/",0


.input_scroll_offset:    equ UI_VARIABLES_BASE
.input_current_length:   equ UI_VARIABLES_BASE + 1
.input_cursor_offset:    equ UI_VARIABLES_BASE + 2
.input_target_buffer:    equ UI_VARIABLES_BASE + 3
.input_max_length:       equ UI_VARIABLES_BASE + 5
.input_screen_length:    equ UI_VARIABLES_BASE + 6
.input_screen_x:         equ UI_VARIABLES_BASE + 7
.input_screen_y:         equ UI_VARIABLES_BASE + 8
.input_masked:           equ UI_VARIABLES_BASE + 9

.menu_marker_selected:   defb "->", 0
.menu_marker_unselected: defb "  ", 0
.menu_key_buffer:        defb " :", 0