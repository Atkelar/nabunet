
#include "ModemHandler.h"
#include "Utilities.h"
#include "NabuHandlerAbstraction.h"
#include "HCCAHandler.h"
#include "Arduino.h"
#include <SdFat.h>
#include <ESP8266WiFi.h>
#include "ConfigFile.h"
#include "ServerAbstraction.h"
#include "NabuNetHandler.h"

NabuNetModem Modem;

// SD card root object... initialized during setup, so we don't yet support
// "hot plug or unplug" for the SD card; this might change eventually. There just 
// wasn't a pin available that would be useful for the "detect card" switch.
SdFat sd;
WiFiEventHandler wifiConnectHandler;
WiFiEventHandler wifiDisconnectHandler;

void onWifiConnect(const WiFiEventStationModeGotIP& event) {
  diag("Connected to WIFI!\n");
  Modem.wifi_connected();
}

void onWifiDisconnect(const WiFiEventStationModeDisconnected& event) {
  diag("Disconnected from WIFI!\n");
  Modem.wifi_disconnected();
}

void NabuNetModem::init()
{
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

  NabuIO.set_active_handler(new HCCAHandler(false, 0));

  LocalServerAvailbale = false;
  ForceChannelQuery = false;
  WiFiAvailable = false;
  IsServicingMode = false;

  PanicCode = 0;

  ModemState = STATE_BOOT; // delegate some more heavy lifting into the loop method, just because.

  //Register event handlers
  wifiConnectHandler = WiFi.onStationModeGotIP(onWifiConnect);
  wifiDisconnectHandler = WiFi.onStationModeDisconnected(onWifiDisconnect);
}

int NabuNetModem::panic_code()
{
  return PanicCode;
}
void NabuNetModem::panic_now(int code)
{
  diag("PANIC: ");
  diag(code);
  ModemState = STATE_ERROR;
  PanicCode = code;
}

void NabuNetModem::wifi_disconnected()
{
  WiFiConnected = false;
  if (ModemConfig.wants_wifi())
  {
    WiFi.reconnect(); // we try our best...
    digitalWrite(PIN_LED_NET, LED_ON);
  }
}

void NabuNetModem::wifi_connected()
{
  WiFiConnected = true;
  digitalWrite(PIN_LED_NET, LED_OFF);
}

bool NabuNetModem::has_wifi()
{
  return WiFiAvailable && WiFiConnected;
}

bool NabuNetModem::check_and_initilize_local_server()
{
  // TODO: check for SD and folders...
  return ModemConfig.wants_local_server();
}


bool NabuNetModem::check_and_initilize_wifi() 
{
  if (ModemConfig.wants_wifi() && ModemConfig.wifi_valid())
  {
    digitalWrite(PIN_LED_NET, LED_ON);
    diag("WiFi init...");
    if (WiFi.getMode() != WIFI_STA)
    {
      if (!WiFi.mode(WIFI_STA))
      {
        return false;
      }
    }
    diag(ModemConfig.ActiveConfig.SSID);
    diag("...");
    WiFi.begin(ModemConfig.ActiveConfig.SSID, ModemConfig.ActiveConfig.NetworkKey, 0, NULL, true); // try connecting...
    delay(500);
    diaghex(WiFi.status());
    diag("x\n");
    ModemState = STATE_CONNECTING_WIFI;
    WiFiConnectTimeout = 50;
    return true;
  }
  return false;
}

bool NabuNetModem::check_and_initilize_remote_server() 
{
  return (ModemConfig.ActiveConfig.Flags & CONFIG_FLAG_USE_WIFI);
}

// wait for 3 seconds and see if the "reset" button get's pressed again, blinking the status LEDs...
bool NabuNetModem::confirm_install_setup_image()
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

