; IRQ handling stuffs...

.diag_buffer:
    defb 0,0
    defb "SIRQ"
setup_interrupts:
; copy 16 bytes of memory from .interrupt_table

	ld hl,.interrupt_table
	ld de,IRQ_TABLE_ADDRESS
	ld bc,16
	ldir

    ; initialize all handler variables...
    xor a
    ld (KBD_BUFFER_START),a
    ld (KBD_BUFFER_END),a

    ; initialize OS variables...
	ld hl,OS_VARIABLE_BASE
	ld de,OS_VARIABLE_BASE + 1
	ld bc,OS_VARIABLES_LENGTH - 1
	xor a
	ld (hl),a			    ;   reset first byte to zero before copy, thus copying 0s...
	ldir

    ld c, IRQ_MASK_VDP | IRQ_MASK_KBD   ; start off with keyboard and VDP interrupts only
    call set_interrupt_mask

    ld a, IRQ_TABLE_ADDRESS >> 8
    ld i, a
    im 2

    ei
    ret

; set interrupt mask register to "C"
set_interrupt_mask:
    push af
.set_interrupt_mask_internal:
  	ld a,00eh
	out (IO_SOUND_LATCH),a
	ld a,c
	out (IO_SOUND_DATA),a
    ld (IRQ_ENABLED_FLAGS),a
    pop af
    ret

