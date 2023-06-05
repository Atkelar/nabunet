/*
 * 
 * NABU Modem Firmware - Version 1.0 - Copyright 2023 by Atkelar - All Rights Reserved; 
 * for License info, see the project repo, this firmware is covered by the same as the project. 
 * [TODO: update license info]
 * 
 * 
 * Hardware info: the ESP8622 GPIO pins need special considerations. 
 * #9 is misbehaving, avoid. 
 * #0 is required for the firmware programming, keep free of use. 
 * #15 needs to be pulled low during boot, can be used as output.
 * #14 -> SCLK
 * #12 _> MISO
 * #13 -> MOSI
 * #1 -> TX
 * #3 -> RX
 * #2 -> LED + Output
 * #4 -> Output or Input
 * #5 -> Output or Input
 * #16 -> Input, supports WAKE, can be pulled HIGH or LOW during boot.
 * #10 -> works as output
 * 
 */

// use serial port for diagnostic output. If set, the regular Nabu port will be not functioning!
// defining this will not enable the level converter and keep the serial IO to any connected
// programmer for looking into diagnostic outputs. see also: diag macros!
//#define SERIALDIAG


/*mk
 * 
 * What needs to happen - high level operations definition:
 * 
 * SPIFFS - stores "Config Modem" program image and Modem config settings.
 * SDCard - can be used to load new Config program image into EEPROM or as a local "server" storage. 
 * 
 * Updates to the config settings are done exclusively via the Nabu config program (from SPIFFS!)
 * 
 * Boot sequence:
 *  1.: initailized all hardware, check EEPROM config, create blank new config if invalid. Check for present SD card,
 *  
 *  2.: check if the Reset button is pressed, if so, enter Servicing mode:
 *  
 *    2a.: If SD card was found, check for "NABUCONF.IMG" file in root folder, maximum 24k in size. If found, present "blinking LED pattern" and wait for 1-2 seconds for another press of the reset button to confirm the choice.
 *    2b.:   load the NABUCONF.IMG file and push it to the EEPROM. Update size and version code. Find the version number string based on first 2 bytes, load the version string (up to 32 chars) and update the configuration when successful. Blink confirmation or light up error LED.
 *    2c.: anyhow, mark the current boot as "servicing boot" - i.e. force channel code entry and make the internal image the 0-image.
 *  
 *  3.: if SD card is present and the config allows "local server" mode, check for "NABU" folder in root and enable local server if found.
 *  
 *  4.: if WiFi is enabled, start the connection phase and light up NET LED during that phase. If Connection works, Blink WiFi LED to confirm, else light up error LED.
 *  
 *  5.: Enable HCCA interface and wait for commmunication...
 *  
 *  
 * 
 */



// Yes, we want to connect to the WiFi...
#include <ESP8266WiFi.h>

// We need to avoid clashing with the SD File class later...
#define FS_NO_GLOBALS
// ...which would happen if we just include FS.h
#include <FS.h>


// Tried to use the "SD" library... did NOT work, even after three full days of scope diagnostics...
// it might clash with the FS library, or other somesuch nice effects. SdFat works, even with larger SD cards.
#include <SdFat.h>


// LED status pins
#define PIN_LED_ERR 10
#define PIN_LED_NET 2
#define PIN_LED_IO 4


// Active high or low?
#define LED_ON LOW
#define LED_OFF HIGH

// ms delay for blinking signals. Must be less than 1000.
#define BLINK_DELAY 250


// Pins 12, 13, 14 are HSPI and should connect up to the SD Card
// IO Pin 5 is left for SD CS pin...
#define PIN_SD_CS 5

// pin 15 MUST be pulled low, othewise boot fails! Use it for output of 5V enable active high signal.
#define PIN_FIVEV_ENABLE 15


// Reset button, pulled high, active LOW.
#define PIN_SIGNAL 16


// we write a constant size config blob...
// this originated as an "external ROM" idea, so it's kept around...
#define CONFIGFILESIZE 2048
#define CONFIGFILENAME "/cfg.dat"

// Magic bytes for config block to detect "virgin" ROMs or broken files.
#define CONFIGBLOCK_MAGIC_1 0xF5
#define CONFIGBLOCK_MAGIC_2 0x5A


// Fallback server URL for broken configs
#define DEFAULT_SERVER_URL "https://nabu.atkelar.com"

// version number of firmware, for reporting... Maxmimum 16 chars!
#define NABUNET_MODEM_FIRMWARE_VERSION "1.0.0 beta"

// Maximum size for a configuration image. SHould be slightly less than 32k, to open optino to replace
// built in EEPROM with an external 32k one eventually...
#define IMAGESIZELIMIT 24*1024


//  ********************************  Configurable values end here  ***************************


// Flags for the configuration block

// We have enabled WiFi connectivity (SSID, KEY and SERVER URL are "valid" and should be used)
#define CONFIG_FLAG_USE_WIFI 1

// We want to use a locally present SD card as a server. If a card is present, it will 
// override the WiFi selection.
#define CONFIG_FLAG_USE_SD 2

// We are authenticated at the remote server; If not, we access as anonymous user.
#define CONFIG_FLAG_IS_AUTHENTICATED 4

// The local SD server can be updated; R/O if not set.
#define CONFIG_FLAG_SD_WRITE 8

// The internal ROM has an active config image. Should only be missing on virgin setups and requires
// a boot update from SD to fix.
#define CONFIG_FLAG_HAS_IMAGE 0x8000


// Configuration block version.
#define CONFIG_VERSION 0x1



// Overall modem state codes.
#define STATE_BOOT 0
#define STATE_RUN 1
#define STATE_SERVICING 2
#define STATE_CONNECT_SD 3
#define STATE_CONNECT_WIFI 4
#define STATE_CONNECTING_WIFI 5
#define STATE_START 6

#define STATE_ERROR 0xFF


// The communication with the NABU is done in a state machine. That way, we can switch between
// states in the individual control loops at any time; Note that the main loop will run the
// hcca_ methods on every loop, so "hopping" from one to the other state is simply done by
// changing to the desired new one and exiting the current loop.
// This is done so that the WiFi and IP core can get as many chances to wake up as possible.
// And also we try to avoid the watchdogs!
#define HCCA_STATE_BOOT 0
#define HCCA_STATE_CONTACTED 1
#define HCCA_STATE_INIT_1 2
#define HCCA_STATE_INIT_2 3
#define HCCA_STATE_WAIT_FOR_CODE 4
#define HCCA_STATE_WAIT_FOR_BOOT 5
#define HCCA_STATE_SEND_BLOCK 6
#define HCCA_STATE_RECEIVE_CODE 7
#define HCCA_STATE_BOOT_REQUESTED 8
#define HCCA_STATE_BOOT_RUNNING 9
#define HCCA_STATE_WAIT_FOR_BLOCK_REQUEST 10
#define HCCA_STATE_WAIT_FOR_BLOCK_NUM 11
#define HCCA_STATE_RUN 13
#define HCCA_STATE_SEND_BLOCK_GO 14

// NabuNet state machine values:
#define NN_STATE_UNKNOWN 0
#define NN_STATE_CONNECTING 1
#define NN_STATE_CONNECTED 2
#define NN_STATE_ERROR 3


// (Error) signals are "blink codes" for the error LED
#define ERROR_SIGNAL_LOCALSERVERFAILD 2  // SD card based server was requested but didn't work out. Missing or bad files, broken card...
#define ERROR_SIGNAL_WIFIFAILED 3   // WiFi was configured, but has failed to connect to the remote server.
#define ERROR_SIGNAL_NOSERVER 4     // No server available; Both WiFi and Local server are not available.
#define ERROR_SIGNAL_FATAL_COM_ERROR 5  // the modem communication failed in an unexpected way.


// the maximum send/receive buffer sizes
// tx buffer might need up to 512bytes + spare for 
// fully escaped loader block. Be sure to make them at leaset that size!
#define HCCA_BUFFER_SIZE 1024



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

// the configurationn structure for mapping the settings to the EEPROM storage.
struct ConfigurationInfo
{
  int Version;
  int Flags;

  int ChannelCode;
  