// Loads the provided image file from SD and places it into the SPIFFS store, marking it as configured if successful.
void NabuNetModem::replace_setup_image_from_card()
{
  digitalWrite(PIN_LED_IO, LED_ON);
  // 1.: read the boot image into the EEPROM

  bool imageLoaded = false;
  int imageSize = 0;
  int versionOffset = 0;
  int idx = 0;

  int newImage = ModemConfig.ActiveConfig.ActiveConfigFile == 1 ? 2 : 1; // switch from one to two or back...
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
        int r = fInput.read(shared_buffer, BUFFER_SIZE);
        if (r == 0)
          break;
        f.write(shared_buffer, r);
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
    memset(shared_buffer, 0, 33);

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
        int r = f.read(shared_buffer, 32);
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
    strncpy(ModemConfig.ActiveConfig.ConfigImageVersion, (const char*)shared_buffer, 31);
    ModemConfig.ActiveConfig.ConfigImageSize = imageSize;
    ModemConfig.ActiveConfig.ActiveConfigFile = newImage;
    ModemConfig.ActiveConfig.Flags |= CONFIG_FLAG_HAS_IMAGE;

    // 4.: save config to EEPROM
    ModemConfig.save_config(false);
  }

  digitalWrite(PIN_LED_ERR, imageLoaded ? LED_OFF : LED_ON);

  digitalWrite(PIN_LED_IO, LED_OFF);

  blink_status_confirmed(PIN_LED_IO, 3);
}


// Check if we have a firmware update on the SD card; false if not.
bool NabuNetModem::check_setup_image_on_card()
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


// Waits until the reset button is released; if longer than 5 seconds, we assume a stuck button.
// return true if the button was initially pressed and released within that timeout;
bool NabuNetModem::wait_signal_released()
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

// Overall nabu <-> server communication loop.
bool NabuNetModem::handle_modem_running()
{
  int now = millis(); // get ready for timeout based stuff...
  if(Serial.available())  // NABU should be slow enough to enable a byte-by-byte receive loop...
  {
    int byteInput = Serial.read();
    // TODO: add "nabu net reset request detection" here, similar to the Nabu reset...
    if (byteInput == 0x83)    // wait for two 0x83 bytes in slow succession for Nabu reset detection...
    {
      diag("x");
      // maybe?
      if (LastHCCAByte == 0x83 && (now - LastHCCAInput > 250))
      {
        HCCAResetSequenceCount++;
        if (HCCAResetSequenceCount > 1)
        {
          diag("RESET!");
          // Gotcha!
          NabuIO.set_active_handler(new HCCAHandler(!IsServicingMode && ForceChannelQuery, IsServicingMode ? 0 : ModemConfig.ActiveConfig.ChannelCode));  // force back to HCCA handler for booting...
          NabuIO.clear_send();
          NabuIO.clear_receive();
          // we will pick up the byte downstairs...
        }
      }
      else
        HCCAResetSequenceCount = 0;
    }
    else
      HCCAResetSequenceCount = 0;
    // write byte to input buffer anyhow...
    LastHCCAInput = now;
    LastHCCAByte = byteInput;

    if (!NabuIO.handle_received(byteInput))
      return false;
  }
  // TODO: websocket input handling here!
  
  if (!NabuIO.handle_idle())
    return false;
    
  return NabuIO.flush_send();  // make sure we got the send code...
}

void NabuNetModem::switch_mode_nabunet()
{
  NabuIO.set_active_handler(new NabuNetHandler(IsServicingMode));
}

