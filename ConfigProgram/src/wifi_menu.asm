; functions to configure the WIFI settings...

wifi_menu:
    ;ld a, 0e4h
    ld a, (VDP_COLOR_BLACK << 4) | VDP_COLOR_DARK_YELLOW
    call clear_screen
    ld hl,.screen_header
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

    ld c, 3
    ld b, 22
    call goto_xy
    ld hl, .current_SSID_header
    call print
    ld hl, modem_wifi_current_ssid
    ld a, (hl)
    or a
    jr nz, .ssid_set
    ld hl, .no_ssid_ssid
.ssid_set:
    call print

    ld a, (modem_wifi_signal)
    ld hl, .signal_0
    cp 20
    jr c, .print_current_signal
    ld hl, .signal_1
    cp 40
    jr c, .print_current_signal
    ld hl, .signal_2
    cp 60
    jr c, .print_current_signal
    ld hl, .signal_3
    cp 80
    jr c, .print_current_signal
    ld hl, .signal_4
.print_current_signal:
    call print

    ld c, 3
    ld b, 23
    call goto_xy
    ld hl, .localIP_header
    call print
    ld hl, modem_wifi_current_ip
    ld a, (hl)
    or a
    jr nz, .ip_set
    ld hl, .no_ip_ip
.ip_set:
    call print





.wifi_menu_loop:        ; TODO: better (centralized?) menu handling...
    call .update_status


    ld hl, .menu_items
    ld a, 1
    ld c, 8
    ld b, 4
    call screen_menu_run
    ret z
    ld hl, .menu_items
    call screen_menu_call

    call .clear_menu

    jp .wifi_menu_loop


.update_status:

    ret

.set_key:
    ld b, 10
    ld c, 3
    call goto_xy
    ld hl, .key_prompt
    call print

    ld hl, config_proposed_string ; reuse buffer...
    xor a
    ld (hl),a  ; we *always* start off clean, to avoid any pollution...
    ld d, 32
    ld e, 20
    ld b, 10
    ld c, 18 | 080h ; request "*"
    call readline
    jr z, .set_key_clear_buffer

    ld hl, config_proposed_string
    call config_set_key    ; TODO error handling

.set_key_clear_buffer:
    ld hl, config_proposed_string
    xor a
    ld (hl),a   ; clear out (well, not quite but almost) the password. TODO: clear full buffer.
    
    ret


.prompt_enable_wifi:
    ld hl, .enable_wifi_prompt
    ld a,1  ; we allow cancel...
    call prompt_yes_no
    cp 2
    ret z   ; leave "as is" when cancelled.
    cp 1
    jr z, .disable_wifi_now
    ld a, 1
    call config_set_wifi_enabled    ; TODO handle errors
    ret
.disable_wifi_now:
    ld a, 0
    call config_set_wifi_enabled    ; TODO handle errors
    ret

.set_ssid_manually:
    ld de, config_proposed_string
    ld hl, modem_wifi_current_ssid
    call strcpy

    ld b, 10
    ld c, 3
    call goto_xy
    ld hl, .ssid_prompt
    call print

    ld hl, config_proposed_string
    ld d, 32
    ld e, 20
    ld b, 10
    ld c, 18
    call readline
    ret z

    ld hl, config_proposed_string
    call config_set_ssid    ; TODO error handling

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

    ld a, 10
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
    call main_print_modem_error_state
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

.menu_items:
    defb "1", 0
    defw .Opt1
    defw .prompt_enable_wifi
    defb "2", 0
    defw .Opt2
    defw .set_ssid_manually
    defb "3", 0
    defw .Opt3
    defw .scan_ssids
    defb "4", 0
    defw .Opt4
    defw .set_key

    defb 0

.Opt1:
defb "Enable/Disable",0
.Opt2:
defb "Set SSID",0
.Opt3:
defb "Scan & select SSID",0
.Opt4:
defb "Set key",0

.query_error:
defb "Status read failed!",0 

.rescan_query:
defb "Rescan networks now?", 0

.scanning_message:
defb "scanning...",0

.no_networks_found:
defb "No networks found!", 0

.ssid_prompt:
defb "SSID:",0

.enable_wifi_prompt:
defb "Enable WiFi?",0

.localIP_header: 
defb "IP:   ",0
.no_ip_ip:
defb "< not con. >", 0 

.current_SSID_header:
defb "SSID: ",0
.no_ssid_ssid:
defb "< not set >",0

.key_prompt:
defb "Key/password:", 0

.animation_location:
defb 0
.current_item:
defb 0

.scanning_animation:    ; must be 2-bytes each, four animation characters with zero termination...
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