  char SSID[33];
  char NetworkKey[65];
  char NetworkHost[121];
  char NetworkUserName[40];
  char NetworkUserToken[16];

  int ConfigImageSize;
  int ActiveConfigFile;
  char ConfigImageVersion[32];
};

// The structure is used for EEPROM IO, to make changes easier, keep the settings 
// as normal variables and copy them over during load/save.
int ConfigFlags;
int ChannelCode;
char SSID[33];
char NetworkKey[65];
char NetworkHost[121];
char NetworkUserName[40];
char NetworkUserToken[16];
char ConfigImageVersion[32];
int ConfigImageSize;
int ActiveConfigFile;

// operational varaibles...
bool ForceChannelQuery;
bool LocalServerAvailbale;
bool WiFiAvailable;
bool IsServicingMode;

// currently requsted block number...
int HCCARequestedBlockNum;
// the current block was the last one in the "file"...
bool HCCAIsLastBlock;


// State machine for the HCCA modem.
int ModemState;

bool SDCardDetected;

// HCCA TX/RX buffers.
byte HCCASendBuffer[HCCA_BUFFER_SIZE];
byte HCCAReceiveBuffer[HCCA_BUFFER_SIZE];

int HCCARxStart, HCCARxEnd, HCCATxStart, HCCATxEnd;
int HCCASendBlockSize;

// State machine for low level NABU HCCA...
int HCCAState;

// State machine for higher level NabuNet com...
int NabuNetState;

// State change indicator helpers...
// specifically, the "reset" modem command sequence: 0x83, 0x83, 0x83, 0x83, 0x81, etc... with at least 500ms delay in between is important...
int LastHCCAByte;
int LastHCCAInput;
int HCCAResetSequenceCount;

int PanicCode;

// NabuNet specific modem status...
unsigned long nn_started;
bool nn_incoming;
int nn_checksum;
byte nn_code;
bool nn_isReply;
bool nn_hasPayload;
bool nn_rxDone;
int nn_payloadLength;
int nn_payloadOffset;
int nn_connectToken;
bool nn_connectInitiated;
byte nn_rx_payload[128];


// shared IO buffer for various functions; should be no problem as each of them is only ever active alone...
// this saves RAM and causes less fragmentation
#define BUFFER_SIZE 4096
unsigned char buffer[BUFFER_SIZE];

// SD card root object... initialized during setup, so we don't yet support
// "hot plug or unplug" for the SD card; this might change eventually. There just 
// wasn't a pin available that would be useful for the "detect card" switch.
SdFat sd;


// The filename on the SD card that is used to push a new config image to the internal storage.
const char BootImageFileName[] = "/nabuboot.img";

// The internal filenames for the SPIFFS files to hold the config boot image. Two names to 
// alternate between 1 and 2, so a failed update will not brick the modem.
#define IMAGEFILE_1 "/cfgimg.1"
#define IMAGEFILE_2 "/cfgimg.2"



// Table mimics the computation in the Nabu computer: CCITT CRC 16 in "buggy" mode...
const unsigned char CRC_Table[] = {
            0x00, 0x00, 0x21, 0x10, 0x42, 0x20, 0x63, 0x30, 0x84, 0x40, 0xA5, 0x50, 0xC6, 0x60, 0xE7, 0x70,
            0x08, 0x81, 0x29, 0x91, 0x4A, 0xA1, 0x6B, 0xB1, 0x8C, 0xC1, 0xAD, 0xD1, 0xCE, 0xE1, 0xEF, 0xF1,
            0x31, 0x12, 0x10, 0x02, 0x73, 0x32, 0x52, 0x22, 0xB5, 0x52, 0x94, 0x42, 0xF7, 0x72, 0xD6, 0x62,
            0x39, 0x93, 0x18, 0x83, 0x7B, 0xB3, 0x5A, 0xA3, 0xBD, 0xD3, 0x9C, 0xC3, 0xFF, 0xF3, 0xDE, 0xE3,
            0x62, 0x24, 0x43, 0x34, 0x20, 0x04, 0x01, 0x14, 0xE6, 0x64, 0xC7, 0x74, 0xA4, 0x44, 0x85, 0x54,
            0x6A, 0xA5, 0x4B, 0xB5, 0x28, 0x85, 0x09, 0x95, 0xEE, 0xE5, 0xCF, 0xF5, 0xAC, 0xC5, 0x8D, 0xD5,
            0x53, 0x36, 0x72, 0x26, 0x11, 0x16, 0x30, 0x06, 0xD7, 0x76, 0xF6, 0x66, 0x95, 0x56, 0xB4, 0x46,
            0x5B, 0xB7, 0x7A, 0xA7, 0x19, 0x97, 0x38, 0x87, 0xDF, 0xF7, 0xFE, 0xE7, 0x9D, 0xD7, 0xBC, 0xC7,
            0xC4, 0x48, 0xE5, 0x58, 0x86, 0x68, 0xA7, 0x78, 0x40, 0x08, 0x61, 0x18, 0x02, 0x28, 0x23, 0x38,
            0xCC, 0xC9, 0xED, 0xD9, 0x8E, 0xE9, 0xAF, 0xF9, 0x48, 0x89, 0x69, 0x99, 0x0A, 0xA9, 0x2B, 0xB9,
            0xF5, 0x5A, 0xD4, 0x4A, 0xB7, 0x7A, 0x96, 0x6A, 0x71, 0x1A, 0x50, 0x0A, 0x33, 0x3A, 0x12, 0x2A,
            0xFD, 0xDB, 0xDC, 0xCB, 0xBF, 0xFB, 0x9E, 0xEB, 0x79, 0x9B, 0x58, 0x8B, 0x3B, 0xBB, 0x1A, 0xAB,
            0xA6, 0x6C, 0x87, 0x7C, 0xE4, 0x4C, 0xC5, 0x5C, 0x22, 0x2C, 0x03, 0x3C, 0x60, 0x0C, 0x41, 0x1C,
            0xAE, 0xED, 0x8F, 0xFD, 0xEC, 0xCD, 0xCD, 0xDD, 0x2A, 0xAD, 0x0B, 0xBD, 0x68, 0x8D, 0x49, 0x9D,
            0x97, 0x7E, 0xB6, 0x6E, 0xD5, 0x5E, 0xF4, 0x4E, 0x13, 0x3E, 0x32, 0x2E, 0x51, 0x1E, 0x70, 0x0E,
            0x9F, 0xFF, 0xBE, 0xEF, 0xDD, 0xDF, 0xFC, 0xCF, 0x1B, 0xBF, 0x3A, 0xAF, 0x59, 0x9F, 0x78, 0x8F,
            0x88, 0x91, 0xA9, 0x81, 0xCA, 0xB1, 0xEB, 0xA1, 0x0C, 0xD1, 0x2D, 0xC1, 0x4E, 0xF1, 0x6F, 0xE1,
            0x80, 0x10, 0xA1, 0x00, 0xC2, 0x30, 0xE3, 0x20, 0x04, 0x50, 0x25, 0x40, 0x46, 0x70, 0x67, 0x60,
            0xB9, 0x83, 0x98, 0x93, 0xFB, 0xA3, 0xDA, 0xB3, 0x3D, 0xC3, 0x1C, 0xD3, 0x7F, 0xE3, 0x5E, 0xF3,
            0xB1, 0x02, 0x90, 0x12, 0xF3, 0x22, 0xD2, 0x32, 0x35, 0x42, 0x14, 0x52, 0x77, 0x62, 0x56, 0x72,
            0xEA, 0xB5, 0xCB, 0xA5, 0xA8, 0x95, 0x89, 0x85, 0x6E, 0xF5, 0x4F, 0xE5, 0x2C, 0xD5, 0x0D, 0xC5,
            0xE2, 0x34, 0xC3, 0x24, 0xA0, 0x14, 0x81, 0x04, 0x66, 0x74, 0x47, 0x64, 0x24, 0x54, 0x05, 0x44,
            0xDB, 0xA7, 0xFA, 0xB7, 0x99, 0x87, 0xB8, 0x97, 0x5F, 0xE7, 0x7E, 0xF7, 0x1D, 0xC7, 0x3C, 0xD7,
            0xD3, 0x26, 0xF2, 0x36, 0x91, 0x06, 0xB0, 0x16, 0x57, 0x66, 0x76, 0x76, 0x15, 0x46, 0x34, 0x56,
            0x4C, 0xD9, 0x6D, 0xC9, 0x0E, 0xF9, 0x2F, 0xE9, 0xC8, 0x99, 0xE9, 0x89, 0x8A, 0xB9, 0xAB, 0xA9,
            0x44, 0x58, 0x65, 0x48, 0x06, 0x78, 0x27, 0x68, 0xC0, 0x18, 0xE1, 0x08, 0x82, 0x38, 0xA3, 0x28,
            0x7D, 0xCB, 0x5C, 0xDB, 0x3F, 0xEB, 0x1E, 0xFB, 0xF9, 0x8B, 0xD8, 0x9B, 0xBB, 0xAB, 0x9A, 0xBB,
            0x75, 0x4A, 0x54, 0x5A, 0x37, 0x6A, 0x16, 0x7A, 0xF1, 0x0A, 0xD0, 0x1A, 0xB3, 0x2A, 0x92, 0x3A,
            0x2E, 0xFD, 0x0F, 0xED, 0x6C, 0xDD, 0x4D, 0xCD, 0xAA, 0xBD, 0x8B, 0xAD, 0xE8, 0x9D, 0xC9, 0x8D,
            0x26, 0x7C, 0x07, 0x6C, 0x64, 0x5C, 0x45, 0x4C, 0xA2, 0x3C, 0x83, 0x2C, 0xE0, 0x1C, 0xC1, 0x0C,
            0x1F, 0xEF, 0x3E, 0xFF, 0x5D, 0xCF, 0x7C, 0xDF, 0x9B, 0xAF, 0xBA, 0xBF, 0xD9, 0x8F, 0xF8, 0x9F,
            0x17, 0x6E, 0x36, 0x7E, 0x55, 0x4E, 0x74, 0x5E, 0x93, 0x2E, 0xB2, 0x3E, 0xD1, 0x0E, 0xF0, 0x1E
        };

