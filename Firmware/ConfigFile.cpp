
#include "ConfigFile.h"
#include "Diag.h"
#include "Definitions.h"
#include "Utilities.h"
#include "Arduino.h"
#define FS_NO_GLOBALS
// ...which would happen if we just include FS.h
#include <FS.h>

NabuNetConfig ModemConfig;

NabuNetConfig::NabuNetConfig()
{
  
}

void NabuNetConfig::save_config(bool showIndicator)
{
  if (showIndicator)
    digitalWrite(PIN_LED_IO, LED_ON);
  save_config();
  if (showIndicator)
    digitalWrite(PIN_LED_IO, LED_OFF);
}


void NabuNetConfig::save_config_now()
{
  using fs::File;
  shared_buffer[0] = CONFIGBLOCK_MAGIC_1;
  shared_buffer[1] = CONFIGBLOCK_MAGIC_2;
  memset(shared_buffer + 2, 0, sizeof(ConfigurationInfo));
  // we save the config now, it WILL be the latest version:
  ActiveConfig.Version = CONFIG_VERSION;

  memcpy(shared_buffer + 2, (void*)&ActiveConfig, sizeof(ConfigurationInfo));

  append_crc16(shared_buffer, CONFIGFILESIZE); // add a checksum...

  File f = SPIFFS.open(CONFIGFILENAME, "w");
  if (f)
  {
    f.write(shared_buffer, CONFIGFILESIZE);
    f.close();
  }
}

bool NabuNetConfig::wifi_valid()
{
  return strlen(ActiveConfig.SSID)>0;
}

bool NabuNetConfig::wants_local_server()
{
  return (ActiveConfig.Flags & CONFIG_FLAG_USE_SD) != 0;
}

bool NabuNetConfig::wants_network_server()
{
  return wants_wifi() && (ActiveConfig.Flags & CONFIG_FLAG_USE_REMOTE) != 0;
}

bool NabuNetConfig::wants_wifi()
{
  return (ActiveConfig.Flags & CONFIG_FLAG_USE_WIFI) != 0;
}

// try to read the EEPROM content and see if we have any old data. 
// Initialize WiFi and other parameters accordingly if we haven't.
void NabuNetConfig::load_or_init_config()
{
  using fs::File;
  digitalWrite(PIN_LED_IO, LED_ON);

  bool fsAvailable = false;

  fs::FSInfo fs_info;
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

  memset(&ActiveConfig,0,sizeof(ConfigurationInfo));

  // make sure we have newer revisions prepared; 
  // Any additions for newer versions need to be defaulted here:
  strncpy(ActiveConfig.NetworkPath, DEFAULT_SERVER_PATH, 32);
  ActiveConfig.NetworkPort = DEFAULT_SERVER_PORT;


  memset(shared_buffer,0,CONFIGFILESIZE);

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
        if (f.readBytes((char*)shared_buffer, CONFIGFILESIZE) != CONFIGFILESIZE)
        {
          diag("config file too small\n");
          shared_buffer[0]=0; // force non-magic byte.
        }
        f.close();
      }
    }
  }

  bool configValid = false;

  if (shared_buffer[0]==CONFIGBLOCK_MAGIC_1 && shared_buffer[1] == CONFIGBLOCK_MAGIC_2 && validate_crc16(shared_buffer, CONFIGFILESIZE))
  {
    ConfigurationInfo* info = (ConfigurationInfo*)(shared_buffer + 2);

    switch (info->Version)
    {
      // most recent version... on top...
      case 0x02:  
        // added at version 2
        
        strncpy(ActiveConfig.NetworkPath, info->NetworkPath, 32);
        ActiveConfig.NetworkPort = info->NetworkPort;
        // fall to earlier version...
      case 0x01:
        ActiveConfig.Flags = info->Flags;
        ActiveConfig.ChannelCode = info->ChannelCode;
        ActiveConfig.ConfigImageSize = info->ConfigImageSize;
        ActiveConfig.ActiveConfigFile = info->ActiveConfigFile;
        
        strncpy(ActiveConfig.SSID, info->SSID, 32);
        strncpy(ActiveConfig.NetworkKey, info->NetworkKey, 64);
        strncpy(ActiveConfig.NetworkHost, info->NetworkHost, 120);
        strncpy(ActiveConfig.NetworkUserName, info->NetworkUserName, 39);
        memcpy(ActiveConfig.NetworkUserToken, info->NetworkUserToken, 16);
        strncpy(ActiveConfig.ConfigImageVersion, info->ConfigImageVersion, 31);
       
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
    memset(&ActiveConfig,0,sizeof(ConfigurationInfo));
    
    ActiveConfig.NetworkPort = DEFAULT_SERVER_PORT;
    strncpy(ActiveConfig.NetworkPath, DEFAULT_SERVER_PATH, 32);
    strncpy(ActiveConfig.NetworkHost, DEFAULT_SERVER_HOST, 120);
    
    save_config(false);

    delay(250); // make sure we see that...
    digitalWrite(PIN_LED_ERR, LED_OFF);
  }
  digitalWrite(PIN_LED_IO, LED_OFF);
}


// reads a requested block from the config image to boot the config program.
bool NabuNetConfig::read_block_from_config_image(int number, int blockSize, int* readByteCount, void* buffer)
{
  digitalWrite(PIN_LED_IO, LED_ON);
  const char* imageFile = ActiveConfig.ActiveConfigFile == 1 ? IMAGEFILE_1 : IMAGEFILE_2;

  *readByteCount = 0;

  fs::File f = SPIFFS.open(imageFile, "r");
  if(f)
  {
    int offset = number * blockSize;

    if (offset >= ActiveConfig.ConfigImageSize)
    {
      digitalWrite(PIN_LED_ERR, LED_ON);
      digitalWrite(PIN_LED_IO, LED_OFF);
      
      return true;
    }

    int len = offset + blockSize <= ActiveConfig.ConfigImageSize ? blockSize : ActiveConfig.ConfigImageSize - offset;

    f.seek(offset);
    
    bool endOfFile = len + offset >= ActiveConfig.ConfigImageSize;

    unsigned char* buffer2 = (unsigned char*)buffer;
    int r = 0;
    while (r < len)
    {
      int r1=f.read(buffer2 + r, len - r);
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

void NabuNetConfig::init()
{
  SPIFFS.begin();
}
