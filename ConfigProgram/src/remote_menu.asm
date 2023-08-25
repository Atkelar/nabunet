; functions to configure the remote server settings...

remote_menu:
    ;ld a, 0e4h
    ld a, (VDP_COLOR_BLACK << 4) | VDP_COLOR_DARK_GREEN
    call clear_screen
    ld hl,.screen_header
    call print

    call load_remote_server_status
    jr z, .remote_menu_status

    ld c, 8
    ld b, 9
    call goto_xy
    ld hl, .query_error
    call print

    call main_print_modem_error_state

    jp .remote_menu_run

.remote_menu_status:

    ld c, 3
    ld b, 20
    call goto_xy
    ld hl, .server_status_header
    call print
    ld a, (modem_remote_api_level)
    or a
    jr z, .remote_not_connected

    ld hl, .server_status_connected
    call print

    ld c, 3
    ld b, 21
    call goto_xy
    ld hl, .server_status_name
    call print
    ld hl, modem_remote_server_name
    call print

    jr .remote_server_info_done
.remote_not_connected:
    ld hl, .server_status_not_connected
    call print
.remote_server_info_done:

    ld c, 3
    ld b, 22
    call goto_xy
    ld hl, .current_host_header
    call print
    ld a, (modem_remote_ignore_tls)
    or a
    jr z, .current_host_secure
    ld hl, .current_host_insecure_header
    call print
.current_host_secure:
    ld hl, modem_remote_current_host
    ld a, (hl)
    or a
    jr nz, .host_set
    ld hl, .no_host
.host_set:
    call print

    ld c, 3
    ld b, 23
    call goto_xy
    ld hl, .current_path_header
    call print
    ld hl, modem_remote_current_port
    call print
    ld hl, .port_path_separator
    call print
    ld hl, modem_remote_current_path
    ld a, (hl)
    or a
    jr nz, .path_set
    ld hl, .no_host
.path_set:
    call print


.remote_menu_run:

    ld hl, .menu_items
    ld a, 1
    ld c, 8
    ld b, 4
    call screen_menu_run
    ret z
    ld hl, .menu_items
    call screen_menu_call

    call .clear_menu

    jp remote_menu


.set_host:
    ld b, 10
    ld c, 3
    call goto_xy
    ld hl, .host_prompt
    call print

    ld de, config_proposed_string
    ld hl, modem_remote_current_host
    call strcpy
    ld hl, config_proposed_string ; reuse buffer...
    xor a
    ld (hl),a  ; we *always* start off clean, to avoid any pollution...
    ld d, 120
    ld e, 20
    ld b, 10
    ld c, 18
    call readline
    ret z

    ld hl, config_proposed_string
    call config_set_host    ; TODO error handling
  
    ret


.prompt_ignore_tls:
    ld hl, .enable_tlsignore_prompt
    ld a,1  ; we allow cancel...
    call prompt_yes_no
    cp 2
    ret z   ; leave "as is" when cancelled.
    cp 1
    jr z, .disable_tls_ignore_now
    ld a, 1
    call config_set_tls_ignore    ; TODO handle errors
    ret
.disable_tls_ignore_now:
    ld a, 0
    call config_set_tls_ignore    ; TODO handle errors
    ret


.prompt_enable_remote:
    ld hl, .enable_remote_prompt
    ld a,1  ; we allow cancel...
    call prompt_yes_no
    cp 2
    ret z   ; leave "as is" when cancelled.
    cp 1
    jr z, .disable_remote_now
    ld a, 1
    call config_set_remote_enabled    ; TODO handle errors
    ret
.disable_remote_now:
    ld a, 0
    call config_set_remote_enabled    ; TODO handle errors
    ret

.set_path:
    ld de, config_proposed_string
    ld hl, modem_remote_current_path
    call strcpy

    ld b, 10
    ld c, 3
    call goto_xy
    ld hl, .path_prompt
    call print

    ld hl, config_proposed_string
    ld d, 32
    ld e, 20
    ld b, 10
    ld c, 18
    call readline
    ret z

    ld hl, config_proposed_string
    call config_set_path    ; TODO error handling

    ret

.set_port:
    ld de, config_proposed_string
    ld hl, modem_remote_current_port
    call strcpy

    ld b, 10
    ld c, 3
    call goto_xy
    ld hl, .port_prompt
    call print

    ld hl, config_proposed_string
    ld d, 5
    ld e, 6
    ld b, 10
    ld c, 18
    call readline
    ret z

    ld hl, config_proposed_string
    call config_set_port    ; TODO error handling

    ret