// **********************************************************  Common utility functions *********************************************

// sets the global state machine into error mode and uses the provided blink code.
void modem_panic(int code)
{
  diag("PANIC: ");
  diag(code);
  ModemState = STATE_ERROR;
  PanicCode = code;
}

// compute (bad) CRC16 CCITT to match Nabu version. This is also used to sum up the boot images!
int compute_crc16(unsigned char* target, int len)
{
  // this code is a 1:1 reproduction of the assembler version to speed up
  // the development process. It might be beneficial to optimize this...
  int running = 0xffff;
  int index, now;
  for (int i = 0; i < len; i++)
  {
    now = target[i];
    now ^= ((running >> 8) & 0xFF);
    index = now * 2;
  
    running = (running << 8) & 0xff00;
    now = CRC_Table[index];
    running |= now;
    now = CRC_Table[index + 1];
    now ^= (running >> 8);
    running = (now << 8) | (running & 0xff);
  }
  return running;
}

// appends the computed CRC value to the last two bytes in the buffer, so the validate call can check for "==0" later.
void append_crc16(unsigned char* target, int len)
{
  int sum = compute_crc16(target, len - 2);

  sum = (0xFFFF - sum) & 0xFFFF;    // store the "negative" sum for validaton later.

  target[len-2] = (sum >> 8) & 0xFF;
  target[len-1] = (sum & 0xFF);
}

// true if the checksum (at the end of the block) is valid against the expected value.
bool validate_crc16(unsigned char* target, int len)
{
  int sum = compute_crc16(target, len);
  diag("CHKSUM IN: ");
  diaghex(highByte(sum));
  diaghex(lowByte(sum));
 
  return sum == 0x1d0f; // broken CRC implementation. This **should** be zero to the best of my knowlege, but this is how the Nabu does it...
}

// will blink the requested LED for "number" times; Can be used as a status indicator.
void blink_status_confirmed(int ledPin, int number)
{
  // starting with "off" state to make sure we catch it between other status codes.
  while (number > 0)
  {
    digitalWrite(ledPin, LED_OFF);
    delay(BLINK_DELAY);
    digitalWrite(ledPin, LED_ON);
    delay(BLINK_DELAY);
    number--;
  }
  digitalWrite(ledPin, LED_OFF);
  delay(BLINK_DELAY * 2); // make sure a "longer" pause is between serialized error blinks
}



// ********************************************************  Configuration related functions ************************************************

bool wants_local_server()
{
  return (ConfigFlags & CONFIG_FLAG_USE_SD) != 0;
}

bool wants_network_server()
{
  return (ConfigFlags & CONFIG_FLAG_USE_WIFI) != 0;
}


// write current config settings to EEPROM, do NOT toggle LEDs...
// This uses the "buffer" memory for transfer; relic from when
// the code was trying to save to I2C EEPROM, keep like that
// in case an EEPROM option returns...
void save_config_noindicator()
{
  using fs::File;
  buffer[0] = CONFIGBLOCK_MAGIC_1; 
  buffer[1] = CONFIGBLOCK_MAGIC_2;
  ConfigurationInfo* info = (ConfigurationInfo*)(buffer + 2);
  memset(info, 0, sizeof(ConfigurationInfo));

  info->Version = CONFIG_VERSION;
  info->Flags = ConfigFlags;
  info->ConfigImageSize = ConfigImageSize;
  info->ActiveConfigFile = ActiveConfigFile;

  strncpy(info->SSID, SSID, 127);
  strncpy(info->NetworkKey, NetworkKey, 127);
  strncpy(info->NetworkHost, NetworkHost, 120);
  strncpy(info->NetworkUserName, NetworkUserName, 39);
  memcpy(NetworkUserToken, info->NetworkUserToken, 16);
  strncpy(info->ConfigImageVersion, ConfigImageVersion, 31);

  append_crc16(buffer, CONFIGFILESIZE); // add a checksum...

  File f = SPIFFS.open(CONFIGFILENAME, "w");
  if (f)
  {
    f.write(buffer, CONFIGFILESIZE);
    f.close();
  }
}

// try to read the EEPROM content and see if we have any old data. 
// Initialize WiFi and other parameters accordingly if we haven't.
void load_or_init_config()
{
  using fs::File;
  digitalWrite(PIN_LED_IO, LED_ON);

  bool fsAvailable = false;

  FSInfo fs_info;
  if(!SPIFFS.info(fs_info))
  {
    // Virgin chips usually don't have that section formatted, so here we go!
    diag("info failed, trying format...");
    if (!SPIFFS.format())
    {
      diag("ERROR: SPIFFS format failed!\n");
    }
    else
    {
      if(SPIFFS.info(fs_info))
      {
        fsAvailable = true;
      }
    }
  }
  else
  {
    diag("SPIFFS OK: ");
    diag(fs_info.usedBytes);
    diag("\n");
    fsAvailable = true;
  }

  memset(buffer,0,CONFIGFILESIZE);

  if (fsAvailable)
  {
    diag("fs avl\n");
    if (SPIFFS.exists(CONFIGFILENAME))
    {
      diag("config file avl\n");
      File f = SPIFFS.open(CONFIGFILENAME, "r");
      if (!f)
      {
        diag("File open error");
      }
      else
      {
        diag("config file open\n");
        if (f.readBytes((char*)buffer, CONFIGFILESIZE) != CONFIGFILESIZE)
        {
          diag("config file too small\n");
          buffer[0]=0;
        }
        f.close();
      }
    }
  }

  ActiveConfigFile = 0;
  ChannelCode = 0;
  ConfigFlags = 0;
  ConfigImageSize = 0;
  ForceChannelQuery = false;
  
  memset(SSID,0,33);
  memset(NetworkKey,0,65);
  memset(NetworkHost,0,121);
  memset(NetworkUserName,0,40);
  memset(NetworkUserToken,0,16);
  memset(ConfigImageVersion, 0, 32);

  bool configValid = false;

  if (buffer[0]==CONFIGBLOCK_MAGIC_1 && buffer[1] == CONFIGBLOCK_MAGIC_2 && validate_crc16(buffer, CONFIGFILESIZE))
  {
    ConfigurationInfo* info = (ConfigurationInfo*)(buffer + 2);

    switch (info->Version)
    {
      case CONFIG_VERSION:  // most recent version...
        ConfigFlags = info->Flags;
        ChannelCode = info->ChannelCode;
        ConfigImageSize = info->ConfigImageSize;
        ActiveConfigFile = info->ActiveConfigFile;
        
        strncpy(SSID, info->SSID, 32);
        strncpy(NetworkKey, info->NetworkKey, 64);
        strncpy(NetworkHost, info->NetworkHost, 120);
        strncpy(NetworkUserName, info->NetworkUserName, 39);
        memcpy(NetworkUserToken, info->NetworkUserToken, 16);
        strncpy(ConfigImageVersion, info->ConfigImageVersion, 31);
       
        configValid = true;
        break;
    }
    
#ifdef SERIALDIAG
    diag("EEPROM valid, version:\t");
    diag(info->Version);
    diag("\t valid: ");
    diag(configValid ? "yes" : "no");
    diag("\n");
#endif    
  }

  if (!configValid)
  {
    diag("\nEEPROM config invalid, resetting...\n");
    digitalWrite(PIN_LED_ERR, LED_ON);
    strncpy(NetworkHost, DEFAULT_SERVER_URL, 120);
    
    save_config_noindicator();

    delay(250); // make sure we see that...
    digitalWrite(PIN_LED_ERR, LED_OFF);
  }
  digitalWrite(PIN_LED_IO, LED_OFF);
}

