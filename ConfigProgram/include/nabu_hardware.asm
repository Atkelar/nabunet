; include file for symbolic NABU PC constant values.
; memory and IO port names to avoid typos and misplacing data...

; origin address the NABU PC boot loader uses; note that the "jump" 
; is two bytes inside that origin!
; boot-able programs need to do "org BOOT_LOAD_ORIGIN" followed 
; by "dw 0" and then start the code!
BOOT_LOAD_ORIGIN:   equ 0140Dh

; Top Of Stack as well as "status byte" location
STATUS_BYTE: equ    0FFEEh
; magic bytes address for detecing a "soft reset"
SOFT_BOOT_MAGIC: equ 0fffeh
SOFT_BOOT_MAGIC_VALUE: equ 05AA5h

; IO port range
IO_CONTROL:     equ 000h
IO_VDP_CONTROL:   equ 0a1h
IO_VDP_DATA:    equ 0a0h
IO_PRINTER:     equ 0B0h
IO_KBD_STATUS:  equ 091h
IO_KBD_DATA:    equ 090h
IO_HCCA:        equ 080h
IO_SOUND_LATCH: equ 041h
IO_SOUND_DATA:  equ 040h
IO_SLOT_0_BASE: equ 0C0h
IO_SLOT_1_BASE: equ 0D0h
IO_SLOT_2_BASE: equ 0E0h
IO_SLOT_3_BASE: equ 0F0h


; IRQ Enable masks
IRQ_MASK_HCCA_RX:   equ 080h
IRQ_MASK_HCCA_TX:   equ 040h
IRQ_MASK_KBD:       equ 020h
IRQ_MASK_VDP:       equ 010h
IRQ_MASK_SLOT_3:    equ 008h
IRQ_MASK_SLOT_2:    equ 004h
IRQ_MASK_SLOT_1:    equ 002h
IRQ_MASK_SLOT_0:    equ 001h

; Status byte masks
STATUS_HCCA_OVERRUN:    equ 040h
STATUS_HCCA_FRAMING:    equ 020h
STATUS_PRINTER_BUSY:    equ 010h
STATUS_IRQ_LEVEL:       equ 00Eh
STATUS_IRQ_ACTIVE:      equ 001h

; Control byte masks
CONTROL_ROMEN:          equ 001h
CONTROL_RF_SWITCH:      equ 002h
CONTROL_PRINT_STRB:     equ 004h
CONTROL_LED_CHECK:      equ 008h
CONTROL_LED_ALERT:      equ 010h
CONTROL_LED_PAUSE:      equ 020h

CONTROL_LED_MASK:       equ 038h


JOYSTICK_MASK_FIRE:     equ 010h
JOYSTICK_MASK_LEFT:     equ 001h
JOYSTICK_MASK_RIGHT:    equ 004h
JOYSTICK_MASK_UP:       equ 008h
JOYSTICK_MASK_DOWN:     equ 002h

KBD_JOYSTICK_1_HEADER:  equ 080h
KBD_JOYSTICK_2_HEADER:  equ 081h

KBD_STATUS_OVERRUN:     equ 010h
KBD_STATUS_RX_RDY:      equ 002h


KBD_CODE_D_RIGHT:       equ 0E0h
KBD_CODE_D_LEFT:        equ 0E1h
KBD_CODE_D_UP:          equ 0E2h    ; CHECK! Might be down?
KBD_CODE_D_DOWN:        equ 0E3h    ; CHECK! Might be up?
KBD_CODE_D_SRIGHT:      equ 0E4h  
KBD_CODE_D_SLEFT:       equ 0E5h
KBD_CODE_D_NO:          equ 0E6h
KBD_CODE_D_YES:         equ 0E7h
KBD_CODE_D_SYM:         equ 0E8h
KBD_CODE_D_PAUSE:       equ 0E9h
KBD_CODE_D_TV:          equ 0EAh

KBD_CODE_U_RIGHT:       equ 0F0h
KBD_CODE_U_LEFT:        equ 0F1h
KBD_CODE_U_UP:          equ 0F2h    ; CHECK! Might be down?
KBD_CODE_U_DOWN:        equ 0F3h    ; CHECK! Might be up?
KBD_CODE_U_SRIGHT:      equ 0F4h  
KBD_CODE_U_SLEFT:       equ 0F5h
KBD_CODE_U_NO:          equ 0F6h
KBD_CODE_U_YES:         equ 0F7h
KBD_CODE_U_SYM:         equ 0F8h
KBD_CODE_U_PAUSE:       equ 0F9h
KBD_CODE_U_TV:          equ 0FAh


