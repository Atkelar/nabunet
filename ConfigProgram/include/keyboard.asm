; keyboard input functions - combined wiht the IRQ code - to handle the input buffers/flags.

; wait for a key in the buffer, if found, return the key code in "a"
get_key:
    ld hl, KBD_BUFFER_END
    ; wait for key...
.get_key_wait:
    ld a, (KBD_BUFFER_START)
    cp (hl)
    jr z, .get_key_wait

    ; got a key... now read/remove from buffer...
    ; disable interrupts for the operation so we don't have a race condition in the buffer handling code.
    di
    ld hl, KBD_BUFFER
    add l
    jr nc, .nocarry
    inc h
.nocarry:
    ld l, a
    ld a, (hl)
    ld c, a ; key code!
    ld a, (KBD_BUFFER_START)
    inc a
    cp KBD_BUFFER_LENGTH
    jr c, .no_buffer_loop
    xor a
.no_buffer_loop:
    ld (KBD_BUFFER_START),a
    ei

    ld a, c
  
    ;; diagnostics: output pressed key for validation...
    ; ld (.diag_buffer), a
    ; ld hl, .diag_buffer
    ; call print
    ; ld a, (.diag_buffer)

    ret

; .diag_buffer:
;     defb 0,0,0

; returns "NZ" when a key is in the buffer, "Z" when not.
key_available:
    ld a, (KBD_BUFFER_START)
    ld b, a
    ld a,(KBD_BUFFER_END)
    cp b
    ret

; returns the state of the special keys in "bc"
get_special_keys:
    ld bc, (KEY_STATES)
    ret

; returns the state of the joysticks in "bc" - c => joystick 1, b => joystick 2
get_joystick_state:
    ld bc, (JOY_STATUS_1)   ; status 2 is following 1, so load 16-bit
    ret
