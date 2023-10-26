update_menu:

    xor a
    ld (.has_local_boot_image),a
    ld (.has_local_firmware_image),a
    ld (.has_remote_boot_image),a
    ld (.has_remote_firmware_image),a

    ld a, (VDP_COLOR_BLACK << 4) | VDP_COLOR_DARK_GREEN
    call clear_screen
    ld hl,.screen_header
    call print

    ld c, 8
    ld b, 0
    call goto_xy
    ld hl, .checking_sd
    call print

    call config_fetch_sd_update_status
    jr z, .sd_status_done

    call main_print_modem_error_state
    ret

.sd_status_done:
    ld b,a
    and 1
    jr z, .sd_status_2
    ld a, 1
    ld (.has_local_boot_image), a
.sd_status_2:
    ld a, b
    and 2
    jr z, .sd_status_3
    ld a, 1
    ld (.has_local_firmware_image), a
.sd_status_3:
    ld hl, .done
    call print

    ld a,(modem_remote_api_level)
    or a
    jr z, .no_remote_server

    ld hl, .checking_remote
    call print

    call config_fetch_remote_update_status
    jr z, .remote_status_done

    call main_print_modem_error_state
    
    jr .no_remote_server
    
.remote_status_done:

;    ld b, 0
;  ld a, 
    ;  no net payload...
;    call .config_send_request_and_wait_reply
;    ret nz

;    ld hl, CONFIG_BUFFER
;  ld a, (hl)
;    inc hl
;  ld (modem_remote_enabled), a
; ld a, (hl)


.no_remote_server:

    jp .update_menu_run



.update_menu_run:
    ld hl, .menu_items
    ld c, 8
    ld b, 4

    ld a,(.update_menu_item)
    call screen_menu_run    ; run selection UI
    ld (.update_menu_item),a
    jr z, .update_menu_run
    ld hl, .menu_items
    call screen_menu_call   ; call selected option, if any...
    jp .update_menu_run


.menu_items:
    defb "1", 0
    defw .Opt1
    defw 0
    defb "2", 0
    defw .Opt2
    defw 0
    defb "3", 0
    defw .Opt3
    defw 0
    defb "4", 0
    defw .Opt4
    defw 0

    defb 0  ; end of menu


.has_local_boot_image:
    db 0
.has_remote_boot_image:
    db 0
.has_local_firmware_image:
    db 0
.has_remote_firmware_image:
    db 0
.update_menu_item:
    db 0

.Opt1:
defb "Update config image from SD",0

.Opt2:
defb "Update firmware from SD",0

.Opt3:
defb "Update config image from Server",0

.Opt4:
defb "Update firmware from Server",0


.screen_header:
defb 0f4h, 0f5h, 0f6h, 0f7h, 0f2h, 0f3h
defb " NABUNET Modem Update"
defb 0ah

defb 0f8h, 0f9h, 0fah, 0fbh
defb "   ", 0c0h
defs 31, 0c4h
defb 0ah

defb 0fch, 0fdh, 0feh, 0ffh, 0ah, 0

.checking_sd:
defb "  Checking SD card...",0

.checking_remote:
defb "  Checking remote server...",0

.done:
defb "done."
defb 0ah, 0
