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

    ld c, 1
    ld b, 1
    call goto_xy    ; test: put cursor in logo...


.wifi_menu_loop:        ; TODO: better (centralized?) menu handling...
    call .update_status
    call get_key

    cp 031h ; "1"
    call z, .prompt_enable_wifi

    cp 032h ; "2"
    call z, .set_ssid_manually

    cp 033h ; "2"
    call z, .scan_ssids

    jp .wifi_menu_loop


.update_status:
    ret

.prompt_enable_wifi:
    ret

.set_ssid_manually:
    ret

.scan_ssids:
    ret

.Opt1:
defb "1: Enabled",0
.Opt2:
defb "2: Set SSID",0
.Opt3:
defb "3: Scan/select SSID",0
.Opt4:
defb "4: Set Key",0


.screen_header:
defb 0f4h, 0f5h, 0f6h, 0f7h, 0f2h, 0f3h
defb " NABUNET WiFi Options"
defb 0ah

defb 0f8h, 0f9h, 0fah, 0fbh
defb "   ", 0c0h
defs 31, 0c4h
defb 0ah

defb 0fch, 0fdh, 0feh, 0ffh, 0ah, 0