bool read_block_from_config_image(int number, int* readByteCount, unsigned char * buffer)
{
  digitalWrite(PIN_LED_IO, LED_ON);
  const char* imageFile = ActiveConfigFile == 1 ? IMAGEFILE_1 : IMAGEFILE_2;

  *readByteCount = 0;

  fs::File f = SPIFFS.open(imageFile, "r");
  if(f)
  {
    int offset = number * 256;

    if (offset >= ConfigImageSize)
    {
      digitalWrite(PIN_LED_ERR, LED_ON);
      digitalWrite(PIN_LED_IO, LED_OFF);
      
      return true;
    }

    int len = offset + 256 <= ConfigImageSize ? 256 : ConfigImageSize - offset;

    f.seek(offset);
    
    bool endOfFile = len + offset >= ConfigImageSize;

    int r = 0;
    while (r < len)
    {
      int r1=f.read(buffer + r, len - r);
      if (r1 == 0)
      {
        digitalWrite(PIN_LED_ERR, LED_ON);
        digitalWrite(PIN_LED_IO, LED_OFF);
        return true;
      }
      r+=r1;
    }

    *readByteCount = r;
    digitalWrite(PIN_LED_IO, LED_OFF);
    return endOfFile;
  }
  digitalWrite(PIN_LED_ERR, LED_ON);
  digitalWrite(PIN_LED_IO, LED_OFF);
  return true;
}




// ********************************************************  HCCA related functions ************************************************

// Resets the modem state to a known startup value.
void reset_hcca_state()
{
  HCCAState = HCCA_STATE_BOOT;
  LastHCCAByte = -1;
  LastHCCAInput = millis();     // some state changes might be timing related, so remember when the last input happened.
  HCCAResetSequenceCount = 0;
  HCCARxStart = HCCARxEnd = HCCATxStart = HCCATxEnd = 0;

  NabuNetState = NN_STATE_UNKNOWN;
  nn_incoming = false;
}

void clear_hcca_receive()
{
  HCCARxStart = HCCARxEnd = 0;
}

void clear_hcca_send()
{
  HCCATxStart = HCCATxEnd = 0;
}

bool push_hcca_received(byte what)
{
  int bufEnd = (HCCARxEnd + 1) % HCCA_BUFFER_SIZE;
  if (bufEnd == HCCARxStart)  // overflow!
    return false;

  HCCAReceiveBuffer[HCCARxEnd] = what;
  HCCARxEnd = bufEnd;
  return true;
}

bool hcca_send(byte what)
{
  int bufEnd = (HCCATxEnd + 1) % HCCA_BUFFER_SIZE;
  if (bufEnd == HCCATxStart)  // overflow!
    return false;

  HCCASendBuffer[HCCATxEnd] = what;
  HCCATxEnd = bufEnd;
  return true;
}

bool hcca_flush()
{
  while (HCCATxStart != HCCATxEnd)
  {
    delay(1);  // tune...
  #ifndef DISABLE_HCCA
    Serial.write(HCCASendBuffer[HCCATxStart]);
  #else
    Serial.print(HCCASendBuffer[HCCATxStart], HEX);
  #endif
    HCCATxStart = (HCCATxStart + 1) % HCCA_BUFFER_SIZE;
  }
  return true;  
}

int hcca_receive()
{
  if (HCCARxStart == HCCARxEnd)
    return -1;
  int value = HCCAReceiveBuffer[HCCARxStart];
  HCCARxStart = (HCCARxStart + 1) % HCCA_BUFFER_SIZE;
  return value;
}

int hcca_received_length()
{
  if (HCCARxStart == HCCARxEnd)
    return 0;
  if (HCCARxEnd > HCCARxStart)
    return HCCARxEnd - HCCARxStart;
  return (HCCA_BUFFER_SIZE + HCCARxEnd) - HCCARxStart;
}

// diagnostics helper: bliks the number in the byte with IO/NET LEDs, i.e. 0x5F will blink IO 5 times, NET 15 times.
void blink_byte(byte n)
{
    blink_status_confirmed(PIN_LED_IO, (n >> 4) & 0xF);
    blink_status_confirmed(PIN_LED_NET, n & 0xF);
}

bool NabuNetSend(byte code, bool isReply, byte* bufferAddress, int bufferLength)
{
  if (code > 0xf)
    return false;
  if (isReply)
    code |= 0x40;
  if (bufferAddress != NULL && bufferLength != 0)
  {
    if (bufferLength < 0 || bufferLength > 128)
      return false;
    code |= 0x80;
  }
  int checksum = code;
  if (!hcca_send(code))
    return false;
  if (bufferLength > 0 && bufferAddress != NULL)
  {
    code = bufferLength;
    checksum+=code;
    if (!hcca_send(code))
      return false;
    for (int i = 0; i < bufferLength; i++)
    {
      if (!hcca_send(bufferAddress[i]))
        return false;
      checksum+=bufferAddress[i];
    }
  }
  
  if (!hcca_send(0xFF - (checksum & 0xFF)))
    return false;
    
  return true;
}

void ResetNabuNetNow()
{
  nn_incoming = false;
  nn_started = 0;
  NabuNetState = NN_STATE_UNKNOWN;
}

void SetNabuNetError()
{
  nn_incoming = false;
  nn_started = 0;
  NabuNetState = NN_STATE_ERROR;
  digitalWrite(PIN_LED_ERR, LED_ON);
  digitalWrite(PIN_LED_IO, LED_OFF);
}

char nn_reportedConfigProgramVersion[33];

bool wifi_ScanRunning = false;
int wifi_scan_current_page = -1;
int wifi_scan_page_size = 8;

byte TranslateCurrentWiFiStatus()
{
  switch(WiFi.status())
  {
    case WL_IDLE_STATUS:
    case WL_NO_SSID_AVAIL:
    case WL_DISCONNECTED:
      return 0;
    case WL_CONNECTED:
      return 1;
    case WL_CONNECT_FAILED:
      return 2;
    case WL_WRONG_PASSWORD:
      return 3;
  }
  return 0xFF;
}

byte TranslateWiFiEncryption(uint8_t type)
{
  switch (type)
  {
    case ENC_TYPE_NONE:
      return 0;
    case ENC_TYPE_WEP:
    case ENC_TYPE_TKIP:
    case ENC_TYPE_CCMP:
    case ENC_TYPE_AUTO:
      return 1;
  }
  return 2;
}

byte TranslateStrength(int dbm)
{
  if (dbm <= -100)
    return 0;
  if (dbm >= -50)
    return 100;
  return 2 * (dbm + 100); // 0..100
}

