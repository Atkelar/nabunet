; functions to configure the WIFI settings...

wifi_menu:
    ;ld a, 0e4h
    ld a, (VDP_COLOR_BLACK << 4) | VDP_COLOR_DARK_YELLOW
    call clear_screen
    ld hl,.screen_header
    call print

    ld c, 8
    ld b, 4
    call goto_xy
    ld hl, .Opt1
    call print

    ld c, 8
    ld b, 5
    call goto_xy
    ld hl, .Opt2
    call print

    ld c, 8
    ld b, 6
    call goto_xy
    ld hl, .Opt3
    call print

    ld c, 8
    ld b, 7
    call goto_xy
    ld hl, .Opt4
    call print

    call load_wifi_status
    jr z, .wifi_menu_status

    ld c, 8
    ld b, 9
    call goto_xy
    ld hl, .query_error
    call print
    jr .wifi_menu_loop

.wifi_menu_status:

    ld c,3
    ld b, 8
    call goto_xy
    ld a, (modem_wifi_enabled)
    call print_hex_8
    ld a, (modem_wifi_ssid_set)
    call print_hex_8
    ld a, (modem_wifi_key_set)
    call print_hex_8
    ld a, (modem_wifi_status)
    call print_hex_8
    ld a, (modem_wifi_signal)
    call print_hex_8

.wifi_menu_loop:        ; TODO: better (centralized?) menu handling...
    call .update_status
    call get_key

    cp 031h ; "1"
    call z, .prompt_enable_wifi

    cp 032h ; "2"
    call z, .set_ssid_manually

    cp 033h ; "2"
    call z, .scan_ssids

    cp 01bh ;  ESC
    jr z, .exit_menu

    jp .wifi_menu_loop


.exit_menu:
    ld b, 1
    ret

.update_status:
    ret

.prompt_enable_wifi:
    ret

.set_ssid_manually:
    ret

.scan_ssids:
    call config_query_scan_done
    ; b <= 2 = scan running, 1 = scan done, 0 = scan idle.
    jp nz, .handle_modem_error
    ld a, b
    cp 1
    jr z, .ask_rescan_now
    cp 2
    jr z, .scan_running_loop
.start_scan_now:
    call config_start_scan
    jp nz, .handle_modem_error

.scan_running_loop:
    call .clear_menu

    ld b, 5
    ld c, 3
    call goto_xy
    ld hl, .scanning_message
    call print

.scan_running_loop_repeat:
    ld b, 7
    ld c, 10
    call goto_xy
    ld a, (.animation_location)
    inc a
    cp 4
    jr c, .animation_ok
    xor a
.animation_ok:
    ld (.animation_location), a
    ld hl, .scanning_animation
    rla a
    ld e, a
    ld d, 0
    add hl, de
    call print

    ld a, 15
    call delay_frames

    call key_available
    jp nz, .key_pressed_in_loop

.key_continue:
    call config_query_scan_done
    ; b <= 2 = scan running, 1 = scan done, 0 = scan idle.
    jp nz, .handle_modem_error
    ld a, b
    cp 2
    jr z, .scan_running_loop_repeat
    jp .list_results_now

.ask_rescan_now:
    ld hl, .rescan_query
    ;   hl -> question string (zero-term)
    ;   a -> 0 = force yes/no - 1 = allow "ESC".
    ;   return: a = 0 yes, 1 no, 2 cancel. also: z if yes, nz if "not yes".
    ld a, 1
    call prompt_yes_no
    cp 2
    ret z
    cp 1
    jr z, .list_results_now
    jr .start_scan_now

.list_results_now:
    ; done...
    ld a, 4
    call config_move_page
    jp nz, .handle_modem_error

    ld a, (CONFIG_BUFFER)
    ld (.has_prev_page), a
    ld a, (CONFIG_BUFFER+1)
    ld (.has_next_page), a
    ld a, (CONFIG_BUFFER+2)
    ld (.entry_count), a
    or a
    jp z, .no_entries_found
    
    call .clear_menu
    ld a, 0 ; page size...
    ld (.current_item), a
