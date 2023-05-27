; The values in this file are arbitrary and selected for "Atkelar's OS"
;


IRQ_TABLE_ADDRESS:      equ 01000h

OS_VARIABLE_BASE:      equ 01010h

IRQ_ENABLED_FLAGS:      equ OS_VARIABLE_BASE

; keyboard and joystick related variables...
KBD_BUFFER_START:       equ IRQ_ENABLED_FLAGS + 1
KBD_BUFFER_END:         equ KBD_BUFFER_START + 1
JOY_STATUS_1:           equ KBD_BUFFER_END + 1
JOY_STATUS_2:           equ JOY_STATUS_1 + 1
JOY_NEXT_NUMBER:        equ JOY_STATUS_2 + 1      ; joystick data is prefixed with "selection" numbers...
KEY_STATES:             equ JOY_NEXT_NUMBER+1  ; two bytes for 16 flags...

KBD_BUFFER:             equ KEY_STATES+2
KBD_BUFFER_LENGTH:      equ 32

; 3 byte counter of frame # - yields about 77 hour before rolling over.
; will be used by cursor flash logic and music player code.
VDP_TIMER:              equ KBD_BUFFER + KBD_BUFFER_LENGTH

; HCCA TX/RX buffers
;       0x1010-0x1013    TX buffer structure: [bytestogo] [currentpointer]
HCCA_TX_TOGO:           equ VDP_TIMER + 3
HCCA_TX_CURRENT:        equ HCCA_TX_TOGO + 2
;       0x1014           TX result: 0 = success, 1 = running, 2 = error
HCCA_TX_STATUS:         equ HCCA_TX_CURRENT + 2

;       0x1010-0x1013    TX buffer structure: [bytestogo] [currentpointer]
HCCA_RX_TOGO:           equ HCCA_TX_STATUS + 1
HCCA_RX_CURRENT:        equ HCCA_RX_TOGO + 2
;       0x1014           TX result: 0 = success, 1 = running, 2 = error
HCCA_RX_RESULT:         equ HCCA_RX_CURRENT + 2
HCCA_RX_LENGTH:         equ HCCA_RX_RESULT + 1

; Screen/Cursor logic
CURSOR_ORIGINAL_CHAR:   equ HCCA_RX_LENGTH + 2
CURSOR_POSITION_X:      equ CURSOR_ORIGINAL_CHAR + 1
CURSOR_POSITION_Y:      equ CURSOR_POSITION_X + 1
CURSOR_OFFSET:          equ CURSOR_POSITION_Y + 1
CURSOR_FLAGS:           equ CURSOR_OFFSET + 2
SCREEN_MODE:            equ CURSOR_FLAGS + 1
SCREEN_WIDTH:           equ SCREEN_MODE + 1
SCREEN_HEIGHT:          equ SCREEN_WIDTH + 1

; Callback registrations
SLOT_0_CALLBACK:        equ SCREEN_HEIGHT + 1
SLOT_1_CALLBACK:        equ SLOT_0_CALLBACK + 2
SLOT_2_CALLBACK:        equ SLOT_1_CALLBACK + 2
SLOT_3_CALLBACK:        equ SLOT_2_CALLBACK + 2



OS_VARIABLE_LENGTH:     equ (SLOT_3_CALLBACK - OS_VARIABLE_BASE)+1

; Keyboard "on/off" markers... These have to match the "number/index" 
; of the received key codes.
KBD_STATE_RIGHT:       equ 0001h
KBD_STATE_LEFT:        equ 0002h
KBD_STATE_UP:          equ 0004h    ; CHECK! Might be down?
KBD_STATE_DOWN:        equ 0008h    ; CHECK! Might be up?
KBD_STATE_SRIGHT:      equ 0010h  
KBD_STATE_SLEFT:       equ 0020h
KBD_STATE_NO:          equ 0040h
KBD_STATE_YES:         equ 0080h
KBD_STATE_SYM:         equ 0100h
KBD_STATE_PAUSE:       equ 0200h
KBD_STATE_TV:          equ 0400h

; Virtual key code; is inserted into the key queue upon key-up
KBD_VKEY_RIGHT:        equ 080h
KBD_VKEY_LEFT:         equ 081h
KBD_VKEY_UP:           equ 082h    ; CHECK! Might be down?
KBD_VKEY_DOWN:         equ 083h    ; CHECK! Might be up?
KBD_VKEY_SRIGHT:       equ 084h  
KBD_VKEY_SLEFT:        equ 085h
KBD_VKEY_NO:           equ 086h
KBD_VKEY_YES:          equ 087h
KBD_VKEY_SYM:          equ 088h
KBD_VKEY_PAUSE:        equ 089h
KBD_VKEY_TV:           equ 08Ah

; VDP color constants
; TMS9918A, page 2-17

VDP_COLOR_TRANSPARENT:   equ 00h
VDP_COLOR_BLACK:         equ 01h
VDP_COLOR_MEDIUM_GREEN:  equ 02h
VDP_COLOR_LIGHT_GREEN:   equ 03h
VDP_COLOR_DARK_BLUE:     equ 04h
VDP_COLOR_LIGHT_BLUE:    equ 05h
VDP_COLOR_DARK_RED:      equ 06h
VDP_COLOR_CYAN:          equ 07h
VDP_COLOR_MEDIUM_RED:    equ 08h
VDP_COLOR_LIGHT_RED:     equ 09h
VDP_COLOR_DARK_YELLOW:   equ 0Ah
VDP_COLOR_LIGHT_YELLOW:  equ 0Bh
VDP_COLOR_DARK_GREEN:    equ 0Ch
VDP_COLOR_MAGENTA:       equ 0Dh
VDP_COLOR_GRAY:          equ 0Eh
VDP_COLOR_WHITE:         equ 0Fh

CURSOR_FLAG_HEIGHT:      equ 07h     ; Number of lines from bottom to top (minus 1): 0 = 1 pixel, 7 = 8 pixels...
CURSOR_FLAG_BLINKON:     equ 40h     ; nonzero if the cursor is currently in "inverse" mode.
CURSOR_FLAG_VISIBLE:     equ 80h     ; nonzero if the cursor is visible on screen - i.e. if the flashing code should run.

SCREEN_MODE_TEXT:        equ 00h 
SCREEN_MODE_GFX1:        equ 01h
SCREEN_MODE_GFX2:        equ 02h
SCREEN_MODE_MCOL:        equ 03h