bool HandleModemConfigCommand(bool isReply, byte* payload, int payloadLength)
{
  if (!isReply && payloadLength >= 1)
  {
    switch(payload[0])
    {
      case 0x00:  // query modem config.
        // payload should have an ASCII string with "payloadlength-1" characters for the modem version string.
        // this should be the same as the one in the active boot image for validation. 
        // If successful, we reply with our MAC address and own version number...
        if (payloadLength > 1 && payloadLength <=33)
        {
          memset(nn_reportedConfigProgramVersion, 0, 33);
          memcpy(nn_reportedConfigProgramVersion, payload+1, payloadLength-1);  

          if(strcmp(nn_reportedConfigProgramVersion, ConfigImageVersion)!= 0)
          {
            SetNabuNetError();
            buffer[0] = 0;
            return NabuNetSend(0xF, true, buffer, 1);
          }

          // and now, send our own info...
          WiFi.macAddress(buffer + 100);
          buffer[0] = 0;
          sprintf((char*)buffer+1, "%02X%02X%02X%02X%02X%02X", buffer[100], buffer[101], buffer[102], buffer[103], buffer[104], buffer[105]);
          strcpy((char*)buffer+13, NABUNET_MODEM_FIRMWARE_VERSION);
          
          return NabuNetSend(0xF, true, buffer, strlen(((const char*)buffer)+1)+1);
        }
        buffer[0] = 0;
        return NabuNetSend(0xF, true, buffer, 1);
      case 0x01:  // query WiFi status
        // we want: 
        //   WiFi enabled in cofig ?
        //   WiFi SSID configured  ?
        //   WiFi Key configured   ?
        //   WiFi status: off/connecting/connected
        //      if connected: signal strength
        //                    IP Address

        buffer[0] = (ConfigFlags & CONFIG_FLAG_USE_WIFI) != 0 ? 1 : 0;
        buffer[1] = (SSID[0] != 0) ? 1 : 0;
        buffer[2] = (NetworkKey[0] != 0) ? 1 : 0;
        buffer[3] = TranslateCurrentWiFiStatus();
        if (buffer[3]==1)
        {
          buffer[4] = TranslateStrength(WiFi.RSSI());
        }
        else
        {
          buffer[4] = 0;
        }
        return NabuNetSend(0xF, true, buffer, 5);
      case 0x02: // start WiFi scan
        if (WiFi.getMode() ==WIFI_OFF)
        {
          if (!WiFi.mode(WIFI_STA))
          {
            buffer[0] = 0xFF;
            return NabuNetSend(0xF, true, buffer, 1);
          }
        }

        if (wifi_ScanRunning)
        {
          buffer[0] = 0;
          return NabuNetSend(0xF, true, buffer, 1);
        }

        WiFi.scanDelete();  // clear out old results if any...
        wifi_scan_current_page = -1;
        wifi_scan_page_size = (payloadLength > 1) ? payload[1] : 8;
        
        wifi_ScanRunning = WiFi.scanNetworks(true, true) == WIFI_SCAN_RUNNING;
        buffer[0] = wifi_ScanRunning ? 0 : 1;
        return NabuNetSend(0xF, true, buffer, 1);
      case 0x03: // SSID Scan complete?
        if (wifi_ScanRunning)
        {
          if (WiFi.scanComplete() >= 0)
          {
            wifi_ScanRunning = false;
            wifi_scan_current_page = 0;
            buffer[0] = 1;  // scan is DONE.
          }
          else
            buffer[0] = 2;  // scan is RUNNING.
        }
        else
          buffer[0] = WiFi.scanComplete() >= 0 ? 1 : 0; // done or not started.
        return NabuNetSend(0xF, true, buffer, 1);
      case 0x04: // Get Current SSID page info. We "page"; this way, we can have "no knowledge" of current page number and have any number of networks and we can transfer one entry at a time.
        {
          int n = WiFi.scanComplete();
          if (n>=0 && wifi_scan_page_size > 0)
          {
            int numPages = ((n-1) / wifi_scan_page_size) + 1; // 8 entries at 8 per page => 1, 9 entries -> 2
            buffer[0] = (wifi_scan_current_page > 0) ? 1 : 0; // can go back...
            buffer[1] = (wifi_scan_current_page + 1 < numPages) ? 1 : 0; // can go forward...
            buffer[2] = buffer[1] == 1 ? wifi_scan_page_size : wifi_scan_page_size - (n % wifi_scan_page_size);
            return NabuNetSend(0xF, true, buffer, 3);
          }
          buffer[0] = 0;
          buffer[1] = 0;
          buffer[2] = 0;
          return NabuNetSend(0xF, true, buffer, 3);
        }
      case 0x05: // move page...
      {
        int n = WiFi.scanComplete();
        if (n>=0 && wifi_scan_page_size > 0)
        {
          int numPages = ((n-1) / wifi_scan_page_size) + 1; // 8 entries at 8 per page => 1, 9 entries -> 2
          switch (payloadLength > 1 ? payload[1] : 0)
          {
             case 1:
              // move forward after read...
              if (wifi_scan_current_page + 1 < numPages)
                wifi_scan_current_page++;
              break;
            case 2:
              if (wifi_scan_current_page > 0)
                wifi_scan_current_page--;
              break;
            case 3:
              wifi_scan_current_page = numPages-1;
              break;
            case 4:
              wifi_scan_current_page = 0;
              break;
          }
          buffer[0] = (wifi_scan_current_page > 0) ? 1 : 0; // can go back...
          buffer[1] = (wifi_scan_current_page + 1 < numPages) ? 1 : 0; // can go forward...
          buffer[2] = buffer[1] == 1 ? wifi_scan_page_size : wifi_scan_page_size - (n % wifi_scan_page_size);
          return NabuNetSend(0xF, true, buffer, 3);
        }
        buffer[0] = 0;
        buffer[1] = 0;
        buffer[2] = 0;
        return NabuNetSend(0xF, true, buffer, 3);
      }
      case 0x06: // Get SSID entry info. current page, entry "n"...
      {
        int n = WiFi.scanComplete();
        int o = payloadLength > 1 ? payload[1] : 0;
        if (n>=0 && wifi_scan_page_size > 0 && o < wifi_scan_page_size)
        {
          o = wifi_scan_current_page * wifi_scan_page_size + o;
          if (o < n)
          {
            buffer[0] = TranslateWiFiEncryption(WiFi.encryptionType(o));
            buffer[1] = TranslateStrength(WiFi.RSSI(o));
            buffer[34] = 0; // catch too long SSID.
            strncpy(((char*)buffer+2), WiFi.SSID(o).c_str(), 32);
            return NabuNetSend(0xF, true, buffer, 2 + strlen((const char*)buffer+2));
          }
        }
        buffer[0]=0;
        buffer[1]=0;
        return NabuNetSend(0xF, true, buffer, 2);
      }
    }
  }
  return true;
}

