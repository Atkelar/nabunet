


reload_current_config:
    ld de, UI_BUFFER
    xor a
    ld (de), a
    inc de
    ld hl, image_version_string
    ld b, 0
.loop_load_config1:
    ld a,(hl)
    or a
    jr z, load_config_loop_done1
    inc b
    ld (de), a
    inc hl
    inc de
    jr .loop_load_config1

load_config_loop_done1:

    inc b
    ld a, HCCA_PROT_CODE_MODEMCONFIG
    ld hl, UI_BUFFER
    ld c, 0
    call modem_sendpacket
    ret nz  ;; TODO: RESET STATUS TO ERROR!

    ld hl, UI_BUFFER
    ld b, UI_BUFFER_LENGTH
    ld a, HCCA_PROT_CODE_MODEMCONFIG
    call modem_wait_for_reply
    ret nz

    push bc
    ld a, CONTROL_LED_CHECK
    ld b, 1
    call set_led
    pop bc

    ld c, b

    ld a, (UI_BUFFER)
    or a
    ret nz  ; should be zero...

    dec c
    ld de, modem_config_var_start
    ld hl, UI_BUFFER + 1

    ld b, 6
    jr .loop_mac_start
.loop_mac_format:
    ld a, ':'
    ld (de),a
    inc de
.loop_mac_start:
    ld a, (hl)
    ld (de), a
    dec c
    inc hl
    inc de
    ld a, (hl)
    ld (de), a
    inc hl
    inc de
    dec c
    dec b
    jr nz, .loop_mac_format
    xor a
    ld (de), a
    inc de

    ; from hl -> de: modem sw version...

.loop_version_string:
    ld a, c
    or a
    jr z, .version_string_done
    ld a, (hl)
    ld (de), a
    inc hl
    inc de
    dec c
    jr .loop_version_string

.version_string_done:
    ld (de), a
    inc de

    ret