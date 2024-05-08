/*
 * 
 * NABU Modem Firmware - Version 1.0 - Copyright 2023-2024 by Atkelar - All Rights Reserved; 
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


#include "Firmware.h"

/*
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
 *  The modem connects to the server via a websocket;
 *  This enables HTTPS transparent connectivity and still
 *  supports active server to client communication
 *  WebSocketClient source from https://github.com/hellerchr/esp8266-websocketclient
 *  adapted to provide "has data" feature and "binary" transfers.
 *  
 * 
 */





// ****************************************************  Setup and state machine code *******************************************

void setup() 
{

#ifdef SERIALDIAG
  // initial serial for diag com output.
  Serial.begin(115200, SERIAL_8N1);

  diag("\n\nDIAG_START\n");
#else

  // initialize serial for Nabu communication
  // NOTE: the bitrate is odd due to the NTSC
  // frequency getting divided down for it.
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

#ifndef SERIALDIAG
  // enable the 5V side of the modem via the level shifter.
  digitalWrite(PIN_FIVEV_ENABLE, HIGH); 
#endif

  ModemConfig.init();

  Modem.init();

}

void loop() 
{
  if (!Modem.handle_state_loop())
  {
    diag("\n\nERROR State! Restarting!\n\n");
    
    if (Modem.panic_code() > 0)
    {
      blink_status_confirmed(PIN_LED_ERR, Modem.panic_code());
    }
    else
    {
      blink_status_confirmed(PIN_LED_IO, 1);
      blink_status_confirmed(PIN_LED_NET, 1);
      blink_status_confirmed(PIN_LED_ERR, 1);
    }
      
    ESP.restart();
  }
}
