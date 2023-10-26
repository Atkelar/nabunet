#ifndef NABUNETDEFINITIONSH
#define NABUNETDEFINITIONSH

// version number of firmware, for reporting... Maxmimum 16 chars!
// must be defined before any includes.
#define NABUNET_MODEM_FIRMWARE_VERSION "1.0.0 beta"



// LED status pins
#define PIN_LED_ERR 10
#define PIN_LED_NET 2
#define PIN_LED_IO 4

// Active high or low?
#define LED_ON 0    // LOW
#define LED_OFF 1   // HIGH

// ms delay for blinking signals. Must be less than 1000.
#define BLINK_DELAY 250

// Pins 12, 13, 14 are HSPI and should connect up to the SD Card
// IO Pin 5 is left for SD CS pin...
#define PIN_SD_CS 5

// pin 15 MUST be pulled low, othewise boot fails! Use it for output of 5V enable active high signal.
#define PIN_FIVEV_ENABLE 15


// "Signal" button, pulled high, active LOW.
#define PIN_SIGNAL 16

// (Error) signals are "blink codes" for the error LED
#define ERROR_SIGNAL_LOCALSERVERFAILD 2  // SD card based server was requested but didn't work out. Missing or bad files, broken card...
#define ERROR_SIGNAL_WIFIFAILED 3   // WiFi was configured, but has failed to connect to the remote server.
#define ERROR_SIGNAL_NOSERVER 4     // No server available; Both WiFi and Local server are not available.
#define ERROR_SIGNAL_FATAL_COM_ERROR 5  // the modem communication failed in an unexpected way.
#define ERROR_SIGNAL_REMOTE_CONN_FAILED 6 // remote server didn't reply or replied out of bounds
#define ERROR_SIGNAL_UPDATEFAILED 7 // Firmware update failed.

// the maximum send/receive buffer sizes
// tx buffer might need up to 512bytes + spare for 
// fully escaped loader block. Be sure to make them at leaset that size!
#define HCCA_BUFFER_SIZE 1024


// The filename on the SD card that is used to push a new config image to the internal storage.
const char BootImageFileName[] = "/nabuboot.img";
const char FirmwareImageFileName[] = "/nabufirm.img";
const char FirmwareTempFileName[] = "/nabu!ota.img";

// The internal filenames for the SPIFFS files to hold the config boot image. Two names to 
// alternate between 1 and 2, so a failed update will not brick the modem.
#define IMAGEFILE_1 "/cfgimg.1"
#define IMAGEFILE_2 "/cfgimg.2"



#endif