// we got regular Nabu Net communication happening.
// currently, this is called pretty deeply nested;
// might be worth "unwinding" that into some less deep stack...
bool handle_nabunet_communication()
{
  int readByte = hcca_receive();
  if (readByte >= 0)
  {
    //blink_byte(readByte);
    if (nn_incoming)  // we are receiving a package!  
    {
      nn_checksum += readByte;
      if (nn_hasPayload)
      {
        if (nn_payloadLength < 0)  // we just got the payload length...
        {
          nn_payloadLength = readByte;
          nn_payloadOffset = 0;
        }
        else
        {
          if (nn_payloadOffset >= nn_payloadLength)
          {
            // we got the checksum now...
            nn_rxDone = true;
          }
          else
          {
            nn_rx_payload[nn_payloadOffset] = readByte;
            nn_payloadOffset++;
          }
        }
      }
      else
      {
        // no payload, this has to be the checksum already...
        nn_rxDone = true;
      }
    }
    else
    {
      digitalWrite(PIN_LED_IO, LED_ON); 
      nn_started = millis();
      nn_incoming = true;
      nn_payloadLength = -1;
      nn_checksum = readByte;
      nn_rxDone = false;
      // independently of status, the byte should be a header...
      // parse it as such...
      nn_code = (readByte & 0xF);
      nn_isReply = (readByte & 0x40) != 0;
      nn_hasPayload = (readByte & 0x80) != 0;
    }
    // read the rest of the packet with a timeout...
    if (nn_rxDone)
    {
      digitalWrite(PIN_LED_IO, LED_OFF);
      nn_rxDone = false;
      nn_incoming = false;
      nn_started = 0;
      if ((nn_checksum & 0xFF) != 0xFF)
      {
        SetNabuNetError();
        blink_byte(0x22);
      }
      else
      {
        switch(NabuNetState)
        {
          case NN_STATE_CONNECTED:
            // this took way too long... but: now we have received a proper sync'd protocol message!
            switch (nn_code)
            {
              case 0:
                // uh-oh... resync request; drop all and run!
                if (nn_hasPayload && !nn_isReply && nn_payloadLength==1)
                {
                  NabuNetState = NN_STATE_CONNECTING;
                  nn_connectInitiated = false;
                  nn_connectToken = nn_rx_payload[0];
                  NabuNetSend(0x00, true, nn_rx_payload, 1);
                } // ignore any others...
                break;
              case 1:
                // User data io operations... TODO
                break;
              case 2:
                // User stream/io operations... TODO
                break;
              case 0xE:
                break;
              case 0xF:
                if (IsServicingMode)
                {
                  return HandleModemConfigCommand(nn_isReply, nn_rx_payload, nn_hasPayload ? nn_payloadLength : 0);
                }// non-servicing mode drops through to "unknown protocol code" by design!
              default:
                SetNabuNetError();
                break;
            }
            break;
          case NN_STATE_CONNECTING:
            // we ignore anything, except a proper SYNC packet...
            if (nn_hasPayload && nn_code == 0 && nn_payloadLength == 1)
            {
              // if the received packet is a valid reply to our request, we lock on.
              if (nn_isReply && nn_rx_payload[0] == nn_connectToken)
              {
                // CHECK! if we originated the request, send 3rd message.
                if (nn_connectInitiated)
                {
                  NabuNetSend(0x00, true, nn_rx_payload, 1);
                }
                NabuNetState = NN_STATE_CONNECTED;
                digitalWrite(PIN_LED_ERR, LED_OFF);
              }
              else
              {
                SetNabuNetError();
                blink_byte(nn_rx_payload[0]);
                // we got a reply, but it's not ours...
                NabuNetState = NN_STATE_UNKNOWN;
              }
            }
            break;
          case NN_STATE_UNKNOWN:
          case NN_STATE_ERROR:
            // we ignore anything, except a proper formed SYNC request...
            if (nn_hasPayload && !nn_isReply && nn_code == 0 && nn_payloadLength == 1)
            {
              NabuNetState = NN_STATE_CONNECTING;
              nn_connectToken = nn_rx_payload[0];
              nn_connectInitiated = false;
              NabuNetSend(0x00, true, nn_rx_payload, 1);  // send reply...
            }
/*            else
              if (nn_started == 0)  // track timeout for our own reconnect...
                nn_started = millis();*/
            break;
          default:
            SetNabuNetError();
            break;
        }
      }
    }
  }
  else
  {
    if (nn_incoming)  // we are receiving a package! count timeout!
    {
      unsigned long delta = millis() - nn_started;
      if (delta > 500)  // half a second for "complete message" is MORE than enough...
      {
        SetNabuNetError();
      }
    }
    else
    {
      if (NabuNetState == NN_STATE_UNKNOWN || NabuNetState == NN_STATE_ERROR)
      {
        if (nn_started == 0)
          nn_started = millis();
        else
        {
          unsigned long delta = millis() - nn_started;
          if (delta > 2500)
          {
            nn_connectInitiated = true;
            nn_connectToken = (nn_connectToken +1) & 0xFF;
            if (nn_connectToken == 0)
              nn_connectToken = 1;
            nn_rx_payload[0]=nn_connectToken;
            NabuNetSend(0x00, false, nn_rx_payload, 1);
            NabuNetState = NN_STATE_CONNECTING;
            nn_started = 0;
          }
        }
      }
    }
  }
  return true;
}

// react to incoming bytes from NABU, based on current HCCA state...
bool handle_hcca_buffer()
{
  int readByte ;
  switch (HCCAState)
  {
    case HCCA_STATE_BOOT:
      if (LastHCCAByte == 0x83)
      {
        // we got the init sequence;
        clear_hcca_send();
        hcca_send(0x10);
        hcca_send(0x06);
        hcca_send(0xe4);
        clear_hcca_receive(); // need to make sure we start over for the next byte in the sequence...
        if (!hcca_flush())
          return false;
        HCCAState = HCCA_STATE_INIT_1;
      }
      else
        clear_hcca_receive(); // in "boot" state, we just ignore everything else to avoid buffer overflows.
      break;
    case HCCA_STATE_INIT_1:
      // wait for command code 0x82... ignore anything else...
      readByte = hcca_receive();
      if (readByte == 0x82)
      {
        clear_hcca_send();
        hcca_send(0x10);
        hcca_send(0x06);
        if (!hcca_flush())
          return false;
        HCCAState = HCCA_STATE_INIT_2;
      }
      else
        if(readByte != -1)
          HCCAState = HCCA_STATE_BOOT;
      break;
    case HCCA_STATE_INIT_2:
      // wait for command code 0x01... ignore anything else...
      readByte = hcca_receive();
      if (readByte == 0x01)
      {
        clear_hcca_send();
        // now we get dynamic...
        if (!IsServicingMode && ForceChannelQuery)  // we need no prompt in servicing mode, this will be "0000" channel anyway...
          hcca_send(0x80);
        else
          hcca_send(0x00);
        
        hcca_send(0x10);
        hcca_send(0xe1);
        if (!hcca_flush())
          return false;
        HCCAState =  ForceChannelQuery ? HCCA_STATE_WAIT_FOR_CODE : HCCA_STATE_WAIT_FOR_BOOT;
      }
      else
        if(readByte != -1)
          HCCAState = HCCA_STATE_BOOT;
      break;
    case HCCA_STATE_WAIT_FOR_CODE:
      readByte = hcca_receive();
      if (readByte == 0x85)
      {
        hcca_send(0x10);
        hcca_send(0x06);
        if (!hcca_flush())
          return false;
        HCCAState = HCCA_STATE_RECEIVE_CODE;
      }
      else
        if (readByte != -1)
        {
          // stay here...
        }
      break;
    case HCCA_STATE_RECEIVE_CODE:
      if (hcca_received_length() >= 2)
      {
        ChannelCode = hcca_receive() << 8;
        ChannelCode |= hcca_receive();
        bool codeIsValid = false;
        if (ChannelCode != 0)
        {
          // TODO: validate channel code against current server...
        }
        else
          codeIsValid = (ConfigFlags & CONFIG_FLAG_HAS_IMAGE) != 0;
        if (codeIsValid)
        {
          hcca_send(0xE4);  // send confirmation...
          HCCAState = HCCA_STATE_WAIT_FOR_BOOT;
        }
        else
        {
          hcca_send(0xFF);  // send failed...
          HCCAState = HCCA_STATE_BOOT;
        }
        if (!hcca_flush())
          return false;
      }
      break;
    case HCCA_STATE_WAIT_FOR_BOOT:
      readByte = hcca_receive();
      if (readByte == 0x81)
      {
        hcca_send(0x10);
        hcca_send(0x06);
        if (!hcca_flush())
          return false;
        HCCAState = HCCA_STATE_BOOT_REQUESTED;
      }
      break;
    case HCCA_STATE_BOOT_REQUESTED:
      readByte = hcca_receive();
      if (readByte == 0x8F)
      {
        HCCAState = HCCA_STATE_BOOT_RUNNING;
      }
      else
      {
        if (readByte >=0)
        {
          HCCAState = HCCA_STATE_WAIT_FOR_BOOT;
        }
      }
      // NABU does ROM->RAM copy now and shows "PLEASE WAIT" before continuing;
      break;
    case HCCA_STATE_BOOT_RUNNING:
      readByte = hcca_receive();
      if (readByte == 5)
      {
        hcca_send(0xE4);
        HCCAState = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;
        // This should now tritter the "please wait" message on the NABU...
      }
      else
      {
        if (readByte != -1)
        {
          hcca_send(0x06);  // NOT E4, should cause error.
          HCCAState = HCCA_STATE_WAIT_FOR_BOOT;
        }
      }
      if (!hcca_flush())
        return false;
      break;
    case HCCA_STATE_WAIT_FOR_BLOCK_REQUEST:
      // this is the command to load a block by a number; 
      // likely 0x00 00 01 ?? for the main program,
      // where ?? is incremented from 0 efter every "not last" block.
      readByte = hcca_receive();
      if (readByte == 0x84)
      {
        hcca_send(0x10);
        hcca_send(0x06);
        HCCAState = HCCA_STATE_WAIT_FOR_BLOCK_NUM;
      }
      else
      {
        if (readByte != -1)
        {
          hcca_send(0x00);
          HCCAState = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;  // try to re-sync...
        }
      }
      if (!hcca_flush())
        return false;
      break;
    case HCCA_STATE_WAIT_FOR_BLOCK_NUM:
      if (hcca_received_length() >= 4)    // get 4 bytes, first is block number (0..n) second-fourth unknown, but 1-0-0 now.
      {
        readByte = hcca_receive();
        HCCARequestedBlockNum = readByte;
        hcca_receive();
        hcca_receive();
        hcca_receive();
        hcca_send(0xE4);
        if (!hcca_flush())
          return false;
        HCCAState = HCCA_STATE_SEND_BLOCK;
      }
      break;
    case HCCA_STATE_SEND_BLOCK:
      int readByteCount;
      bool isLastBlock;

      memset(buffer, 0, 0x10);  // clear "header"..

      if (IsServicingMode) // in servising mode, we force to the boot channel...
      {
        isLastBlock = read_block_from_config_image(HCCARequestedBlockNum, &readByteCount, buffer + 0x10);
      }
      else 
        return false;  // TODO

      buffer[0xb] = isLastBlock ? 0x10 : 0; // set "last block" flag...

      append_crc16(buffer, readByteCount + 0x12);

      // we done loading the block! Send other code on load fail here!
      // if the 91 code takes too long (about 5 seconds) the load is aborted
      // and the "see "if something goes wrong" in the owners guide"
      // message is shown.
      hcca_send(0x91);

      if (!hcca_flush())
        return false;

      HCCASendBlockSize = readByteCount + 0x12;
      HCCAIsLastBlock = isLastBlock;

      HCCAState = HCCA_STATE_SEND_BLOCK_GO;
      break;
    case HCCA_STATE_SEND_BLOCK_GO:
      if (hcca_received_length() >= 2)
      {
        readByte = hcca_receive();
        if (readByte != 0x10)
        {
          HCCAState = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;
          break;
        }
        readByte = hcca_receive();
        if (readByte != 0x6)
        {
          HCCAState = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;
          break;
        }
       
        for(int i = 0; i < HCCASendBlockSize; i++)
        {
          hcca_send(buffer[i]);
          
          if (buffer[i] == 0x10)  // escape 0x10...
            hcca_send(0x10);
        }
        hcca_send(0x10);
        hcca_send(0xe1);
  
        if (!hcca_flush())
          return false;
        HCCAState = HCCAIsLastBlock ? HCCA_STATE_RUN : HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;
      }
      break;
    case HCCA_STATE_RUN:
      // We got the Nabu PC with a proper control program now, anything should happen within this section now.
      // TODO: handle actual requests... might need reworking when we have info about the old NABU protocol...
      if (handle_nabunet_communication())
        return hcca_flush();
  }
  return true;
}

