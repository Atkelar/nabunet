; common system functions...


reboot_nabu_now:
    ; enable ROM line...
    di  ; make sure we don't end up in some wonky state...
    ld a, CONTROL_RF_SWITCH ; make sure only the RF switch is active, everything else is initialized in the ROM...
    out (IO_CONTROL), a
    ; and off we go!
    jp 00000h


; input: a = combination of LED flags to set.
set_led_state:
    and CONTROL_LED_MASK
    ld b, a
    ld a, (STATUS_BYTE)
    and ~CONTROL_LED_MASK    ; clear old...
    or b                    ; set new...
    out (IO_CONTROL), a
    ld (STATUS_BYTE), a
    ret

; a => LED flag to set/clera
; b => zero to clear turn off, one to turn on, two to toggle...
set_led:
    and CONTROL_LED_MASK
    ld c, a
    ld a, b
    cp 2
    jr z, .toggle_led
    cp 1
    jr z, .enable_led
    cp 0
    ret nz
    ld a, c
    cpl
    ld c, a
    ld a, (STATUS_BYTE)
    and c
    jr .set_led
.enable_led:
    ld a, (STATUS_BYTE)
    or c
    jr .set_led
.toggle_led:
    ld a, (STATUS_BYTE)
    xor c
.set_led:
    out (IO_CONTROL), a
    ld (STATUS_BYTE), a
    ret