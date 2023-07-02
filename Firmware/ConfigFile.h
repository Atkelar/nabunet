#ifndef CONFIGFILEH
#define CONFIGFILEH


// we write a constant size config blob...
// this originated as an "external ROM" idea, so it's kept around...
#define CONFIGFILESIZE 2048
#define CONFIGFILENAME "/cfg.dat"

// Magic bytes for config block to detect "virgin" ROMs or broken files.
#define CONFIGBLOCK_MAGIC_1 0xF5
#define CONFIGBLOCK_MAGIC_2 0x5A

// Maximum size for a configuration image. Should be slightly less than 32k, to open option to replace
// built in EEPROM with an external 64k one eventually...
#define IMAGESIZELIMIT 24*1024


// Fallback server URL for broken configs
#define DEFAULT_SERVER_HOST "nabu.atkelar.com"
#define DEFAULT_SERVER_PATH "/api"
#define DEFAULT_SERVER_PORT 443


// Flags for the configuration block

// We have enabled WiFi connectivity (SSID, KEY are "valid" and should be used)
#define CONFIG_FLAG_USE_WIFI 1

// We want to use a locally present SD card as a server. If a card is present, it will 
// override the WiFi selection.
#define CONFIG_FLAG_USE_SD 2

// We are authenticated at the remote server; If not, we access as anonymous user.
#define CONFIG_FLAG_IS_AUTHENTICATED 4

// The local SD server can be updated; R/O if not set.
#define CONFIG_FLAG_SD_WRITE 8

// We have enabled the remote server in the config; this enables WiFi and remote server separation;
#define CONFIG_FLAG_USE_REMOTE 16 

// The internal ROM has an active config image. Should only be missing on virgin setups and requires
// a boot update from SD to fix.
#define CONFIG_FLAG_HAS_IMAGE 0x8000


// Configuration block version.
#define CONFIG_VERSION 0x2

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

  // Version 2...
  char NetworkPath[33];
  int NetworkPort;
};


class NabuNetConfig
{
  public:
    NabuNetConfig();

    ConfigurationInfo ActiveConfig;

    void init();

    bool wants_local_server();
    bool wants_network_server();
    bool wants_wifi();
    bool wifi_valid();

    // try to read the EEPROM content and see if we have any old data. 
    // Initialize WiFi and other parameters accordingly if we haven't.
    void load_or_init_config();
    
    // write current config settings to EEPROM, specify if we want the IO LED toggled or not.
    void save_config(bool showIndicator = true);

    // fetch file block for loading OS from the current config file.
    bool read_block_from_config_image(int number, int blockSize, int* readByteCount, void* buffer);

  private:
    // write current config settings to EEPROM, do NOT toggle LEDs...
    // This uses the "buffer" memory for transfer; relic from when
    // the code was trying to save to I2C EEPROM, keep like that
    // in case an EEPROM option returns...
    void save_config_now();
};

extern NabuNetConfig ModemConfig;
#endif
