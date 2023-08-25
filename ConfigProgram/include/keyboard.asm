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
; input: bc -> special key flag
; result: nz if all of the requested flags are set in the current state, bc -> current state.
get_special_keys:
    ld de, (KEY_STATES)
    ld a, d
    and b
    cp b
    jr z, .high_is_ok
    xor a
    ld b, d
    ld c, e
    ret ; set z
.high_is_ok:
    ld a, e
    and c
    cp c
    jr z, .low_is_ok
    xor a
    ld b, d
    ld c, e
    ret
.low_is_ok:
    ld a, 1
    ld b, d
    ld c, e
    or a
    ret

; returns the state of the joysticks in "bc" - c => joystick 1, b => joystick 2
get_joystick_state:
    ld bc, (JOY_STATUS_1)   ; status 2 is following 1, so load 16-bit
    ret



; constants for keyboard mappings
KEY_CODE_RIGHT:         equ 080h
KEY_CODE_LEFT:          equ 081h
KEY_CODE_UP:            equ 082h
KEY_CODE_DOWN:          equ 083h
KEY_CODE_ENTER:         equ 00dh
KEY_CODE_SPACE:         equ 020h
KEY_CODE_DELETE:        equ 07Fh
KEY_CODE_ESC:           equ 01bh
KEY_CODE_TAB:           equ 009h
KEY_CODE_PAUSE:         equ 089h
KEY_CODE_NABUTV:        equ 08Ah
KEY_CODE_YES:           equ 087h
KEY_CODE_NO:            equ 086h
KEY_CODE_PAGELEFT:      equ 085h
KEY_CODE_PAGERIGHT:     equ 084h


KEY_CODE_0:             equ 030h
KEY_CODE_1:             equ 031h
KEY_CODE_2:             equ 032h
KEY_CODE_3:             equ 033h
KEY_CODE_4:             equ 034h
KEY_CODE_5:             equ 035h
KEY_CODE_6:             equ 036h
KEY_CODE_7:             equ 037h
KEY_CODE_8:             equ 038h
KEY_CODE_9:             equ 039h

KEY_CODE_BANG:          equ 021h
KEY_CODE_AT:            equ 040h
KEY_CODE_HASH:          equ 023h
KEY_CODE_DOLLAR:        equ 024h
KEY_CODE_PERCENT:       equ 025h
KEY_CODE_CARET:         equ 05Eh
KEY_CODE_AMP:           equ 026h
KEY_CODE_ASTERISK:      equ 02Ah
KEY_CODE_OPEN_PAR:      equ 028h
KEY_CODE_CLOSE_PAR:     equ 029h

KEY_CODE_OPEN_BRACE:    equ 07Bh
KEY_CODE_CLOSE_BRACE:   equ 07Dh

KEY_CODE_OPEN_BRACKET:  equ 05Bh
KEY_CODE_CLOSE_BRACKET: equ 05Dh

KEY_CODE_COLON:         equ 03Bh
KEY_CODE_APOS:          equ 027h
KEY_CODE_QUOT:          equ 022h
KEY_CODE_SEMICOLON:     equ 03Ah

KEY_CODE_COMMA:         equ 02Ch
KEY_CODE_PERIOD:        equ 02Eh
KEY_CODE_SLASH:         equ 02Fh
KEY_CODE_QUESTION:      equ 03Fh
KEY_CODE_LESSER:        equ 03Ch
KEY_CODE_GREATER:       equ 03Eh


KEY_CODE_MINUS:         equ 02Dh
KEY_CODE_UNDERSCORE:    equ 05Fh
KEY_CODE_PLUS:          equ 02Bh
KEY_CODE_EQUALS:        equ 03Dh

