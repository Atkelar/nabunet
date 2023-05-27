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


    jp main_menu
    ; will not return... might reboot, but not return.

; include system code

include "irq.asm"
include "screen.asm"
include "system.asm"
include "keyboard.asm"

include "menu.asm"

; include configuration program parts

include "main_menu.asm"

;  Character set for config app is 0x20-0xff
;  the "load charset" function will take first 
;  byte as "count", second byte as "first char"
;  that simplifies "limited" charset changes
charset_definition:

defb 224          ; number of chars in set...
defb 32           ; first character code in set...
incbin "Assets/config_charset.bin"

debugging_marker:
push hl
push bc
push af
ld hl, dbg_1
call 056bh              ; "print" method in boot rom...
ld hl, dbg_mark
inc (hl)
pop af
pop bc
pop hl
ret


dbg_1:
defb 2, 0a8h, 02h
dbg_mark:
defb "0X"


image_version_string:
defb "1.0.0.0 BETA",0