bool NabuNetModem::handle_state_loop()
{
  switch (ModemState)
  {
    case STATE_BOOT:
      diag("BOOT\n");
      // we booted. Read config from EEPROM
      ModemConfig.load_or_init_config();
      diag("POSTROM\n");

      // reset status variables for "soft boot" later on...
      LocalServerAvailbale = false;
      ForceChannelQuery = false;
      WiFiAvailable = false;
      IsServicingMode = false;
      
      // test_blocksend_code();
      // Check if the "reset" pin is held down, wait for release... force this mode in case we don't have a valid EEPROM...
      if (ModemConfig.ActiveConfig.ConfigImageSize == 0 || wait_signal_released())
      {
        diag("RELOADIMAGE1: ");
        diag(ModemConfig.ActiveConfig.ConfigImageSize);
        diag(" - ");
        diag(ModemConfig.ActiveConfig.ActiveConfigFile);
        diag(" - ");
        diaghex(ModemConfig.ActiveConfig.Flags);
        diag("\n");
        
        // indeed! Do we have a new setup image in the reader? 
        if (check_setup_image_on_card())
        {
          diag("RELOADIMAGE2\n");
          // yes, we got one... offer for installation... or force if ROM is empty...
          if (ModemConfig.ActiveConfig.ConfigImageSize == 0 || confirm_install_setup_image())
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

      ModemState = STATE_START; // continue on...
      break;

    case STATE_CONNECT_SD:
      diag("CONNECT_SD\n");
      if (SDCardDetected &&  ModemConfig.wants_local_server())
      {
        if (!check_and_initilize_local_server())
        {
          blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_LOCALSERVERFAILD);
        }
        else
        {
          LocalServerAvailbale = true;  
          ModemState = STATE_START;    // localserver overrides network, so skip WiFi and boot into it...
          break;
        }
      }
      
      ModemState = STATE_CONNECT_WIFI;
      break;

    case STATE_CONNECT_WIFI:
      diag("CONNECT_WIFI\n");
      if (ModemConfig.wants_wifi())
      {
        if (!check_and_initilize_wifi())
          blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_WIFIFAILED);
        else
        {
          ModemState = STATE_CONNECTING_WIFI;
          break;
        }
      }
      ModemState = STATE_START;
      break;

    case STATE_CONNECTING_WIFI:
      diag("CONNECTING_WIFI\n");
      switch(WiFi.status())
      {
        case WL_CONNECTED:
          diag("connected.\n");
          ModemState = STATE_CONNECT_REMOTE_SERVER;
          WiFiAvailable = true;
          digitalWrite(PIN_LED_NET, LED_OFF);
          break;
        case WL_IDLE_STATUS:
          digitalWrite(PIN_LED_NET, LED_OFF);
          delay(250);
          digitalWrite(PIN_LED_NET, LED_ON);
          break;
        case WL_DISCONNECTED:
          WiFiConnectTimeout--;
          if (WiFiConnectTimeout <= 0)
          {
            diag("timeout during conect!\n");
            WiFiAvailable = false;
            digitalWrite(PIN_LED_NET, LED_OFF);
            blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_WIFIFAILED);
            ModemState = STATE_START;
          }
          else
          {
            diag(".");
            digitalWrite(PIN_LED_NET, LED_OFF);
            delay(250);
            digitalWrite(PIN_LED_NET, LED_ON);
          }
          break;
        case WL_NO_SSID_AVAIL:
        case WL_CONNECT_FAILED:
        case WL_CONNECTION_LOST:
        case WL_WRONG_PASSWORD:
          WiFiAvailable = false;
          diag("error: ");
          diaghex(WiFi.status());
          diag("\n");
         
          digitalWrite(PIN_LED_NET, LED_OFF);
          blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_WIFIFAILED);
          ModemState = STATE_START;
          break;
      }
      break;

    case STATE_CONNECT_REMOTE_SERVER:
      diag("CONNECT-REMOTE...\n");
      RemoteServerAvailable = RemoteServerInstance.connect();
      ModemState = STATE_START;
      break;

    case STATE_START:
      diag("START!\n");
      // we force ourselves into servicing mode if we have nowhere to go...
      if (!(LocalServerAvailbale || RemoteServerAvailable))
      {
        IsServicingMode = true;
        blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_NOSERVER);
      }
      else
      {
        if (LocalServerAvailbale)
          ServerHandler::set_current(&LocalServerInstance);
        else  
          ServerHandler::set_current(&RemoteServerInstance);
        NabuIO.set_active_handler(new HCCAHandler(ModemConfig.ActiveConfig.ChannelCode, false));
      }
      if (IsServicingMode)
      {
        ServerHandler::set_current(&ConfigServerInstance);
        NabuIO.set_active_handler(new HCCAHandler(0, false));
      }
      diag("\nserver starting");
      diag(ServerHandler::current()->server_name());
      diag("...\n");
      ModemState = STATE_RUN;
      diag("RUN\n");
      break;

    case STATE_RUN:
      if (!handle_modem_running())
      {
        panic_now(ERROR_SIGNAL_FATAL_COM_ERROR);
      }
      break;
    case STATE_ERROR:
      return false;
  }
  return true;
}