/*
void test_blocksend_code()
{
  int readByteCount;
  memset(buffer, 0, 0x10);  // clear "header"..
  bool isLastBlock = read_block_from_config_image(0, &readByteCount, buffer + 0x10);
  buffer[0xb] = isLastBlock ? 0x10 : 0; // set "last block" flag...
  append_crc16(buffer, readByteCount + 0x12);
  for (int i=0;i<readByteCount+0x12;i++)
  {
    diaghex(buffer[i]);
  }
}
*/

// check to see if anything was sent FROM the Nabu, if so, put it into the receive buffer and check for the reset sequence;
bool handle_hcca_incoming()
{
  if(Serial.available())  // NABU should be slow enough to enable a byte-by-byte receive loop...
  {
  #ifndef DISABLE_HCCA
    int byteInput = Serial.read();
  #else
    int byteInput = Serial.read();
  #endif
    int now = millis();
    if (byteInput == 0x83)
    {
      diag("x");
      // maybe?
      if (LastHCCAByte == 0x83 && (now - LastHCCAInput > 250))
      {
        HCCAResetSequenceCount++;
        if (HCCAResetSequenceCount > 2)
        {
          diag("RESET!");
          // Gotcha!
          HCCAState = HCCA_STATE_BOOT;
          ResetNabuNetNow();
          return true;
        }
      }
      else
        HCCAResetSequenceCount = 0;
    }
    // write byte to input buffer anyhow...
    LastHCCAInput = now;
    LastHCCAByte = byteInput;

    if (!push_hcca_received(byteInput))
      return false;
  }
  return handle_hcca_buffer();
}

// check for pending HCCA communication, handle state machine and distribute commands/replies. Return false on fatal error.
bool handle_hcca_request()
{
  if (!handle_hcca_incoming())  // take care of all (known) NABU commands for the boot process...
    return false;

  return true;
}



// ******************************************************* Config Image related functions *****************************************


// wait for 3 seconds and see if the "reset" button get's pressed again, blinking the status LEDs...
bool confirm_install_setup_image()
{

  int count = 0;
  while (count < (5000 / BLINK_DELAY) && digitalRead(PIN_SIGNAL) == HIGH)
  {
    digitalWrite(PIN_LED_NET, ((count % 2)==0) ? LED_ON : LED_OFF);
    digitalWrite(PIN_LED_ERR, ((count % 2)==0) ? LED_ON : LED_OFF);
    delay(BLINK_DELAY);
    count++;
  }

  while (digitalRead(PIN_SIGNAL) == HIGH)
    delay(1); // wait for release again...

  digitalWrite(PIN_LED_NET, LED_OFF);
  digitalWrite(PIN_LED_ERR, LED_OFF);
  return count > 0; // we confirmed!
}

// Waits until the reset button is released; if longer than 5 seconds, we assume a stuck button.
// return true if the button was initially pressed and released within that timeout;
bool wait_signal_released()
{
  // waits for the reset button to be released, signalling "OK" all the way...

  if(digitalRead(PIN_SIGNAL) == LOW)
  {
    // yes, we might...
    int count = 0;
    while (count < (5000 / BLINK_DELAY) && digitalRead(PIN_SIGNAL) == LOW)
    {
      digitalWrite(PIN_LED_NET, ((count % 2)==0) ? LED_ON : LED_OFF);
      digitalWrite(PIN_LED_ERR, ((count % 2)!=0) ? LED_ON : LED_OFF);
      delay(BLINK_DELAY);
      count++;
    }
    digitalWrite(PIN_LED_NET, LED_OFF);
    digitalWrite(PIN_LED_ERR, LED_OFF);
    if (count < (5000 / BLINK_DELAY))
    {
      // we got a valid reset request. Assume stuck key otherwise and continue normal.
      return true;
    }
  }

  return false; // we snapped to error mode...
}

// Check if we have a firmware update on the SD card; false if not.
bool check_setup_image_on_card()
{
  if(!SDCardDetected)
    return false;

  bool result = false;

  diag("Scanning SD for image");
  diag(BootImageFileName);

  digitalWrite(PIN_LED_IO, LED_ON);

  char nameBuffer[14];
  nameBuffer[13]=0;

  

  File32 entry = sd.open(BootImageFileName);
  if (!entry)
  {
    digitalWrite(PIN_LED_IO, LED_OFF);
    return false;
  }
  if (entry.size() > 10 && entry.size() < IMAGESIZELIMIT)  // sanity check and size limit check...
    result = true;
  else
    diag("\n\nConfig image on SD is invlaid sized.!\n");

  digitalWrite(PIN_LED_IO, LED_OFF);

  if (result)
    diag("\n\nFound config image on SD!\n");
  
  return result;
}

