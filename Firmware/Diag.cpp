
#include "Diag.h"
#include "Definitions.h"
#include "Utilities.h"

// diagnostics helper: bliks the number in the byte with IO/NET LEDs, i.e. 0x5F will blink IO 6 times, NET 16 times.
//   the "+1" is to make it clear if there's a zero...
void diag_blink_byte(unsigned char n)
{
    blink_status_confirmed(PIN_LED_IO, ((n >> 4) & 0xF)+1);
    blink_status_confirmed(PIN_LED_NET, (n & 0xF)+1);
    //blink_status_confirmed(PIN_LED_ERR, 1);
}
