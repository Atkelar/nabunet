// use serial port for diagnostic output. If set, the regular Nabu port will be not functioning!
// defining this will not enable the level converter and keep the serial IO to any connected
// programmer for looking into diagnostic outputs. see also: diag macros!
//#define SERIALDIAG


// diagnostic output macros

#ifndef diag
// diagnostic macros...
#ifdef SERIALDIAG
// #define diag(...) Serial.print(#__VA_ARGS__);
#define diag(x) Serial.print(x);
#define diaghex(x) Serial.print(" 0x"); Serial.print(x, HEX);
#define DISABLE_HCCA
#else
#define diag(x) ;
#define diaghex(x) ;
// can't co-exist on same port, so we don't compile that in...
#endif

// diagnostics helper: bliks the number in the byte with IO/NET LEDs, i.e. 0x5F will blink IO 5 times, NET 15 times.
void diag_blink_byte(unsigned char n);

#endif
