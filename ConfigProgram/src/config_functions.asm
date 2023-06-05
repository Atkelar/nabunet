


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


load_wifi_status:
    ld b, 1
    ld hl, UI_BUFFER
    ld a, 1
    ld (hl),a
    ld a, HCCA_PROT_CODE_MODEMCONFIG
    ld c, 0
    call modem_sendpacket
    ret nz  ;; TODO: RESET STATUS TO ERROR!

    ld hl, UI_BUFFER
    ld b, UI_BUFFER_LENGTH
    ld a, HCCA_PROT_CODE_MODEMCONFIG
    call modem_wait_for_reply
    ret nz

    ld hl, UI_BUFFER
    ld a, (hl)
    inc hl
    ld (modem_wifi_enabled), a
    ld a, (hl)
    inc hl
    ld (modem_wifi_ssid_set),a
    ld a, (hl)
    inc hl
    ld (modem_wifi_key_set),a
    ld a, (hl)
    inc hl
    ld (modem_wifi_status),a
    ld a, (hl)
    inc hl
    ld (modem_wifi_signal),a

    ret


CONFIG_BUFFER: equ UI_BUFFER+1  ; we use the UI buffer, first byte is API code...

; simplification for tx/rx in modem API.
; a => call code
; b => payload size (sans code byte)
; return: nz if error
; b <= reply length
.config_send_request_and_wait_reply:
    ld hl, UI_BUFFER
    ld (hl), a
    inc b
    ld a, HCCA_PROT_CODE_MODEMCONFIG
    ld c, 0
    call modem_sendpacket
    ret nz

    ld hl, CONFIG_BUFFER
    ld b, UI_BUFFER_LENGTH-1
    ld a, HCCA_PROT_CODE_MODEMCONFIG
    call modem_wait_for_reply
    ret


; return: nz if error
; b <= 2 = scan running, 1 = scan done, 0 = scan idle.
config_query_scan_done:
    ld b, 0
    ld a, 3
    call .config_send_request_and_wait_reply
    ret nz  ;; TODO: RESET STATUS TO ERROR!

    ld a, (CONFIG_BUFFER)
    ld b, a
    xor a
    ret


; return: nz if error
config_start_scan:
    ld a, 8
    ld (CONFIG_BUFFER), a   ; page size, we assume 8 entries per page..
    ld b, 1
    ld a, 2
    call .config_send_request_and_wait_reply
    ret

; a = move code; 1 = next, 2 = prev, 3 = last, 4 = first
; return buffer, one byte each:
; can go back, can go forward, number of entries on current page
config_move_page:
    ld (CONFIG_BUFFER), a
    ld a, 5
    ld b, 1
    call .config_send_request_and_wait_reply
    ret


; a = # of entry on page
; return nz if error
; buffer: encryption type (0=none, 1=enc, 2=?), signal strength (0..100), SSID (b-2 chars)
config_fetch_ssid:
    ld (CONFIG_BUFFER), a
    ld a, 6
    ld b, 1
    call .config_send_request_and_wait_reply
    ret