; enables (or's) the "C" flag to the current interrupts
enable_interrupt_mask:
    push af
    ld a,  (IRQ_ENABLED_FLAGS)
    or c
    ld c, a
    jr .set_interrupt_mask_internal
    ret

; disables (and's the complement) the "C" flag to the current interrupts
disable_interrupt_mask:
    push af
    ld a, c
    xor 0ffh
    ld c, a
    ld a,  (IRQ_ENABLED_FLAGS)
    and c
    ld c, a
    jr .set_interrupt_mask_internal
    ret


.keyboard_interrupt:
;
;   The following special keycodes are received:
;       90h -> multiple key down error
;       91h, 92h, 93h    -> RAM/ROM or IRQ error
;       94h, 95h        -> "I am alive" codes upon restart or all 3-4 seconds when idle
;   the keyboard interrupt will put the sent codes into the proper storage location
;       lower codes -> keyboard buffer
;       uppder codes -> 
;
    push af
    push bc
    push de
    push hl

    ; ld a, CONTROL_LED_ALERT
    ; ld b, 2
    ; call set_led

    in a,(IO_KBD_STATUS)     ;   read status byte...   initial interrupt will show "overrun" because boot took too long;
    and KBD_STATUS_OVERRUN
    jp nz, .error_kbd_lloverflow

    in a,(IO_KBD_DATA)

    cp 080h ; high bits are set for error conditions and "on/off" keys
    jp c, .regular_key

    ; check for known established codes and joystick input...
    cp 090h
    jr z, .button_smash
    jp c, .joystick_selectors

    cp 096h
    jr c, .status_code
    jr .up_down_toggle_code

.button_smash:
    ; code 90h - "multiple keys pressed..."
    ; call beep?
    jp .kbd_handled

.status_code:
    cp 095h ; kbd restart! clean all states and start over!
    jr z, .kbd_fatal_error

    cp 094h ; kbd watchdog - normal, just ignore...
    jp z, .kbd_handled
    ; other status codes...
.kbd_fatal_error:
    jp .kbd_error_reset_states

.up_down_toggle_code:
    cp 0E0h
    jr nc, .special_key_handler
    ; now we MUST have a joystick code...
    and 01Fh    ; filter out any non-button code part.
    ld de, 0
    ld b, a
    ld a, (JOY_NEXT_NUMBER)
    ld e, a
    ld hl, JOY_STATUS_1
    add hl, de
    ld (hl), b
    ld a, b
    jp .kbd_handled

.special_key_handler:
    ; now we have codes E0-FF - which is down or up of special keys...
    cp 0F0h
    jr nc, .special_key_up
    sub 0E0h    ; one based for loop!
    ; lookup flag...
    ld b, 0
    ld hl, .keyboard_translation_state
    sla a   ; *2 for offset...
    ld c, a
    add hl, bc
    ld c, (hl)
    ld a, (KEY_STATES)
    or c
    ld (KEY_STATES), a
    inc hl
    ld c, (hl)
    ld a, (KEY_STATES+1)
    or c
    ld (KEY_STATES+1), a
    jr .kbd_handled

.special_key_up:
    sub 0F0h    ; one based for loop!
    ; lookup flag...
    ld e, a

    ld a, e
    ld b, 0
    ld hl, .keyboard_translation_state
    sla a   ; *2 for offset...
    ld c, a
    add hl, bc
    ld a, (hl)
    cpl
    ld c, a
    ld a, (KEY_STATES)
    and c
    ld (KEY_STATES), a
    inc hl

    ld a, (hl)
    cpl
    ld c, a
    ld a, (KEY_STATES+1)
    and c
    ld (KEY_STATES+1), a

    ; now, simulate a key...
    ld c, e
    ld b, 0
    ld hl, .keyboard_translation_vkey
    add hl, bc
    ld a, (hl)
    jr .regular_key

.error_kbd_lloverflow:  ; the RX buffer overflowed on the low level, i.e. input wasn't read fast enough!   
    in a, (IO_KBD_DATA) ; make room for next byte, but reset all states...
    ; call beep_error

    ld a, 014h          ; set Error Reset and Clear to Receive...
    out (IO_KBD_STATUS),a

    jr .kbd_error_reset_states


.joystick_selectors:
    sub 080h
    and 01h ; can only be either 0 or 1 at this point...
    ld (JOY_NEXT_NUMBER), a
    jr .kbd_handled


.regular_key:
    ld hl, KBD_BUFFER
    ld b, a ; save...
    ld a,(KBD_BUFFER_END)
    ld d, a
    inc a
    cp KBD_BUFFER_LENGTH
    jr c, .buffer_non_loop
    ld a, 0
.buffer_non_loop:
    ld e, a
    ld a, (KBD_BUFFER_START)
    cp e
    jr z, .buffer_overflow   ; bumped into the end...
    ld a, e
    ld (KBD_BUFFER_END), a
    ld e, d
    ld d, 0
    add hl, de
    ld (hl), b


.kbd_handled:
    pop hl
    pop de
    pop bc
    pop af
    ei
    reti

.buffer_overflow:
    ; call beep?
    jr .kbd_handled

.kbd_error_reset_states:
    ld a, 0
    ld (KBD_BUFFER_START), a
    ld (KBD_BUFFER_END), a
    ld (JOY_STATUS_1), a
    ld (JOY_STATUS_2), a
    ld (KEY_STATES), a
    ld (KEY_STATES+1), a
    jr .kbd_handled

; *************   KEYBOARD IRQ handler done.

; *************   Expansion slots handler...

setup_slot_irq_handler:
; sets the handler of the IRQ slot # in a to the address in c.
; TODO
    ret

clear_slot_irq_handler:
; removes the handler of the IRQ slot # in a.
; TODO
    ret

set_slot_irq_enabled:
; enables the IRQ for # in a if c is nonzero, disables it if c is zero.
; TODO
    ret


.slot_0_interrupt:
    ; Interrupt should only be enabled if the handler code is defined...
    push hl
    ld hl, .slot_interrupt_return
    push hl
    ld hl, (SLOT_0_CALLBACK)
    push hl
    ret

.slot_1_interrupt:
    ; Interrupt should only be enabled if the handler code is defined...
    push hl
    ld hl, .slot_interrupt_return
    push hl
    ld hl, (SLOT_1_CALLBACK)
    push hl
    ret

.slot_2_interrupt:
    ; Interrupt should only be enabled if the handler code is defined...
    push hl
    ld hl, .slot_interrupt_return
    push hl
    ld hl, (SLOT_2_CALLBACK)
    push hl
    ret

.slot_3_interrupt:
    ; Interrupt should only be enabled if the handler code is defined...
    push hl
    ld hl, .slot_interrupt_return
    push hl
    ld hl, (SLOT_3_CALLBACK)
    push hl
    ret

.slot_interrupt_return:
    pop hl
    ei
    reti


; **************** VDP interrupt for timer...

.video_interrupt:
    push af
    push bc

    ; fetch VDP status to clear interrupt and do timing stuffs....
    in a,(IO_VDP_CONTROL)

    ; maybe do something else?
    ; store "collision" flag...

    ; blink cursor... on/off matches bit 0x20 -> should be 32 frames; at 60fps that should 
    ; be just about 0.5s and a good blink rate with almost no effort.
    ; NOTE: if the cursor is not set as "VISIBLE", DO NOT TOUCH THE VDP registers! 

    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_VISIBLE
    jr z, .cursor_done

    ld a, (VDP_TIMER)
    and 020h    
    jr z, .cursor_should_be_normal
    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_BLINKON
    jr nz, .cursor_done

    push hl
    push de
    ; flip cursor character to "0"
    ld hl,(CURSOR_OFFSET)  ; save for later use too.
    ; 2.: read current character from screen and remember.
    ld de, VDP_SCREEN_BASE
    add hl, de
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; update address select bit
    out (IO_VDP_CONTROL), a
    xor a
    out (IO_VDP_DATA), a
    pop de
    pop hl

    ld a, (CURSOR_FLAGS)
    or CURSOR_FLAG_BLINKON
    ld (CURSOR_FLAGS),a
    jr .cursor_done

.cursor_should_be_normal:
    ld a, (CURSOR_FLAGS)
    and CURSOR_FLAG_BLINKON
    jr z, .cursor_done

    push hl
    push de
    ; flip cursor character to "0"
    ld hl,(CURSOR_OFFSET)  ; save for later use too.
    ; 2.: read current character from screen and remember.
    ld de, VDP_SCREEN_BASE
    add hl, de
    ld a, l
    out (IO_VDP_CONTROL), a
    ld a, h
    and 3Fh     ; mask top bits
    or 040h     ; update address select bit
    out (IO_VDP_CONTROL), a
    ld a, (CURSOR_ORIGINAL_CHAR)
    out (IO_VDP_DATA), a
    pop de
    pop hl

    ld a, (CURSOR_FLAGS)
    and ~CURSOR_FLAG_BLINKON & 0ffh
    ld (CURSOR_FLAGS),a
    jr .cursor_done

.cursor_done:
    ; RX timeout countdown?
    ld a, (VDP_TIMER)
    ld b, a
    inc a
    xor b
    and 040h ; did bit flip with inc?
    jr z, .rx_timeout_done

    ld a, (HCCA_RX_STATUS)
    cp HCCA_XFSTATUS_RUNNING
    jr nz, .rx_timeout_done  ; we are idle/error
  
    ld a,(HCCA_RX_TIMEOUT) 
    or a
    jr z, .rx_timeout_expired
    dec a
    ld (HCCA_RX_TIMEOUT), a
    jr .rx_timeout_done
.rx_timeout_expired:
    ld a, HCCA_XFSTATUS_ERROR
    ld (HCCA_RX_STATUS), a
    ld a, HCCA_ERROR_TIMEOUT
    ld (HCCA_RX_ERROR), a
    ld a, HCCA_STATUS_ERROR
    ld (HCCA_STATUS), a

;    ld c, IRQ_MASK_HCCA_RX      ; stop waiting for input... TODO: validate for callbacks?
;    call disable_interrupt_mask

.rx_timeout_done:
    ; 1016h 3-byte counter...
    ld a, (VDP_TIMER)
    inc a
    jr z, .rollover1
    ld (VDP_TIMER), a
    jr .timer_done
.rollover1:
    ld (VDP_TIMER), a

    ; ld a, CONTROL_LED_PAUSE
    ; ld b, 2
    ; call set_led

    ld a, (VDP_TIMER+1)
    inc a
    jr z, .rollover2
    ld (VDP_TIMER+1), a
    jr .timer_done
.rollover2:
    ld (VDP_TIMER+1), a
    ld a, (VDP_TIMER+2)
    inc a
    ld (VDP_TIMER+2), a ; ignore rollover... 

.timer_done:
    pop bc
    pop af
    ei
    reti

; **** VDP Interrupt done.

; ***** HCCA send/recive interrupt handler


.hcca_ready_to_send_interrupt:
    push af
    push bc

    ld a, (HCCA_TX_STATUS)

    cp HCCA_XFSTATUS_RUNNING
    jr nz, .send_done_or_error

    ld a, (HCCA_TX_TOGO)
    or a
    jr z, .send_done_now

    dec a

    ld (HCCA_TX_TOGO),a
    ld bc, (HCCA_TX_CURRENT)
    ld a, (bc)
    out (IO_HCCA), a
    inc bc
    ld (HCCA_TX_CURRENT),bc

    pop bc
    pop af
    ei
    reti

.send_done_now:
    ld a, HCCA_XFSTATUS_IDLE
    ld (HCCA_TX_STATUS), a

.send_done_or_error:
    ld c, IRQ_MASK_HCCA_TX
    call disable_interrupt_mask
    pop bc
    pop af
    ei
    reti

; the HCCA received signal will decode the protocol details and do checksum handling
.hcca_recevied_interrupt:
    push af
    push bc
    push de
    push hl

  	ld a,00fh
	out (IO_SOUND_LATCH),a
	in a,(IO_SOUND_DATA)
    and STATUS_HCCA_OVERRUN | STATUS_HCCA_FRAMING
    jr z, .hcca_receive_modem_ready
    ; TODO: error condition in receive!

    ld (HCCA_RX_ERROR), a
    ld a, HCCA_XFSTATUS_ERROR
    ld (HCCA_RX_STATUS), a
    jp .hcca_receive_done   ; abort in HW error case.

.hcca_receive_modem_ready:  
    ; make room for next byte ASAP - the RX speed is slow compared to CPU speed,
    ; so as long as we are picking up the byte quickly, we shouldn't end up in overflow state...
    in a, (IO_HCCA)
    ld b, a
    ld a, (HCCA_STATUS) ; check overall status first...
    cp HCCA_STATUS_CONNECTED
    jr z, .hcca_receive_normal
    cp HCCA_STATUS_CONNECTING
    jr z, .hcca_receive_normal
    jp .hcca_receive_unknown_state

.hcca_receive_normal:
    ; normal byte incoming...
    ld a, (HCCA_RX_LL_STATE)
    cp HCCA_LLSTATE_IDLE
    jp z, .new_packet_start
    cp HCCA_LLSTATE_EXPECTLEN
    jp z, .packet_len_received
    cp HCCA_LLSTATE_DATA
    jr z, .packet_data_received
    ; if we got here, we are dealing with the checksum byte...
    ld a, (HCCA_RX_LL_CHECKSUM)
    add b
    xor HCCA_PROT_CHECKSUM_TARGET
    jr z, .checksum_ok
    ld a, HCCA_LLSTATE_IDLE
    ld (HCCA_RX_LL_STATE), a
    ; uh-oh... checksum didn't validate! need to re-sync eventually!
    ld a, HCCA_ERROR_CHECKSUM
    ld (HCCA_RX_ERROR), a
    ld a, HCCA_STATUS_ERROR
    ld (HCCA_STATUS), a
    ld a, HCCA_XFSTATUS_ERROR
    ld (HCCA_RX_STATUS), a
    ld (HCCA_TX_STATUS), a
    jp .hcca_receive_done

.packet_data_received:
    ld a,(HCCA_RX_LL_CHECKSUM)
    add b
    ld (HCCA_RX_LL_CHECKSUM), a
    ld hl, (HCCA_RX_CURRENT)
    ld a, b
    ld (hl), a
    inc hl
    ld (HCCA_RX_CURRENT),hl
    ld a, (HCCA_RX_TOGO)
    dec a
    ld (HCCA_RX_TOGO), a
    or a
    jp z, .packet_data_done
    jp .hcca_receive_done
.packet_data_done:
    ld a, HCCA_LLSTATE_CHECKSUM
    ld (HCCA_RX_LL_STATE), a
    jp .hcca_receive_done

.checksum_ok:
    ; if we are in "handshaking" mode, we need to see if we are waiting for a response or not.
    ; we expect either:
    ;   * "STREAM" package input, copy to listener buffer if any...
    ;   * "reply" to previously sent package of any type; copy data - if any - to target buffer and signal if matching code.
    ; The higher level receive code is responsible for anything else.
    ; any other packet configuratoin is a protocol error at this stage.
    ld a, HCCA_LLSTATE_IDLE
    ld (HCCA_RX_LL_STATE), a
    ld a, (HCCA_RX_LL_CODE)
    and a, HCCA_PROT_FLAG_REPLY
    jr nz, .packet_was_reply
    ld a, (HCCA_RX_LL_CODE)
    and a, HCCA_PROT_MASK_CODE
    cp HCCA_PROT_CODE_STREAM
    jr z, .packet_was_streaminput
    jr .error_in_protocol

.packet_was_reply:
    ld a, (HCCA_RX_LL_CODE)
    and HCCA_PROT_MASK_CODE
    ld b,a
    ld a, (HCCA_RX_EXPECTED)
    cp b
    jr z, .packet_was_expected_reply
    ld a, HCCA_LLSTATE_IDLE ; ignore...
    jp .hcca_receive_done

.packet_was_expected_reply:
    ld a, (HCCA_RX_LL_LENGTH)
    ld b,a
    ld a, (HCCA_RX_SIZE)
    cp b
    jr c, .error_in_protocol

    ld de, (HCCA_RX_TARGET)
    ld hl, HCCA_RX_BUFFER
    ld a, (HCCA_RX_LL_LENGTH)
    ld (HCCA_RX_LENGTH),a
    ld c, a
    ld b, 0
    ldir
    ld a, HCCA_XFSTATUS_IDLE
    ld (HCCA_RX_STATUS), a
    jr .hcca_receive_done

.packet_was_streaminput:

    jr .hcca_receive_done

.packet_len_received:
    ld a,(HCCA_RX_LL_CHECKSUM)
    add b
    ld (HCCA_RX_LL_CHECKSUM), a
    ld a,b
    cp 081h    ; maximum 80h
    jr nc, .error_in_protocol
    ld (HCCA_RX_LL_LENGTH), a
    ld (HCCA_RX_TOGO), a
    ld a, HCCA_LLSTATE_DATA
    ld (HCCA_RX_LL_STATE), a
    ld hl, HCCA_RX_BUFFER
    ld (HCCA_RX_CURRENT), hl

    jr .hcca_receive_done

.error_in_protocol:
    ld a, HCCA_ERROR_PROTOCOL
    ld (HCCA_RX_ERROR), a
    ld a, HCCA_STATUS_ERROR
    ld (HCCA_STATUS), a
    ld a, HCCA_XFSTATUS_ERROR
    ld (HCCA_RX_STATUS), a
    ld (HCCA_TX_STATUS), a
    jr .hcca_receive_done

.new_packet_start:
    ld a, b
    ld (HCCA_RX_LL_CHECKSUM), a    ; start checksum
    ld (HCCA_RX_LL_CODE), a        ; remember code for current packet
    and HCCA_PROT_FLAG_DATA
    jr z, .new_packet_nodata

    ld a, HCCA_LLSTATE_EXPECTLEN
    ld (HCCA_RX_LL_STATE), a
    ld hl, HCCA_RX_BUFFER
    ld (HCCA_RX_CURRENT), hl
    jr .hcca_receive_done

.new_packet_nodata:
    ld a,HCCA_LLSTATE_CHECKSUM
    ld (HCCA_RX_LL_STATE), a
    xor a
    ld (HCCA_RX_LL_LENGTH), a
    jr .hcca_receive_done

.hcca_receive_unknown_state:
    ; As of now, handshake is dealt with at a procedure level; the handling of a "resync" request is done after the packet was received...
;     ; the modem state is "error"; we expect - at most - a sync request at this time...
;     ld a,b
;     cp HCCA_PROT_FLAG_DATA | HCCA_PROT_CODE_HANDSHAKE
;     jr nz, .hcca_receive_done
; .hcca_receive_start_handshake:
;     ; we recevied a handshake request in unknown state, start handshake process
;     ld (HCCA_RX_LL_CHECKSUM), a    ; start checksum
;     xor a
;     ld (HCCA_HS_INIT), a
;     ld (HCCA_HS_TOKEN), a
;     ld (HCCA_RX_CODE), a
;     ld hl, HCCA_RX_BUFFER
;     ld (HCCA_RX_CURRENT), hl
;     ld (HCCA_RX_TOGO), 8bitonly
;     ld a, HCCA_STATUS_CONNECTING
;     ld (HCCA_STATUS), a

.hcca_receive_done:
    pop hl
    pop de
    pop bc
    pop af
    ei
    reti

; IMPORTANT: the interrupt table MUST start at an 0x??00 offset!
; It is thus copied to a non-used suitable RAM location by the init code...
.interrupt_table:
; we have 8 ISR routines, lowest to highest priority
; 7 = HCCA receive, mask = 0x80
; 6 = HCCA send done, mask = 0x40
; 5 = Keyboard, mask = 0x20
; 4 = VDP, mask = 0x10
; 3 = Slot 0, mask = 0x08
; 2 = Slot 1, mask = 0x04
; 1 = Slot 2, mask = 0x02
; 0 = Slot 3, mask = 0x01
; the order is reversed, due to active low signals...
    defw    .hcca_recevied_interrupt
    defw    .hcca_ready_to_send_interrupt
    defw    .keyboard_interrupt
    defw    .video_interrupt
    defw    .slot_0_interrupt
    defw    .slot_1_interrupt
    defw    .slot_2_interrupt
    defw    .slot_3_interrupt


.keyboard_translation_state:
    defw KBD_STATE_RIGHT
    defw KBD_STATE_LEFT
    defw KBD_STATE_UP
    defw KBD_STATE_DOWN
    defw KBD_STATE_SRIGHT
    defw KBD_STATE_SLEFT
    defw KBD_STATE_NO
    defw KBD_STATE_YES
    defw KBD_STATE_SYM
    defw KBD_STATE_PAUSE
    defw KBD_STATE_TV
    defw 0,0,0,0,0      ; five unused fillers... just in case...

.keyboard_translation_vkey:
    defb KBD_VKEY_RIGHT
    defb KBD_VKEY_LEFT
    defb KBD_VKEY_UP
    defb KBD_VKEY_DOWN
    defb KBD_VKEY_SRIGHT
    defb KBD_VKEY_SLEFT
    defb KBD_VKEY_NO
    defb KBD_VKEY_YES
    defb KBD_VKEY_SYM
    defb KBD_VKEY_PAUSE
    defb KBD_VKEY_TV
    defb 0,0,0,0,0      ; five unused fillers... just in case...