.show_server_info:

    call .clear_menu

    ld b, 5
    ld c, 3
    call goto_xy
    
    ld a, (modem_remote_api_level)
    or a
    jp z, .server_info_not_connected

    ld hl, .server_info_api_level_header
    call print
    ld a, (modem_remote_api_level)
    call print_hex_8

    ld b, 6
    ld c, 3
    call goto_xy
    ld hl, .server_info_version
    call print
    ld hl, modem_remote_server_version
    call print

    ld b, 7
    ld c, 3
    call goto_xy
    ld hl, .server_info_name
    call print
    ld hl, modem_remote_server_name
    call print


    ld b, 9
    ld c, 3
    call goto_xy
    ld hl, .server_info_flag_guest
    call print
    ld a, (modem_remote_flags)
    and HCCA_SERVER_FLAG_GUEST
    call .print_flag_status

    ld b, 10
    ld c, 3
    call goto_xy
    ld hl, .server_info_flag_login
    call print
    ld a, (modem_remote_flags)
    and HCCA_SERVER_FLAG_LOGIN
    call .print_flag_status

    ld b, 11
    ld c, 3
    call goto_xy
    ld hl, .server_info_flag_readonly
    call print
    ld a, (modem_remote_flags)
    and HCCA_SERVER_FLAG_READONLY
    call .print_flag_status

    ld b, 12
    ld c, 3
    call goto_xy
    ld hl, .server_info_flag_virtual
    call print
    ld a, (modem_remote_flags)
    and HCCA_SERVER_FLAG_VIRTUAL
    call .print_flag_status

    call get_key
    ret

.print_flag_status:
    or a
    jr z, .flag_is_disabled
    ld hl, .flag_enabled
    jp print

.flag_is_disabled:
    ld hl, .flag_disabled
    jp print

.server_info_not_connected:
    ld hl, .info_not_connected
    call print
    call get_key
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
    defw .prompt_enable_remote
    defb "2", 0
    defw .Opt2
    defw .set_host
    defb "3", 0
    defw .Opt3
    defw .set_path
    defb "4", 0
    defw .Opt4
    defw .set_port
    defb "5", 0
    defw .Opt5
    defw 0
    defb "6", 0
    defw .Opt6
    defw .prompt_ignore_tls
    defb "7", 0
    defw .Opt7
    defw .show_server_info

    defb 0

.Opt1:
defb "Enable/Disable",0
.Opt2:
defb "Set Host",0
.Opt3:
defb "Set Path",0
.Opt4:
defb "Set Port",0
.Opt5:
defb "Guest/Auth",0
.Opt6:
defb "TLS Ignore Certificate?",0
.Opt7:
defb "Show Server Info",0

.info_not_connected:
defb "Not connected to a server.",0

.server_info_api_level_header:
defb "API Level: 0x",0
.server_info_version:
defb "Version: ",0
.server_info_name:
defb "Name:    ",0

.server_info_flag_guest:
defb " Guest:     ", 0
.server_info_flag_login:
defb " Login:     ", 0
.server_info_flag_readonly:
defb " Read only: ", 0
.server_info_flag_virtual:
defb " V-Servers: ", 0

.flag_enabled:
defb "X",0
.flag_disabled:
defb "-",0

.query_error:
defb "Status read failed!",0 

.server_status_header:
defb "Server: ", 0
.server_status_connected:
defb "Connected", 0
.server_status_not_connected:
defb "Not Connected", 0
.server_status_name:
defb "Name: ",0


.host_prompt:
defb "Host:",0

.port_prompt:
defb "Port:",0

.enable_remote_prompt:
defb "Enable Remote Server?",0

.enable_tlsignore_prompt:
defb "WARNING: Ignore TLS errors?",0

.current_host_header:
defb "Host: ",0
.current_host_insecure_header:
defb "! ",0
.current_path_header:
defb "Port/Path: ",0
.no_host:
defb "< not set >",0

.path_prompt:
defb "Path:", 0
.port_path_separator:
defb " ", 0

.screen_header:
defb 0f4h, 0f5h, 0f6h, 0f7h, 0f2h, 0f3h
defb " NABUNET Remote Server Options"
defb 0ah

defb 0f8h, 0f9h, 0fah, 0fbh
defb "   ", 0c0h
defs 31, 0c4h
defb 0ah

defb 0fch, 0fdh, 0feh, 0ffh, 0ah, 0

