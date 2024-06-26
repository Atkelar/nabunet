; Main program entry point

include "nabu_hardware.asm"
include "atkelar_os.asm"

org BOOT_LOAD_ORIGIN

defw image_version_string       ; filler bytes for alignement, used to point to version string in boot image...

program_entry_point:

    ld a, 0
    call set_led_state  ; turn off all the LEDs on the front...

    call setup_interrupts

    call setup_screen

    ld hl, charset_definition
    call load_font

    ld b, 0
    ld c, 0
    call goto_xy

    ld hl, .splash_header
    call print
    ld hl, image_version_string
    call print

    ld b, 8
    ld c, 0
    call goto_xy
    ld hl, .please_wait
    call print

    ld a, 60    
    call delay_frames   ; delay slightly to show the main tech revision number...

.modem_init_retry:

    call modem_initialize
    jr z, .connected

    ld b, 9
    ld c, 3
    call goto_xy
    ld hl, .connect_failed
    call print

    call main_print_modem_error_state

    ;call .print_modem_diaginfo

    ld a, 60
    call delay_frames
    ld b, 9
    ld c, 3
    call goto_xy
    ld hl, .retrying
    call print
    jr .modem_init_retry

.connected:

    ld b, 8
    ld c, 0
    call goto_xy
    ld hl, .reading_config
    call print
    call clear_eol

    call reload_modem_info
    jr z, .config_loaded

    ;call .print_modem_diaginfo

    ld hl, .connect_failed
    call print
    ld a, 255
    call delay_frames

.config_loaded:
    jp main_menu
    ; will not return... might reboot, but not return.


main_print_modem_error_state:
    ld b, 23
    ld c, 1
    call goto_xy
    call clear_eol
    ld hl, .modem_error_header_1
    call print
    call modem_get_state_message
    call print
    ld hl, .modem_error_header_2
    call print
    call modem_get_tx_error_message
    call print
    ld hl, .modem_error_header_3
    call print
    call modem_get_rx_error_message
    call print
    ret

;; diagnostics output during connection failed events...
; .print_modem_diaginfo:
;     ld a, (HCCA_STATUS)
;     call print_hex_8
;     ld a, (HCCA_RX_ERROR)
;     call print_hex_8
;     ld a, (HCCA_TX_STATUS)
;     call print_hex_8
;     ld a, (HCCA_TX_ERROR)
;     call print_hex_8

;     ld a, (HCCA_TX_BUFFER)
;     call print_hex_8
;     ld a, (HCCA_TX_BUFFER+1)
;     call print_hex_8
;     ld a, (HCCA_TX_BUFFER+2)
;     call print_hex_8
;     ld a, (HCCA_TX_BUFFER+3)
;     call print_hex_8

;     ld a, (HCCA_RX_LL_STATE)
;     call print_hex_8
;     ld a, (HCCA_RX_LL_CODE)
;     call print_hex_8
;     ld a, (HCCA_RX_LL_LENGTH)
;     call print_hex_8
;     ld a, (HCCA_RX_LL_CHECKSUM)
;     call print_hex_8
;     ret

; include system code

include "irq.asm"
include "screen.asm"
include "system.asm"
include "keyboard.asm"
include "modem.asm"
include "strings.asm"

include "menu.asm"
include "utility.asm"
include "ui.asm"

; include configuration program parts

include "update_menu.asm"
include "main_menu.asm"
include "wifi_menu.asm"
include "remote_menu.asm"
include "diagnostics_menu.asm"
include "config_functions.asm"

;  Character set for config app is 0x20-0xff
;  the "load charset" function will take first 
;  byte as "count", second byte as "first char"
;  that simplifies "limited" charset changes
charset_definition:

defb 224          ; number of chars in set...
defb 32           ; first character code in set...
incbin "Assets/config_charset.bin"

; debugging_marker:
; push hl
; push bc
; push af
; ld hl, dbg_1
; call 056bh              ; "print" method in boot rom...
; ld hl, dbg_mark
; inc (hl)
; pop af
; pop bc
; pop hl
; ret


; dbg_1:
; defb 2, 0a8h, 02h
; dbg_mark:
; defb "0X"

.modem_error_header_1:
    defb "MDM: ",0
.modem_error_header_2:
    defb " TX: ",0
.modem_error_header_3:
    defb " RX: ",0

.splash_header:
    defb "NABUNET Modem Config, ", 0

.reading_config:
    defb "reading configuraton...", 0
.please_wait:
    defb "connecting modem...", 0

.connect_failed:
    defb "...failed! ", 0

.retrying:
    defb "retrying...",0

modem_config_var_start:
modem_mac_formatted:
    defs 18
modem_version_string:
    defs 32

modem_wifi_enabled:
    defb 0
modem_wifi_ssid_set:
    defb 0
modem_wifi_key_set:
    defb 0
modem_wifi_status:
    defb 0
modem_wifi_signal:
    defb 0

modem_wifi_current_ssid:
    defs 33
config_proposed_string:
    defs 33
modem_wifi_current_ip:
    defs 16 ; IP4 only, sorry. 3*4+3+ zero.

modem_remote_current_host:
    defs 121
modem_remote_current_path:
    defs 33
modem_remote_current_port:
    defs 6  ; 5+0 
modem_remote_ignore_tls:
    defb 0
modem_remote_flags:
    defb 0
modem_remote_api_level:
    defb 0
modem_remote_enabled:
    defb 0
modem_remote_server_name:
    defs 33
modem_remote_server_version:
    defs 33

    
menu_temp_vars:
    defs 256

image_version_string:
    defb "1.0.2-BETA",0
