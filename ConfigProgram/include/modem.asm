; high level modem control commands... 

; The high level API can have up to four "files" open at the same time.
; Overall, it's supposed to work similar to a file handle in any other OS: 
; open via a name for read/write, then read/write bytes and see if stuff is available.

; streams also support "push notify" on incoming data; this is handled via the IRQ, 
; whenever a data block is completed.


; "modem_initialize" - performs initial handshake.
; "modem_get_state" - checks the modem state
; "modem_sendpacket" - sends low level data packet
; "open" - opens a data stream with a remote system. 
; "close" - closes a data stream.
; "read" - read the next "n" bytes to a buffer.
; "write" - write "n" bytes from a buffer.
; "seek" - send a "seek to offset" command.
; "peek" - check if data is available on a stream.
; "set_callback" - sets a callback function for new data in stream X

; returns status code in a, zero if connected, nonzero if not for any reason.
modem_get_state:
    ld a,(HCCA_STATUS)
    cp HCCA_STATUS_CONNECTED
    ret


modem_initialize:
    ; hard abort TX and RX here...
    di
    ld c, IRQ_MASK_HCCA_RX | IRQ_MASK_HCCA_TX
    call disable_interrupt_mask

    xor a
    ld (HCCA_STATUS),a
    ld (HCCA_HS_PENDING), a ; no resync now...
    ei

    
  	ld a,00fh
	out (IO_SOUND_LATCH),a
	in a,(IO_SOUND_DATA)
    and STATUS_HCCA_OVERRUN | STATUS_HCCA_FRAMING
    jr z, .modem_ready
    in a,(IO_HCCA)  ; read dummy, to clear errors.

.modem_ready:
    ld c, IRQ_MASK_HCCA_RX
    call enable_interrupt_mask

    call modem_connect

    ret

; performs handshake with modem LL protocol.
modem_connect:
    di
    ld a, HCCA_STATUS_UNKNOWN
    ld (HCCA_STATUS), a
    ld a, HCCA_XFSTATUS_IDLE
    ld (HCCA_RX_STATUS), a
    ld (HCCA_TX_STATUS), a
    xor a
    ld (HCCA_RX_ERROR), a
    ld (HCCA_TX_ERROR), a
    ld (HCCA_RX_LL_STATE), a
    ei

    ld a, 1
    ld (HCCA_HS_INIT), a
    ld a, HCCA_STATUS_CONNECTING
    ld (HCCA_STATUS), a

    ld a, (HCCA_HS_TOKEN)
    inc a
    jr nz, .token_ok
    inc a
.token_ok:
    ld (HCCA_HS_TOKEN), a
    ld a, 0
    ld b, 1
    ld hl, HCCA_HS_TOKEN
    ld c, 0
    call modem_sendpacket
    ret nz  ;; TODO: RESET STATUS TO ERROR!

    ld hl, UI_BUFFER
    ld b, 1
    ld a, 0
    call modem_wait_for_reply
    ret nz

    ; we got the reply to our initilized handshake, validate the "token"
    ld a, (UI_BUFFER)
    ld b, a
    ld a, (HCCA_HS_TOKEN)
    cp b
    ret nz  ; error...


    ld a, 0
    ld b, 1
    ld hl, HCCA_HS_TOKEN
    ld c, 1
    call modem_sendpacket
    ret nz

    ld a, 0
    ld (HCCA_HS_INIT), a
    ld a, HCCA_STATUS_CONNECTED
    ld (HCCA_STATUS), a

    xor a   ; success!
    ret



.wait_tx_done:
    push af
.wait_tx_done_loop:
    ld a, (HCCA_TX_STATUS)
    cp HCCA_XFSTATUS_RUNNING
    jr z,.wait_tx_done_loop
    cp HCCA_XFSTATUS_IDLE
    jr z,.done_good
    pop af
    ld a, 1
    or a  ; make zero flag off.
    ret
.done_good:
    pop af
    xor a   ; make zero flag on.
    ret

; a => code (0-F)
; b => length of block, 0..128
; hl => data (ignored if length is zero)
; c => 0 = new packet, 1 = reply.
modem_sendpacket:
    ld d, a
    call .wait_tx_done      ; there *might* be a stream ack going on or similar...
    ret nz
    xor a
    ld (HCCA_TX_ERROR), a
    ld a, d


    ld (HCCA_TX_BUFFER), a
    ld (HCCA_TX_LASTCODE), a
    ld a, c
    or a
    jr z, .noreply
    ld a, (HCCA_TX_BUFFER)
    or HCCA_PROT_FLAG_REPLY
    ld (HCCA_TX_BUFFER), a
.noreply:
    ld de, HCCA_TX_BUFFER+1

    ld a, b
    or a
    jr nz, .hasdata

    ld a, 2                ; no data = 2 bytes only.
    ld (HCCA_TX_TOGO), a
    ld c, 0

    jr .hasnodata
.hasdata:
    push hl
    ld a, (HCCA_TX_BUFFER)
    or HCCA_PROT_FLAG_DATA
    ld (HCCA_TX_BUFFER), a

    ld a, b
    ld (HCCA_TX_BUFFER+1), a
    ld c, a
    inc a  ;   add length byte!
    inc a  ;   add checksum byte !
    inc a  ;   add code byte too!
    ld (HCCA_TX_TOGO), a

    inc de
    ; ld a, (HCCA_TX_BUFFER)  ; inclue fully flagged byte for checksum
    ; add c
    ;ld c, a
    pop hl
    ; move "b" bytes from HL to HCCA_TX_BUFFER+2
.move_data_loop:
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    add c
    ld c,a
    djnz .move_data_loop
    
.hasnodata:
    ld a, (HCCA_TX_BUFFER)  ; inclue fully flagged byte for checksum
    add c
    ld c, a
    ld hl, HCCA_TX_BUFFER
    ld (HCCA_TX_CURRENT), hl
    ld a, HCCA_PROT_CHECKSUM_TARGET
    sub c
    ld (de),a

    ld a, HCCA_XFSTATUS_RUNNING
    ld (HCCA_TX_STATUS), a      ; start!

    ld c, IRQ_MASK_HCCA_TX
    call enable_interrupt_mask  ; and send off!

    xor a   ; we are fine...
    ret




; a => expected protocol code
; b => buffer length (max. reply size)
; hl => buffer location
; nonzero if error
; b <= recevied length if any.
modem_wait_for_reply:

    ; we should NEVER hit a race condition here;

    ld (HCCA_RX_EXPECTED), a
    ld (HCCA_RX_TARGET), hl
    ld a, b
    ld (HCCA_RX_SIZE), a
    ld a, 2
    ld (HCCA_RX_TIMEOUT), a

    ld a, HCCA_XFSTATUS_RUNNING
    ld (HCCA_RX_STATUS),a

.loop_wait_reply:
    ld a,(HCCA_RX_STATUS)
    cp HCCA_XFSTATUS_RUNNING
    jr z, .loop_wait_reply

    cp HCCA_XFSTATUS_IDLE
    ret nz

    ld a, (HCCA_RX_LENGTH)
    ld b, a

    xor a
    ret