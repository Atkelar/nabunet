

main_menu:
    ;ld a, 0e4h
    ld a, (VDP_COLOR_GRAY << 4) | VDP_COLOR_DARK_BLUE
    call clear_screen
    ld hl,.screen_header
    call print

    ld c, 3
    ld b, 13
    call goto_xy
    ld hl, .modem_info_header_mac
    call print

    ld hl, modem_mac_formatted
    call print

    ld c, 3
    ld b, 14
    call goto_xy
    ld hl, .modem_info_header_ver
    call print
    ld hl, modem_version_string
    call print

.main_menu_loop: 
    call .update_status

    ld hl, .menu_items
    ld c, 8
    ld b, 4

    ld a,(.main_menu_item)
    call screen_menu_run    ; run selection UI
    ld (.main_menu_item),a
    jr z, .main_menu_loop
    ld hl, .menu_items
    call screen_menu_call   ; call selected option, if any...
    jp main_menu


.ask_reboot:
    ld hl, .reboot_question
    ld a,0
    call prompt_yes_no
    call z, reboot_nabu_now
    ret


.update_status:
    ld c, 0
    ld b, 20
    call goto_xy
    call clear_eol
    ld hl, .status_lines_header
    call print

    ld c, 0
    ld b, 21
    call goto_xy
    call clear_eol
    ld hl, .status_lines_wifi
    call print

    

    ld c, 0
    ld b, 22
    call goto_xy
    call clear_eol
    ld hl, .status_lines_remoteserver
    call print
    ld c, 0
    ld b, 23
    call goto_xy
    call clear_eol
    ld hl, .status_lines_localserver
    call print
    ret

.screen_header:
defb 0f4h, 0f5h, 0f6h, 0f7h, 0f2h, 0f3h
defb " NABUNET Config by Atkelar"
defb 0ah

defb 0f8h, 0f9h, 0fah, 0fbh
defb "   ", 0c0h
defs 31, 0c4h
defb 0ah

defb 0fch, 0fdh, 0feh, 0ffh, 0ah, 0


.menu_items:
    defb "1", 0
    defw .Opt1
    defw 0

    defb "2", 0
    defw .Opt2
    defw wifi_menu

    defb "3", 0
    defw .Opt3
    defw remote_menu

    defb "4", 0
    defw .Opt4
    defw 0

    defb 1, 0   ; separator...
    defw 0
    defw 0

    defb "5", 0
    defw .Opt5
    defw .ask_reboot

    defb 1, 0   ; separator...
    defw 0
    defw 0

    defb "D", 0
    defw .Opt6
    defw diagnostics_menu

    defb 0  ; end of menu

.Opt1:
defb "General Options",0
.Opt2:
defb "WiFi Settings",0
.Opt3:
defb "Remote Server",0
.Opt4:
defb "Local Server",0
.Opt5:
defb "Reboot!",0
.Opt6:
defb "Diagnostics",0

.status_lines_header:
defb "  Current Settings:",0
.status_lines_wifi:
defb "    WiFi  ",0
.status_lines_remoteserver:
defb "    Remote Server   ",0
.status_lines_localserver:
defb "    Local Server    ",0

.reboot_question:
defb "Reboot your NABU?", 0

.modem_info_header_mac:
defb "Modem MAC: ",0
.modem_info_header_ver:
defb "  Version: ",0

.main_menu_item: defb 1