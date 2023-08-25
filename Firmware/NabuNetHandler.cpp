

#include "NabuNetHandler.h"
#include "Arduino.h"
#include "Diag.h"
#include "Utilities.h"
#include "ConfigFile.h"
#include "ServerAbstraction.h"


NabuNetHandler::NabuNetHandler(bool servicing) : NabuHandlerBase()
{
  IsServicing = servicing;
  reset_handler();
}

void NabuNetHandler::reset_handler()
{
  Incoming = false;
  Started = 0;
  State = NN_STATE_UNKNOWN;
  wifi_ScanRunning = false;
  wifi_scan_current_page = -1;
  wifi_scan_page_size = 8;
  ReportedConfigProgramVersion[0]=0;
}

void NabuNetHandler::block_received(int blockNumber, int bytes, bool lastBlock)
{
  
}



// we got regular Nabu Net communication happening.
// currently, this is called pretty deeply nested;
// might be worth "unwinding" that into some less deep stack...
bool NabuNetHandler::handle_buffer(NabuIOHandler* input)
{
  int readByte = input->read_byte();
  if (readByte >= 0)
  {
    //blink_byte(readByte);
    if (Incoming)  // we are receiving a package!  
    {
      Checksum += readByte;
      if (HasPayload)
      {
        if (PayloadLength < 0)  // we just got the payload length...
        {
          PayloadLength = readByte;
          PayloadOffset = 0;
        }
        else
        {
          if (PayloadOffset >= PayloadLength)
          {
            // we got the checksum now...
            RxDone = true;
          }
          else
          {
            Rx_Payload[PayloadOffset] = readByte;
            PayloadOffset++;
          }
        }
      }
      else
      {
        // no payload, this has to be the checksum already...
        RxDone = true;
      }
    }
    else
    {
      digitalWrite(PIN_LED_IO, LED_ON); 
      Started = millis();
      Incoming = true;
      PayloadLength = -1;
      Checksum = readByte;
      RxDone = false;
      // independently of status, the byte should be a header...
      // parse it as such...
      Code = (readByte & 0xF);
      IsReply = (readByte & 0x40) != 0;
      HasPayload = (readByte & 0x80) != 0;
    }
    // read the rest of the packet with a timeout...
    if (RxDone)
    {
      digitalWrite(PIN_LED_IO, LED_OFF);
      RxDone = false;
      Incoming = false;
      Started = 0;
      if ((Checksum & 0xFF) != 0xFF)
      {
        set_error();
        //blink_byte(0x22);
      }
      else
      {
        switch(State)
        {
          case NN_STATE_CONNECTED:
            // this took way too long... but: now we have received a proper sync'd protocol message!
            switch (Code)
            {
              case 0:
                // uh-oh... resync request; drop all and run!
                if (HasPayload && !IsReply && PayloadLength==1)
                {
                  State = NN_STATE_CONNECTING;
                  ConnectInitiated = false;
                  ConnectToken = Rx_Payload[0];
                  send_packet(input, 0x00, true, Rx_Payload, 1);
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
                if (IsServicing)
                {
                  return handle_modem_config_command(input, IsReply, Rx_Payload, HasPayload ? PayloadLength : 0);
                }// non-servicing mode drops through to "unknown protocol code" by design!
              default:
                set_error();
                break;
            }
            break;
          case NN_STATE_CONNECTING:
            // we ignore anything, except a proper SYNC packet...
            if (HasPayload && Code == 0 && PayloadLength == 1)
            {
              // if the received packet is a valid reply to our request, we lock on.
              if (IsReply && Rx_Payload[0] == ConnectToken)
              {
                // CHECK! if we originated the request, send 3rd message.
                if (ConnectInitiated)
                {
                  send_packet(input, 0x00, true, Rx_Payload, 1);
                }
                State = NN_STATE_CONNECTED;
                digitalWrite(PIN_LED_ERR, LED_OFF);
              }
              else
              {
                set_error();
                //blink_byte(Rx_Payload[0]);
                // we got a reply, but it's not ours...
                State = NN_STATE_UNKNOWN;
              }
            }
            break;
          case NN_STATE_UNKNOWN:
          case NN_STATE_ERROR:
            // we ignore anything, except a proper formed SYNC request...
            if (HasPayload && !IsReply && Code == 0 && PayloadLength == 1)
            {
              State = NN_STATE_CONNECTING;
              ConnectToken = Rx_Payload[0];
              ConnectInitiated = false;
              send_packet(input, 0x00, true, Rx_Payload, 1);  // send reply...
            }
/*            else
              if (nn_started == 0)  // track timeout for our own reconnect...
                nn_started = millis();*/
            break;
          default:
            set_error();
            break;
        }
      }
    }
  }
  else
  {
    if (Incoming)  // we are receiving a package! count timeout!
    {
      unsigned long delta = millis() - Started;
      if (delta > 500)  // half a second for "complete message" is MORE than enough...
      {
        set_error();
      }
    }
    else
    {
      if (State == NN_STATE_UNKNOWN || State == NN_STATE_ERROR)
      {
        if (Started == 0)
          Started = millis();
        else
        {
          unsigned long delta = millis() - Started;
          if (delta > 2500)
          {
            ConnectInitiated = true;
            ConnectToken = (ConnectToken +1) & 0xFF;
            if (ConnectToken == 0)
              ConnectToken = 1;
            Rx_Payload[0]=ConnectToken;
            send_packet(input, 0x00, false, Rx_Payload, 1);
            State = NN_STATE_CONNECTING;
            Started = 0;
          }
        }
      }
    }
  }
  return true;
}

void NabuNetHandler::set_error()
{
  Incoming = false;
  Started = 0;
  State = NN_STATE_ERROR;
  digitalWrite(PIN_LED_ERR, LED_ON);
  digitalWrite(PIN_LED_IO, LED_OFF);
}

bool NabuNetHandler::handle_idle(NabuIOHandler* source) 
{
  return true;
}

bool NabuNetHandler::handle_modem_config_command(NabuIOHandler* input, bool isReply, unsigned char* payload, int payloadLength)
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
          memset(ReportedConfigProgramVersion, 0, 33);
          memcpy(ReportedConfigProgramVersion, payload+1, payloadLength-1);  

          if(strcmp(ReportedConfigProgramVersion, ModemConfig.ActiveConfig.ConfigImageVersion)!= 0)
          {
            set_error();
            shared_buffer[0] = 0;
            return send_packet(input, 0xF, true, shared_buffer, 1);
          }

          // and now, send our own info...
          WiFi.macAddress(shared_buffer + 100);
          shared_buffer[0] = 0;
          sprintf((char*)shared_buffer+1, "%02X%02X%02X%02X%02X%02X", shared_buffer[100], shared_buffer[101], shared_buffer[102], shared_buffer[103], shared_buffer[104], shared_buffer[105]);
          strcpy((char*)shared_buffer+13, NABUNET_MODEM_FIRMWARE_VERSION);
          
          return send_packet(input, 0xF, true, shared_buffer, strlen(((const char*)shared_buffer)+1)+1);
        }
        shared_buffer[0] = 0;
        return send_packet(input, 0xF, true, shared_buffer, 1);
      case 0x01:  // query WiFi status
        // we want: 
        //   WiFi enabled in cofig ?
        //   WiFi SSID configured  ?
        //   WiFi Key configured   ?
        //   WiFi status: off/connecting/connected
        //      if connected: signal strength
        //                    IP Address

        shared_buffer[0] = (ModemConfig.ActiveConfig.Flags & CONFIG_FLAG_USE_WIFI) != 0 ? 1 : 0;
        shared_buffer[1] = (ModemConfig.ActiveConfig.SSID[0] != 0) ? 1 : 0;
        shared_buffer[2] = (ModemConfig.ActiveConfig.NetworkKey[0] != 0) ? 1 : 0;
        shared_buffer[3] = translate_wifi_status(WiFi.status());
        if (shared_buffer[3]==1)
        {
          shared_buffer[4] = translate_wifi_signal_strength(WiFi.RSSI());
        }
        else
        {
          shared_buffer[4] = 0;
        }
        return send_packet(input, 0xF, true, shared_buffer, 5);
      case 0x02: // start WiFi scan
        if (WiFi.getMode() != WIFI_STA)
        {
          if (!WiFi.mode(WIFI_STA))
          {
            shared_buffer[0] = 0xFF;
            return send_packet(input, 0xF, true, shared_buffer, 1);
          }
        }

        if (wifi_ScanRunning)
        {
          shared_buffer[0] = 0;
          return send_packet(input, 0xF, true, shared_buffer, 1);
        }

        WiFi.scanDelete();  // clear out old results if any...
        wifi_scan_current_page = -1;
        wifi_scan_page_size = (payloadLength > 1) ? payload[1] : 8;
        
        wifi_ScanRunning = WiFi.scanNetworks(true, true) == WIFI_SCAN_RUNNING;
        shared_buffer[0] = wifi_ScanRunning ? 0 : 1;
        return send_packet(input, 0xF, true, shared_buffer, 1);
      case 0x03: // SSID Scan complete?
        if (wifi_ScanRunning)
        {
          if (WiFi.scanComplete() >= 0)
          {
            wifi_ScanRunning = false;
            wifi_scan_current_page = 0;
            shared_buffer[0] = 1;  // scan is DONE.
          }
          else
            shared_buffer[0] = 2;  // scan is RUNNING.
        }
        else
          shared_buffer[0] = WiFi.scanComplete() >= 0 ? 1 : 0; // done or not started.
        return send_packet(input, 0xF, true, shared_buffer, 1);
      case 0x04: // Get Current SSID page info. We "page"; this way, we can have "no knowledge" of current page number and have any number of networks and we can transfer one entry at a time.
        {
          int n = WiFi.scanComplete();
          if (n>=0 && wifi_scan_page_size > 0)
          {
            int numPages = ((n-1) / wifi_scan_page_size) + 1; // 8 entries at 8 per page => 1, 9 entries -> 2
            shared_buffer[0] = (wifi_scan_current_page > 0) ? 1 : 0; // can go back...
            shared_buffer[1] = (wifi_scan_current_page + 1 < numPages) ? 1 : 0; // can go forward...
            shared_buffer[2] = shared_buffer[1] == 1 ? wifi_scan_page_size : wifi_scan_page_size - (n % wifi_scan_page_size);
            return send_packet(input, 0xF, true, shared_buffer, 3);
          }
          shared_buffer[0] = 0;
          shared_buffer[1] = 0;
          shared_buffer[2] = 0;
          return send_packet(input, 0xF, true, shared_buffer, 3);
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
          shared_buffer[0] = (wifi_scan_current_page > 0) ? 1 : 0; // can go back...
          shared_buffer[1] = (wifi_scan_current_page + 1 < numPages) ? 1 : 0; // can go forward...
          shared_buffer[2] = shared_buffer[1] == 1 ? wifi_scan_page_size : wifi_scan_page_size - (n % wifi_scan_page_size);
          return send_packet(input, 0xF, true, shared_buffer, 3);
        }
        shared_buffer[0] = 0;
        shared_buffer[1] = 0;
        shared_buffer[2] = 0;
        return send_packet(input, 0xF, true, shared_buffer, 3);
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
            shared_buffer[0] = translate_wifi_encryption(WiFi.encryptionType(o));
            shared_buffer[1] = translate_wifi_signal_strength(WiFi.RSSI(o));
            shared_buffer[34] = 0; // catch too long SSID.
            strncpy(((char*)shared_buffer+2), WiFi.SSID(o).c_str(), 32);
            return send_packet(input, 0xF, true, shared_buffer, 2 + strlen((const char*)shared_buffer+2));
          }
        }
        shared_buffer[0]=0;
        shared_buffer[1]=0;
        return send_packet(input, 0xF, true, shared_buffer, 2);
      }
      case 0x07:  // enable/disable WiFi...
      {
        bool enableNow = (payloadLength > 1 && payload[1] == 1);
        if (enableNow)  // validate if we have all the data...
        {
          if (strlen(ModemConfig.ActiveConfig.SSID)==0)
          {
            // SSID not configured, deny enabling...
            shared_buffer[0]=2;  // return code 2 = SSID missing.
            return send_packet(input, 0xF, true, shared_buffer, 1);
          }
        }
        if(enableNow)
          ModemConfig.ActiveConfig.Flags |= CONFIG_FLAG_USE_WIFI;
        else
          ModemConfig.ActiveConfig.Flags &= ~CONFIG_FLAG_USE_WIFI;
        ModemConfig.save_config();
        if (ModemConfig.ActiveConfig.Flags & CONFIG_FLAG_USE_WIFI)
        {
          // (re-)enable WiFi... TODO: do we need to check for active scans?
          if (WiFi.getMode() != WIFI_STA)
          {
            if (!WiFi.mode(WIFI_STA))
            {
              shared_buffer[0] = 0x3;
              return send_packet(input, 0xF, true, shared_buffer, 1);
            }
          }
          WiFi.begin(ModemConfig.ActiveConfig.SSID, ModemConfig.ActiveConfig.NetworkKey); // try connecting...
        }
        else
        {
          if (WiFi.getMode() == WIFI_STA)
          {
            WiFi.disconnect(); // disconnect...
          }
        }
        shared_buffer[0]=0;  // return code 0 = status updated.
        return send_packet(input, 0xF, true, shared_buffer, 1);
      }
      break;
      case 0x08:
      {
        // set SSID or NetworkKey string; can also be used to set "other" strings...
        if (payloadLength >= 3)
        {
          byte what = payload[1]; // 1 = SSID, 2 = Key
          if (what < 1 || what > 6)
          {
            shared_buffer[0]=0xFF;  // return code 0xFF = protocol error
            return send_packet(input, 0xF, true, shared_buffer, 1);
          }
          byte strLen = payload[2];
          bool wasWiFiSetting = false;
          bool wasRemoteSetting = false;
          if(strLen == 0)
          {
            // we want to clear the setting...
            switch(what)
            {
              case 1:
                // SSID...
                // ...turn off WiFi!
                wasWiFiSetting = true;
                memset(ModemConfig.ActiveConfig.SSID, 0, 33);  // remove ALL of the old one!
                memset(ModemConfig.ActiveConfig.NetworkKey, 0, 65);  // remove ALL of the old one!
                ModemConfig.ActiveConfig.Flags &= ~CONFIG_FLAG_USE_WIFI;
                break;
              case 2:
                // Key...
                wasWiFiSetting = true;
                memset(ModemConfig.ActiveConfig.NetworkKey, 0, 65);  // remove ALL of the old one!
                ModemConfig.ActiveConfig.Flags &= ~CONFIG_FLAG_USE_WIFI;
                break;
              case 3: // IP address, not ignore..
                break;
              case 4: 
                // Network host...
                // ...disconnect
                wasRemoteSetting = true;
                memset(ModemConfig.ActiveConfig.NetworkHost, 0, 121);  // remove ALL of the old one!
                break;
              case 5:
                // Network path...
                // ...disconnect
                wasRemoteSetting = true;
                memset(ModemConfig.ActiveConfig.NetworkPath, 0, 33);  // remove ALL of the old one!
                break;
              case 6:
                // Network port...
                // ...disconnect
                wasRemoteSetting = true;
                ModemConfig.ActiveConfig.NetworkPort = DEFAULT_SERVER_PORT;
                ModemConfig.save_config();
                break;
            }
            ModemConfig.save_config();
            if (WiFi.getMode() == WIFI_STA && wasWiFiSetting)
            {
              WiFi.disconnect();
            }
            if (wasRemoteSetting)
            {
                if (RemoteServerInstance.is_connected())
                  RemoteServerInstance.disconnect();
            }
          }
          else
          {
            if (strLen + 3 <= payloadLength)
            {
              // update...
              switch(what)
              {
                case 1:
                  memset(ModemConfig.ActiveConfig.SSID, 0, 33);  // remove ALL of the old one!
                  memcpy(ModemConfig.ActiveConfig.SSID,payload+3,strLen>=32 ? 32 : strLen);
                  wasWiFiSetting = true;
                  break;
                case 2:
                  memset(ModemConfig.ActiveConfig.NetworkKey, 0, 65);  // remove ALL of the old one!
                  memcpy(ModemConfig.ActiveConfig.NetworkKey,payload+3,strLen>=64 ? 64 : strLen);
                  wasWiFiSetting = true;
                  break;
                case 3:
                  break;
                case 4: 
                  // Network host...
                  wasRemoteSetting = true;
                  memset(ModemConfig.ActiveConfig.NetworkHost, 0, 121);  // remove ALL of the old one!
                  memcpy(ModemConfig.ActiveConfig.NetworkHost, payload+3,strLen>=120 ? 120 : strLen);
                  break;
                case 5:
                  // Network path...
                  wasRemoteSetting = true;
                  memset(ModemConfig.ActiveConfig.NetworkPath, 0, 33);  // remove ALL of the old one!
                  memcpy(ModemConfig.ActiveConfig.NetworkPath, payload+3,strLen>=32 ? 32 : strLen);
                  break;
                case 6:
                  wasRemoteSetting = true;
                  payload[3+strLen] = 0;
                  ModemConfig.ActiveConfig.NetworkPort = atoi((char*)(payload+3));
                  break;
              }
              ModemConfig.save_config();
              if (WiFi.getMode() == WIFI_STA && wasWiFiSetting)
              {
                WiFi.disconnect();
                if (ModemConfig.ActiveConfig.Flags & CONFIG_FLAG_USE_WIFI)
                  WiFi.begin(ModemConfig.ActiveConfig.SSID, ModemConfig.ActiveConfig.NetworkKey);  // reconnect, without password...
              }
              if (wasRemoteSetting)
              {
                  if (RemoteServerInstance.is_connected())
                    RemoteServerInstance.disconnect();
                  // TODO: try connecting...
                  RemoteServerInstance.connect();
              }
            }
            else
            {
              shared_buffer[0]=0xFF;  // return code 0xFF = protocol error
              return send_packet(input, 0xF, true, shared_buffer, 1);
            }
          }
          shared_buffer[0]=0x0;  // return code 0 = OK.
          return send_packet(input, 0xF, true, shared_buffer, 1);
        }
      }
      break;
      case 0x09:
      {
        // get SSID or other string. Network key is NOT readable!
        if (payloadLength >= 2)
        {
          byte what = payload[1]; // 1 = SSID, 2 = Key (invalid), 3 = local IP...
          if (what < 1 || what > 8 || what == 2)
          {
            shared_buffer[0]=0xFF;  // return code 0xFF = protocol error
            return send_packet(input, 0xF, true, shared_buffer, 1);
          }

          shared_buffer[0] = shared_buffer[1] = 0;  // code 0 = success, 0 default length.

          switch (what)
          {
            case 1:
              strcpy((char*)shared_buffer+2, ModemConfig.ActiveConfig.SSID);
              shared_buffer[1] = strlen(ModemConfig.ActiveConfig.SSID);
              break;
            case 3:
              if (WiFi.status() == WL_CONNECTED)
              {
                IPAddress addr = WiFi.localIP();
                String str = addr.toString();
                strcpy((char*)shared_buffer+2, str.c_str());
                shared_buffer[1] = str.length();
              }
              break;
            case 4:
              strcpy((char*)shared_buffer+2, ModemConfig.ActiveConfig.NetworkHost);
              shared_buffer[1] = strlen(ModemConfig.ActiveConfig.NetworkHost);
              break;
            case 5:
              strcpy((char*)shared_buffer+2, ModemConfig.ActiveConfig.NetworkPath);
              shared_buffer[1] = strlen(ModemConfig.ActiveConfig.NetworkPath);
              break;
            case 6:
              sprintf((char*)shared_buffer+2, "%d", ModemConfig.ActiveConfig.NetworkPort);
              shared_buffer[1]= strlen((char*)shared_buffer+2);
              break;
            case 7:
              // remote server version...
              strcpy((char*)shared_buffer+2, RemoteServerInstance.server_version().c_str());
              shared_buffer[1] = RemoteServerInstance.server_version().length();
              break;
            case 8:
              // remote server name...
              strcpy((char*)shared_buffer+2, RemoteServerInstance.server_name().c_str());
              shared_buffer[1] = RemoteServerInstance.server_name().length();
              break;
          }
          return send_packet(input, 0xF, true, shared_buffer, 2 + shared_buffer[1]);
        }
      }
      case 0x0A:  // query Remote Server status
        // we want: 
        //   Remote enabled in cofig ?
        // if connected, remote API version and remote server name/flags and version

        shared_buffer[0] = (ModemConfig.ActiveConfig.Flags & CONFIG_FLAG_USE_REMOTE) != 0 ? 1 : 0;
        shared_buffer[1] = RemoteServerInstance.api_level();
        shared_buffer[2] = RemoteServerInstance.feature_flags() & 0xFF;
        shared_buffer[3] = ModemConfig.ignore_tls_errors() ? 1 : 0;
       
        return send_packet(input, 0xF, true, shared_buffer, 4);
      case 0x0B:  // enable/disable Remote...
      {
        bool enableNow = (payloadLength > 1 && payload[1] == 1);
        if (enableNow)  // validate if we have all the data...
        {
          if (strlen(ModemConfig.ActiveConfig.NetworkHost)==0 || strlen(ModemConfig.ActiveConfig.NetworkPath)==0)
          {
            // URL incorrect
            shared_buffer[0]=2;  // return code 2 = parameter missing.
            return send_packet(input, 0xF, true, shared_buffer, 1);
          }
        }
        if(enableNow)
          ModemConfig.ActiveConfig.Flags |= CONFIG_FLAG_USE_REMOTE;
        else
          ModemConfig.ActiveConfig.Flags &= ~CONFIG_FLAG_USE_REMOTE;
        ModemConfig.save_config();
        if (ModemConfig.ActiveConfig.Flags & CONFIG_FLAG_USE_REMOTE)
        {
          // (re-)enable WiFi... TODO: do we need to check for active scans?
          if (!RemoteServerInstance.connect())
            return send_packet(input, 0xF, true, shared_buffer, 1);
        }
        else
        {
          RemoteServerInstance.disconnect();
        }
        shared_buffer[0]=0;  // return code 0 = status updated.
        return send_packet(input, 0xF, true, shared_buffer, 1);
      }
      break;
      case 0x0C:  // enable/disable ignore TLS errors...
      {
        bool newValue = (payloadLength > 1 && payload[1] == 1);
        if (newValue != ModemConfig.ignore_tls_errors())
        {
          ModemConfig.set_ignore_tls_errors(newValue);
          if (ModemConfig.wants_network_server())
          {
            if (!RemoteServerInstance.connect())
            {
              shared_buffer[0] = 1;
              return send_packet(input, 0xF, true, shared_buffer, 1);
            }
          }
        }
        shared_buffer[0] = 0;  // return code 0 = status updated.
        return send_packet(input, 0xF, true, shared_buffer, 1);
      }
      break;
    }
  }
  return true;
}


bool NabuNetHandler::send_packet(NabuIOHandler* source, byte code, bool isReply, unsigned char* bufferAddress, int bufferLength)
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
  if (!source->send_byte(code))
    return false;
  if (bufferLength > 0 && bufferAddress != NULL)
  {
    code = bufferLength;
    checksum+=code;
    if (!source->send_byte(code))
      return false;
    for (int i = 0; i < bufferLength; i++)
    {
      if (!source->send_byte(bufferAddress[i]))
        return false;
      checksum+=bufferAddress[i];
    }
  }
  
  if (!source->send_byte(0xFF - (checksum & 0xFF)))
    return false;
    
  return true;
}
