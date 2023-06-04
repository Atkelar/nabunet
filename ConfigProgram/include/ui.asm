; Some common UI functions: get user input as text...

; input: b=>y, c=>x, hl=>text buffer, d=buffer max length, e=screen line length
; output: Z if cancelled (ESC), NZ if confirmed (GO)
; NOTE: buffer content is edited in place, no matter what the outcome is!
; NOTE: Doesn't work in multicolor mode.
readline:
    ld a,(SCREEN_MODE)
    cp SCREEN_MODE_MCOL
    ret z   ; signal cancellation implicitly

    ; sanity checks first...
    ; input needs to be at least 1 characters long
    ; input buffer length can be larger/smaller than display
    ; input needs to be fully on screen



    ld a, d
    or a
    jr z, .sanity_failed

    ld a, e
    or a
    jr z, .sanity_failed
    add c
    dec a

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

    ld (.input_target_buffer), hl
    

    ret

.input_scroll_offset:    equ UI_VARIABLES_BASE
.input_current_length:   equ UI_VARIABLES_BASE + 1
.input_cursor_offset:    equ UI_VARIABLES_BASE + 2
.input_target_buffer:    equ UI_VARIABLES_BASE + 3
.input_max_length:       equ UI_VARIABLES_BASE + 5
.input_screen_length:    equ UI_VARIABLES_BASE + 6
.input_screen_x:         equ UI_VARIABLES_BASE + 7
.input_screen_y:         equ UI_VARIABLES_BASE + 8