KEY_CODE_A_CONTROL:       equ 001h
KEY_CODE_B_CONTROL:       equ 002h
KEY_CODE_C_CONTROL:       equ 003h
KEY_CODE_D_CONTROL:       equ 004h
KEY_CODE_E_CONTROL:       equ 005h
KEY_CODE_F_CONTROL:       equ 006h
KEY_CODE_G_CONTROL:       equ 007h
KEY_CODE_H_CONTROL:       equ 008h
KEY_CODE_I_CONTROL:       equ 009h
KEY_CODE_J_CONTROL:       equ 00Ah
KEY_CODE_K_CONTROL:       equ 00Bh
KEY_CODE_L_CONTROL:       equ 00Ch
KEY_CODE_M_CONTROL:       equ 00Dh
KEY_CODE_N_CONTROL:       equ 00Eh
KEY_CODE_O_CONTROL:       equ 00Fh
KEY_CODE_P_CONTROL:       equ 010h
KEY_CODE_Q_CONTROL:       equ 011h
KEY_CODE_R_CONTROL:       equ 012h
KEY_CODE_S_CONTROL:       equ 013h
KEY_CODE_T_CONTROL:       equ 014h
KEY_CODE_U_CONTROL:       equ 015h
KEY_CODE_V_CONTROL:       equ 016h
KEY_CODE_W_CONTROL:       equ 017h
KEY_CODE_X_CONTROL:       equ 018h
KEY_CODE_Y_CONTROL:       equ 019h
KEY_CODE_Z_CONTROL:       equ 01Ah
KEY_CODE_OPEN_BRACKET_CONTROL:      equ 01Bh
KEY_CODE_CLOSE_BRACKET_CONTROL:     equ 01Ch

KEY_CODE_A_LOWER:       equ 061h
KEY_CODE_B_LOWER:       equ 062h
KEY_CODE_C_LOWER:       equ 063h
KEY_CODE_D_LOWER:       equ 064h
KEY_CODE_E_LOWER:       equ 065h
KEY_CODE_F_LOWER:       equ 066h
KEY_CODE_G_LOWER:       equ 067h
KEY_CODE_H_LOWER:       equ 068h
KEY_CODE_I_LOWER:       equ 069h
KEY_CODE_J_LOWER:       equ 06Ah
KEY_CODE_K_LOWER:       equ 06Bh
KEY_CODE_L_LOWER:       equ 06Ch
KEY_CODE_M_LOWER:       equ 06Dh
KEY_CODE_N_LOWER:       equ 06Eh
KEY_CODE_O_LOWER:       equ 06Fh
KEY_CODE_P_LOWER:       equ 070h
KEY_CODE_Q_LOWER:       equ 071h
KEY_CODE_R_LOWER:       equ 072h
KEY_CODE_S_LOWER:       equ 073h
KEY_CODE_T_LOWER:       equ 074h
KEY_CODE_U_LOWER:       equ 075h
KEY_CODE_V_LOWER:       equ 076h
KEY_CODE_W_LOWER:       equ 077h
KEY_CODE_X_LOWER:       equ 078h
KEY_CODE_Y_LOWER:       equ 079h
KEY_CODE_Z_LOWER:       equ 07Ah

KEY_CODE_MAKE_LOWER:    equ 020h

KEY_CODE_A_UPPER:       equ 041h
KEY_CODE_B_UPPER:       equ 042h
KEY_CODE_C_UPPER:       equ 043h
KEY_CODE_D_UPPER:       equ 044h
KEY_CODE_E_UPPER:       equ 045h
KEY_CODE_F_UPPER:       equ 046h
KEY_CODE_G_UPPER:       equ 047h
KEY_CODE_H_UPPER:       equ 048h
KEY_CODE_I_UPPER:       equ 049h
KEY_CODE_J_UPPER:       equ 04Ah
KEY_CODE_K_UPPER:       equ 04Bh
KEY_CODE_L_UPPER:       equ 04Ch
KEY_CODE_M_UPPER:       equ 04Dh
KEY_CODE_N_UPPER:       equ 04Eh
KEY_CODE_O_UPPER:       equ 04Fh
KEY_CODE_P_UPPER:       equ 050h
KEY_CODE_Q_UPPER:       equ 051h
KEY_CODE_R_UPPER:       equ 052h
KEY_CODE_S_UPPER:       equ 053h
KEY_CODE_T_UPPER:       equ 054h
KEY_CODE_U_UPPER:       equ 055h
KEY_CODE_V_UPPER:       equ 056h
KEY_CODE_W_UPPER:       equ 057h
KEY_CODE_X_UPPER:       equ 058h
KEY_CODE_Y_UPPER:       equ 059h
KEY_CODE_Z_UPPER:       equ 05Ah

