

main_menu:
    ;ld a, 0e4h
    ld a, (VDP_COLOR_LIGHT_YELLOW << 4) | VDP_COLOR_DARK_BLUE
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

    ld c, 8
    ld b, 8
    call goto_xy
    ld hl, .Opt5
    call print

.main_menu_loop:        ; TODO: better (centralized?) menu handling...
    call .update_status
    call get_key
    cp 035h ; "5"
    call z, .ask_reboot
    jp .main_menu_loop



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
defb " NABUNET Config Program - 0.1b"
defb 0ah

defb 0f8h, 0f9h, 0fah, 0fbh
defb "   --------------------------------"
defb 0ah

defb 0fch, 0fdh, 0feh, 0ffh, 0ah, 0

.menu_items:
    defb 5
    defw .Opt1, .Opt2, .Opt3, .Opt4, .Opt5
.Opt1:
defb "1: General Options",0
.Opt2:
defb "2: WiFi Settings",0
.Opt3:
defb "3: Remote Server",0
.Opt4:
defb "4: Local Server",0
.Opt5:
defb "5: Reboot!",0

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
