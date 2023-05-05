
; OS Entry point is 0140Fh, but binary is loaded to 0140Dh...

org 0140Dh


defw (image_version_string - 0140Dh)       ; filler bytes for alignement; but...

;   The firmware in the modem uses these to locate a 0-terminated version string
;   inside the image. This has to be 0-offset, relative to binary start (for now)


program_entry_point:

    ; YES, I know... could have been a loop, but I was tired and 
    ;  now I want to keep it as "historic artefact" :)

    ld hl, hellorld_msg_1
    call 056bh              ; "print" method in boot rom...
    ld hl, hellorld_msg_2
    call 056bh              ; "print" method in boot rom...
    ld hl, hellorld_msg_3
    call 056bh              ; "print" method in boot rom...
    ld hl, hellorld_msg_4
    call 056bh              ; "print" method in boot rom...
    ld hl, hellorld_msg_5
    call 056bh              ; "print" method in boot rom...

    

    halt
    jr program_entry_point  ;   loop, just in case, but halt should stop us...


;   version string for the config image; will be used to tell the server
;   about the config image versoin that is active on the modem.
image_version_string:
    defb "TRIAL2b",0


;   NABU ROM "print" method expects the number of characters, screen RAM offset (2-bytes)
;   followed by the text. The character set is set up by the ROM initially;

hellorld_msg_1:
defb 40, 0a8h, 02h
defb " [\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\] "
hellorld_msg_2:
defb 40, 0d0h, 02h
defb "                                        "
hellorld_msg_3:
defb 40, 0f8h, 02h
defb "  ATKELAR'S MODEM SAYS HELLORLD! VER 2  "
hellorld_msg_4:
defb 40, 020h, 03h
defb "                                        "
hellorld_msg_5:
defb 40, 048h, 03h
defb " ", 0x84,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85
defb 0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85,0x85
defb 0x85,0x85,0x85,0x85,0x85,0x85,0x86," "