.load_next_entry:
    ld a, (.current_item)
    call config_fetch_ssid
    jp nz, .handle_modem_error
    ld e, b
    dec b
    dec b
    jr z, .list_done
    ld d, 0
    ld hl, CONFIG_BUFFER
    add hl, de
    xor a
    ld (hl), a  ; terminate name!

    ; buffer: encryption type (0=none, 1=enc, 2=?), signal strength (0..100), SSID (b-2 chars)
    ld a, (.current_item)
    add 5
    ld b, a
    ld c, 3
    call goto_xy
    ld a, (CONFIG_BUFFER+1)
    ld hl, .signal_0
    cp 20
    jr c, .print_signal
    ld hl, .signal_1
    cp 40
    jr c, .print_signal
    ld hl, .signal_2
    cp 60
    jr c, .print_signal
    ld hl, .signal_3
    cp 80
    jr c, .print_signal
    ld hl, .signal_4
.print_signal:
    call print

    ld a, (CONFIG_BUFFER)
    ld hl, .status_clr
    or a
    jr z, .print_enctype
    ld hl, .status_enc
    cp 1
    jr z, .print_enctype
    ld hl, .status_unk

.print_enctype:
    call print

    ld hl, CONFIG_BUFFER+2
    call print

    ld a, (.current_item)
    inc a
    ld (.current_item), a
    ld b, a
    ld a, (.entry_count)
    cp b
    jr z, .list_done
    jp .load_next_entry
.list_done:

    ld a, 200
    call delay_frames

    ret    

.key_pressed_in_loop:
    call get_key
    cp 01bh ; escape...
    ret ; we abort...
    jp .key_continue    ; we ignore the key...

.no_entries_found:
    ld b, 5
    ld c, 3
    call goto_xy
    ld hl, .no_networks_found
    call print
    ld a, 120
    call delay_frames
    ret

.handle_modem_error:
    ; TODO: show error code info...
    ret

.clear_menu:
    ld a, 4
.clear_loop:
    ld b, a
    ld c, 0
    push af
    call goto_xy
    call clear_eol
    pop af
    inc a
    cp 25
    jr nz, .clear_loop
    ret

.Opt1:
defb "1: Enabled",0
.Opt2:
defb "2: Set SSID",0
.Opt3:
defb "3: Scan/select SSID",0
.Opt4:
defb "4: Set Key",0

.query_error:
defb "Status read failed!",0 

.rescan_query:
defb "Rescan networks now?", 0

.scanning_message:
defb "scanning...",0

.no_networks_found:
defb "No networks found!", 0

.animation_location:
defb 0
.current_item:
defb 0

.scanning_animation:    ; must be 2-bytes each, four animation characters wiht zero termination...
defb 0e7h, 0
defb 0e8h, 0
defb 0e9h, 0
defb 0eah, 0


.has_next_page: ;equ menu_temp_vars
defb 0
;    
.has_prev_page:
defb 0
;     equ menu_temp_vars+1
.entry_count:      ; equ menu_temp_vars+2
defb 0

.screen_header:
defb 0f4h, 0f5h, 0f6h, 0f7h, 0f2h, 0f3h
defb " NABUNET WiFi Options"
defb 0ah

defb 0f8h, 0f9h, 0fah, 0fbh
defb "   ", 0c0h
defs 31, 0c4h
defb 0ah

defb 0fch, 0fdh, 0feh, 0ffh, 0ah, 0

.status_enc:
defb 020h, 0edh, 020h, 0

.status_clr:
defb 020h, 0ech, 020h, 0

.status_unk:
defb 020h, "?", 020h, 0

.signal_0:
defb 020h, 020h, 0

.signal_1:
defb 0eeh, 020h, 0

.signal_2:
defb 0efh, 020h, 0

.signal_3:
defb 0efh, 0f0h, 0

.signal_4:
defb 0efh, 0f1h, 0

.cursor_on:
defb 0xeb, 0

.cursor_off:
defb 0x20, 0
