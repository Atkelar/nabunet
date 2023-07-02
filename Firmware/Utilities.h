#ifndef NABUUTILITIESH
#define NABUUTILITIESH

// compute (bad) CRC16 CCITT to match Nabu version. This is also used to sum up the boot images!
int compute_crc16(unsigned char* target, int len);

// appends the computed CRC value to the last two bytes in the buffer, so the validate call can check for "==0" later.
void append_crc16(unsigned char* target, int len);

// true if the checksum (at the end of the block) is valid against the expected value.
bool validate_crc16(unsigned char* target, int len);

// sets the global state machine into error mode and uses the provided blink code.
void modem_panic(int code);

// will blink the requested LED for "number" times; Can be used as a status indicator.
void blink_status_confirmed(int ledPin, int number);

unsigned char translate_wifi_status(int status);
unsigned char translate_wifi_encryption(unsigned char type);
unsigned char translate_wifi_signal_strength(int dbm);

// shared IO buffer for various functions; should be no problem as each of them is only ever active alone...
// this saves RAM and causes less fragmentation
#define BUFFER_SIZE 4096
extern unsigned char shared_buffer[];

#endif
