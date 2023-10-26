

; Loads the current modem information; 
reload_modem_info:
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

load_remote_server_status:
    ; reset...
    xor a

    ld (modem_remote_server_name),a
    ld (modem_remote_server_version),a
    ld (modem_remote_api_level),a
    ld (modem_remote_enabled),a
    ld (modem_remote_flags),a
    ld (modem_remote_ignore_tls),a 

    ld b, 0
    ld a, 0ah
    ; no net payload...
    call .config_send_request_and_wait_reply
    ret nz

    ld hl, CONFIG_BUFFER
    ld a, (hl)
    inc hl
    ld (modem_remote_enabled), a
    ld a, (hl)
    inc hl
    ld (modem_remote_api_level),a
    ld a, (hl)
    inc hl
    ld (modem_remote_flags),a
    ld a, (hl)
    inc hl
    ld (modem_remote_ignore_tls), a


    ld a, 4 ; Host String
    ld de, modem_remote_current_host
    call config_get_string
    ret nz

    ld a, 5 ; Path String
    ld de, modem_remote_current_path
    call config_get_string
    ret nz

    ld a, 6 ; Port String
    ld de, modem_remote_current_port
    call config_get_string
    ret nz

    ld a, 7
    ld de, modem_remote_server_version
    call config_get_string
    ret nz
    ld a, 8
    ld de, modem_remote_server_name
    call config_get_string
    ret nz
    ret


load_wifi_status:
    ld b, 0
    ld a, 1
    ; no net payload...
    call .config_send_request_and_wait_reply
    ret nz

    ld hl, CONFIG_BUFFER
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

    ld a, 1
    ld de, modem_wifi_current_ssid
    call config_get_string
    ret nz

    ld a, 3
    ld de, modem_wifi_current_ip
    call config_get_string
    ret nz

    xor a   ; make sure we get the Z flag
    ret

; read configuration string through buffer.
; input: a -> string #, de -> target address
config_get_string:
    push de
    ld (CONFIG_BUFFER), a
    ld a, 9 ; read config string
    ld b, 1
    call .config_send_request_and_wait_reply
    jr nz, .string_get_fail_pop

    ; now we should have a reply...
    ld a, (CONFIG_BUFFER)
    or a
    jr nz, .string_get_fail_pop

    pop de
    ld a, (CONFIG_BUFFER+1)
    or a
    jr z, .config_string_empty
    ld c, a
    ld b, 0
    ld hl, CONFIG_BUFFER+2
    ldir
    xor a
.config_string_empty:
    ld (de),a
    ret
.string_get_fail_pop:
    pop de
    ld a, 1
    or a    ; force NZ
    ret

; input: a = 1 enable, a = 0 disable.
; output NZ if error, a = return code from modem.
config_set_wifi_enabled:  
    ld hl, CONFIG_BUFFER
    ld (hl), a
    ld b, 1
    ld a, 7
    call .config_send_request_and_wait_reply
    ret nz

    xor a ; clear flag
    ld a, (CONFIG_BUFFER)
    ret


; input: a = 1 enable, a = 0 disable.
; output NZ if error, a = return code from modem.
config_set_tls_ignore:
    ld hl, CONFIG_BUFFER
    ld (hl), a
    ld b, 1
    ld a, 0ch    ; tls ignore flag
    call .config_send_request_and_wait_reply
    ret nz

    xor a ; clear flag
    ld a, (CONFIG_BUFFER)
    ret

; input: a = 1 enable, a = 0 disable.
; output NZ if error, a = return code from modem.
config_set_remote_enabled:  
    ld hl, CONFIG_BUFFER
    ld (hl), a
    ld b, 1
    ld a, 11    ; set remote enabled
    call .config_send_request_and_wait_reply
    ret nz

    xor a ; clear flag
    ld a, (CONFIG_BUFFER)
    ret

; input:  hl -> string
; output NZ if error, a = return code from modem.
config_set_host: 
    ld a, 4 ; set remote host
    jr .config_set_string

; input:  hl -> string
; output NZ if error, a = return code from modem.
config_set_path: 
    ld a, 5 ; set remote path
    jr .config_set_string

; input:  hl -> string
; output NZ if error, a = return code from modem.
config_set_port: 
    ld a, 6 ; set remote port
    jr .config_set_string

; input:  hl -> string
; output NZ if error, a = return code from modem.
config_set_key: 
    ld a, 2 ; set key
    jr .config_set_string

; input:  hl -> string
; output NZ if error, a = return code from modem.
config_set_ssid:
    ld a, 1 ; set SSID
    jr .config_set_string

.config_set_string:
    ld (CONFIG_BUFFER), a
    push hl
    call strlen
    ld a, l
    ld (CONFIG_BUFFER+1), a
    add 2
    ld b, a
    pop hl
    ld de, CONFIG_BUFFER+2
    call strcpy
    ld a, 8     ; set string command.
    call .config_send_request_and_wait_reply
    ret nz

    ld a, (CONFIG_BUFFER)
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


; return nz if error
; a: bitmask of available update images.
config_fetch_sd_update_status:
    ld a, 0Dh
    ld b, 0
    call .config_send_request_and_wait_reply
    ret nz
    ld a, (CONFIG_BUFFER)
    ret


; return nz if error
; buffer: bitmask of available updates, [len] version for boot image, [len] version for firmware
config_fetch_remote_update_status:
    ld a, 0Eh
    ld b, 0
    call .config_send_request_and_wait_reply
    ret
