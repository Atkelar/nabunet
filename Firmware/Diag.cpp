
#include "Diag.h"
#include "Definitions.h"
#include "Utilities.h"

// diagnostics helper: bliks the number in the byte with IO/NET LEDs, i.e. 0x5F will blink IO 5 times, NET 15 times.
void diag_blink_byte(unsigned char n)
{
    blink_status_confirmed(PIN_LED_IO, (n >> 4) & 0xF);
    blink_status_confirmed(PIN_LED_NET, n & 0xF);
}
