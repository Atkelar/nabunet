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
	ld bc,OS_VARIABLE_LENGTH - 1
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

    ld a, CONTROL_LED_ALERT
    ld b, 2
    call set_led

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
    ld hl, JOY_NEXT_NUMBER
    ld a, (hl)
    ld hl, JOY_STATUS_1
    add hl, de
    ld (hl), b
    ld a, b
    jr .regular_key

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

    ld a, CONTROL_LED_CHECK
    ld b, 2
    call set_led

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

    ; TODO:
    ; blink cursor... on/off matches bit 0x20 -> should be 32 frames; at 60fps that should 
    ; be just about 0.5s and a good blink rate with almost no effort.

    ; RX timeout countdown?

    ; 1016h 3-byte counter...
    ld a, (VDP_TIMER)
    inc a
    jr z, .rollover1
    ld (VDP_TIMER), a
    jr .timer_done
.rollover1:
    ld (VDP_TIMER), a

    ld a, CONTROL_LED_PAUSE
    ld b, 2
    call set_led

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

    cp 1
    jr nz, .send_done_or_error


    ld bc, (HCCA_TX_TOGO)
    ld a, b
    or c
    jr z, .send_done_now

    dec bc
    ld (HCCA_TX_TOGO),bc
    ld bc, (HCCA_TX_CURRENT)
    ld a, (bc)
    out (0x80), a
    inc bc
    ld (HCCA_TX_CURRENT),bc

    pop bc
    pop af
    ei
    reti

.send_done_now:
    ld a, 0
    ld (HCCA_TX_STATUS), a

.send_done_or_error:
    ld c, 040h
    call disable_interrupt_mask
    pop bc
    pop af
    ei
    reti

.hcca_recevied_interrupt:
    push af
    push bc



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