// Loads the provided image file from SD and places it into the SPIFFS store, marking it as configured if successful.
void replace_setup_image_from_card()
{
  digitalWrite(PIN_LED_IO, LED_ON);
  // 1.: read the boot image into the EEPROM

  bool imageLoaded = false;
  int imageSize = 0;
  int versionOffset = 0;
  int idx = 0;

  int newImage = ActiveConfigFile == 1 ? 2 : 1; // switch from one to two or back...
  const char* newImageName = newImage == 1 ? IMAGEFILE_1 : IMAGEFILE_2;

  File32 fInput = sd.open(BootImageFileName);
  fs::File f;
  if (fInput && fInput.size()>=6 && fInput.size() < IMAGESIZELIMIT)
  {
    f = SPIFFS.open(newImageName, "w");
    if (f)
    {
      diag("\nfile open: ");
      diag(newImageName);
      int len = 0;
      while(len<fInput.size())
      {
        int r = fInput.read(buffer, BUFFER_SIZE);
        if (r == 0)
          break;
        f.write(buffer, r);
        len+=r;
      }
      diag("\n read bytes: ");
      diag(len);
      imageSize = len;
      f.close();
      fInput.close();
      imageLoaded = true;
    }
  }
  if (imageLoaded)
  {
    // 2.: load version info back from EEPROM
    idx = 0;
    memset(buffer, 0, 33);

    diag("\n reading back image: ");

    f = SPIFFS.open(newImageName, "r");
    if(f)
    {
      idx = f.read();
      idx |= f.read() << 8;
  
      idx-=0x140D;    // remove absolute boot offset...
  
      if (idx > 0 && idx < imageSize-2)
        versionOffset = idx;
  
      // 3.: update setup info in config
      if(versionOffset > 0)
      {
        diag("\n reading version: ");
  
        f.seek(versionOffset);
        int r = f.read(buffer, 32);
        diag("\n read bytes: ");
        diag(r);
        if (r <= 0) // bail out if we can't read the version string...
        {
          imageLoaded = false;
        }
      }
      else
        imageLoaded = false;
      f.close();
    }
  }

  if (imageLoaded)
  {
    diag("\n loaded, updating config...");
    strncpy(ConfigImageVersion, (const char*)buffer, 31);
    ConfigImageSize = imageSize;
    ActiveConfigFile = newImage;
    ConfigFlags |= CONFIG_FLAG_HAS_IMAGE;

    // 4.: save config to EEPROM
    save_config_noindicator();
  }

  digitalWrite(PIN_LED_ERR, imageLoaded ? LED_OFF : LED_ON);

  digitalWrite(PIN_LED_IO, LED_OFF);

  blink_status_confirmed(PIN_LED_IO, 3);
}

// **************************************************** Local SD card based server **********************************************

bool check_and_initilize_local_server()
{
  return false;
}


// *************************************************** WiFi server connection **************************************************

bool check_and_initilize_wifi() 
{
  return false;
}


// ****************************************************  Setup and state machine code *******************************************

void setup() 
{

#ifdef SERIALDIAG
  // initial serial for diag com output.
  Serial.begin(115200, SERIAL_8N1);

  diag("\n\nDIAG_START\n");
#else

  // initialize serial for Nabu com.
  Serial.begin(111860, SERIAL_8N1);
#endif

  pinMode(PIN_LED_ERR, OUTPUT);
  pinMode(PIN_LED_NET, OUTPUT);
  pinMode(PIN_LED_IO, OUTPUT);
  pinMode(PIN_FIVEV_ENABLE, OUTPUT);
  
  pinMode(PIN_SIGNAL, INPUT);

  digitalWrite(PIN_LED_ERR, LED_OFF);
  digitalWrite(PIN_LED_NET, LED_OFF);
  digitalWrite(PIN_LED_IO, LED_OFF);

  // enable the 5V side of the modem via the level shifter.
#ifndef SERIALDIAG
  digitalWrite(PIN_FIVEV_ENABLE, HIGH); 
#endif

  SPIFFS.begin();

  int retry = 0;
  while (retry < 10)
  {
    SDCardDetected = sd.begin(PIN_SD_CS);
    if(!SDCardDetected)
    {
      diag(".");
      delay(10);
    }
    else
      break;
    retry++;
  }
  if (SDCardDetected)
  {
    diag("SD Detected: ");
    diaghex(sd.fatType());
    diaghex(sd.card()->type());
    diag("\n");
    SDCardDetected = sd.fatType() != 0; // supported FS?
  }

  reset_hcca_state();

  LocalServerAvailbale = false;
  ForceChannelQuery = false;
  WiFiAvailable = false;
  IsServicingMode = false;

  PanicCode = 0;

  NabuNetState = NN_STATE_UNKNOWN;
  
  ModemState = STATE_BOOT; // delegate some more heavy lifting into the loop method, just because.

  nn_reportedConfigProgramVersion[0]=0;
}

void loop() 
{
  switch (ModemState)
  {
    case STATE_BOOT:
      diag("BOOT\n");
      // we booted. Read config from EEPROM
      load_or_init_config();
      diag("POSTROM\n");
      
      // test_blocksend_code();
      // Check if the "reset" pin is held down, wait for release... force this mode in case we don't have a valid EEPROM...
      if (ConfigImageSize == 0 || wait_signal_released())
      {
        diag("RELOADIMAGE1: ");
        diag(ConfigImageSize);
        diag(" - ");
        diag(ActiveConfigFile);
        diag(" - ");
        diaghex(ConfigFlags);
        diag("\n");
        
        // indeed! Do we have a new setup image in the reader? 
        if (check_setup_image_on_card())
        {
          diag("RELOADIMAGE2\n");
          // yes, we got one... offer for installation... or force if ROM is empty...
          if (ConfigImageSize == 0 || confirm_install_setup_image())
          {
            // load and update boot image...
            diag("RELOADIMAGE3\n");
            replace_setup_image_from_card();
            diag("\nRELOADIMAGE4\n");
          }
        }
        ModemState = STATE_SERVICING;
      }
      else
        ModemState = STATE_CONNECT_SD;
      break;
    case STATE_SERVICING:
      diag("SERVICING\n");
      // possibly some extensions...

      ForceChannelQuery = true;
      IsServicingMode = true;

      ModemState = STATE_CONNECT_SD; // continue on...
      break;

    case STATE_CONNECT_SD:
      diag("CONNECT_SD\n");
      LocalServerAvailbale = false;
      if (SDCardDetected && wants_local_server())
      {
        if (!check_and_initilize_local_server())
        {
          blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_LOCALSERVERFAILD);
        }
        else
        {
          LocalServerAvailbale = true;
        }
      }
      
      ModemState = STATE_CONNECT_WIFI;
      break;

    case STATE_CONNECT_WIFI:
      diag("CONNECT_WIFI\n");
      WiFiAvailable = false;
      if (wants_network_server())
      {
        if (!check_and_initilize_wifi())
          blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_WIFIFAILED);
        else
        {
          digitalWrite(PIN_LED_NET, LED_ON);
          ModemState = STATE_CONNECTING_WIFI;
        }
      }
      ModemState = STATE_START;
      break;

    case STATE_CONNECTING_WIFI:
      diag("CONNECTING_WIFI\n");
      // TODO: established?
      delay(100); 
     
      break;

    case STATE_START:
      diag("START!\n");
      // we force ourselves into servicing mode if we have nowhere to go...
      if (!(LocalServerAvailbale || WiFiAvailable))
      {
        IsServicingMode = true;
        blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_NOSERVER);
      }
      diag("\nserver starting...\n");
      ModemState = STATE_RUN;
      diag("RUN\n");
      break;

    case STATE_RUN:
      if (!handle_hcca_request())
      {
        modem_panic(ERROR_SIGNAL_FATAL_COM_ERROR);
      }
      break;
    case STATE_ERROR:
      diag("\n\nERROR State! Restarting!\n\n");

      if (PanicCode > 0)
      {
        blink_status_confirmed(PIN_LED_ERR, PanicCode);
      }
      else
      {
        blink_status_confirmed(PIN_LED_IO, 1);
        blink_status_confirmed(PIN_LED_NET, 1);
        blink_status_confirmed(PIN_LED_ERR, 1);
      }
        
      ESP.restart();
      break;
  }
}
