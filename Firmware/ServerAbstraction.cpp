
#include "ServerAbstraction.h"
#include "ConfigFile.h"
#include "NabuHandlerAbstraction.h"
#include "Diag.h"
#include "Utilities.h"
#include <ESP8266WiFi.h>


ConfigServerHandler ConfigServerInstance;
LocalServerHandler LocalServerInstance;
RemoteServerHandler RemoteServerInstance;

const String NotConnectedServerName = "not connected...";
const String LoadingServerInfoServerName = "loading...";
const String NotConnectedServerVersion = "?.?";


static ServerHandler* _Current = NULL;


RemoteServerHandler::RemoteServerHandler()
{
  Connection = NULL;
  validatedCode = -1;
  validatedKernel = 0;
  validatedLoader = 0;
  validatedIsNabuNet = false;
  remote_buffer = (unsigned char*)malloc(4096);
}

LocalServerHandler::LocalServerHandler()
{
  
}

bool ConfigServerHandler::request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target)
{
  if (channelNumber != 0)
    return false;
  int count=0;
  bool result = ModemConfig.read_block_from_config_image(blockNumber, blockLength, &count, target);
  if (count > 0)
  {
    NabuIO.report_block_for_hcca(blockNumber, count, result);
    return true;
  }
  return false;
}

ConfigServerHandler::ConfigServerHandler()
{
  
}

ServerHandler::ServerHandler()
{

}

ServerHandler* ServerHandler::current()
{
  return _Current;
}

bool ServerHandler::set_current(ServerHandler* newTarget)
{
  _Current = newTarget;
  return true;
}

bool RemoteServerHandler::is_connected()
{
  return (Connection != NULL && Connection->isConnected() && RemoteServerApiLevel > 0);
}

void RemoteServerHandler::disconnect()
{
  if (Connection)
    delete Connection;
  Connection = NULL;
  HasServerInfo = false;
  RemoteServerApiLevel = 0;
  RemoteFlags = 0; 
  validatedCode = -1;
  validatedKernel = 0;
  validatedLoader = 0;
  validatedIsNabuNet = false;
}

bool RemoteServerHandler::has_login()
{
  return is_connected() && ((RemoteFlags & SERVER_FLAG_LOGIN)!=0);
}

int RemoteServerHandler::feature_flags()
{
  return is_connected() ? RemoteFlags : SERVER_FLAG_READONLY;
}

bool RemoteServerHandler::virtual_server_is_nabunet(int code)
{
  if (!is_connected())
    return false;
  if (validatedCode == code)
  {
    return validatedIsNabuNet;
  }
  remote_buffer[1] = code & 0xFF;
  remote_buffer[2] = (code >> 8) & 0xFF;
  int len = RemoteCall(2, 2, 3);
  if (len == 9 && (remote_buffer[1] & 1) != 0)  // bit 0 => is valid.
  {
    return (remote_buffer[1] & 2)!=0;
  }
  return false;
}

bool RemoteServerHandler::request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target)
{
  if (!is_connected())
    return false;
  if (validatedCode != channelNumber)
  {
    if (!validate_virtual_server(channelNumber))
      return false;
  }
  if (validatedKernel <=0)
    return false;

  remote_buffer[1] = a1;
  remote_buffer[2] = a2;
  remote_buffer[3] = a3;
  remote_buffer[4] = blockNumber & 0xFF;
  remote_buffer[5] = (blockNumber >> 8) & 0xFF;
  remote_buffer[6] = blockLength & 0xFF;
  remote_buffer[7] = (blockLength >> 8) & 0xFF;
  remote_buffer[8] = validatedKernel & 0xFF;
  remote_buffer[9] = (validatedKernel >> 8) & 0xFF;
  remote_buffer[10] = (validatedKernel >> 16) & 0xFF;
  remote_buffer[11] = (validatedKernel >> 24) & 0xFF;
  remote_buffer[12] = channelNumber & 0xFF;
  remote_buffer[13] = (channelNumber >> 8) & 0xFF;

  int count = RemoteCall(4,13, 5);
  if (count > 0)
  {
    if ((remote_buffer[1] & 0x1)!=0)
    {
      bool last = (remote_buffer[1] & 0x2)!=0;
      int len = remote_buffer[2] | (remote_buffer[3] << 8);
      memcpy(target, remote_buffer + 4, len);
      NabuIO.report_block_for_hcca(blockNumber, len, last);
      return true;
    }
  }
  return false;
}

int extract_int(unsigned char* from)
{
  return from[0] | (from[1] << 8) | (from[2] << 16) | (from[3] << 24);
}

bool RemoteServerHandler::validate_virtual_server(int code)
{
  if (!is_connected())
    return false;
  if (validatedCode == code)
  {
    return true;
  }
  else
  {
    validatedCode = -1;
    validatedKernel = 0;
    validatedLoader = 0;
    validatedIsNabuNet = false;
    remote_buffer[1] = code & 0xFF;
    remote_buffer[2] = (code >> 8) & 0xFF;
    int len = RemoteCall(2, 2, 3);
    if (len == 9 && (remote_buffer[1] & 1) != 0)  // bit 0 => is valid.
    {
      validatedCode = code;
      validatedIsNabuNet = (remote_buffer[1] & 2)!=0; // bit 1 => is nabu net modem server.
      validatedKernel = extract_int(remote_buffer+2);
      validatedLoader = extract_int(remote_buffer+6);
      return true;
    }
  }
  return false;
}

int RemoteServerHandler::RemoteCall(byte sendCode, int sendSize, byte expectedResultCode)
{
  digitalWrite(PIN_LED_NET, LED_ON);
  
  remote_buffer[0] = sendCode;
  Connection->send(remote_buffer, sendSize+1);
  // TODO: handle the "push" messages... timeout in getMessage...
  int t1 = Connection->getMessage(remote_buffer,512);

  digitalWrite(PIN_LED_NET, LED_OFF);

  if(t1 > 1 && remote_buffer[0] == expectedResultCode)
    return t1-1;
  return 0;
}


bool RemoteServerHandler::connect()
{
  if (Connection)
    disconnect();
  Connection = new WebSocketClient(true, ModemConfig.ignore_tls_errors());
  digitalWrite(PIN_LED_NET, LED_ON);
  if (Connection->connect(ModemConfig.ActiveConfig.NetworkHost, ModemConfig.ActiveConfig.NetworkPath, ModemConfig.ActiveConfig.NetworkPort))
  {
    int t1, t2;
    diag("...connected...");
    // handshake...
    // send init-packet #00 - MAC, RQAPI, VERSION, CFGVER
        
    WiFi.macAddress(remote_buffer + 1);
    remote_buffer[7] = 1;  // TODO: SERVER API REQUESTED!
    remote_buffer[8] = t1 = strlen(NABUNET_MODEM_FIRMWARE_VERSION);
    strncpy((char*)(remote_buffer+9), NABUNET_MODEM_FIRMWARE_VERSION, t1);
    remote_buffer[9+t1] = t2 = strlen(ModemConfig.ActiveConfig.ConfigImageVersion);
    strncpy((char*)(remote_buffer + 10 + t1), ModemConfig.ActiveConfig.ConfigImageVersion, t2);
    t1 = RemoteCall(0, 9+t1+t2, 1);
    // expect init-reply #01 - SRVAPI, FLAGS, SERVERNAME
    if (t1 > 3)
    {
      RemoteServerApiLevel = remote_buffer[1];
      RemoteFlags = remote_buffer[2]; 
      
      t2 = remote_buffer[3];
      RemoteServerVersion[32]=0;
      strncpy(RemoteServerVersion, (char*)(remote_buffer + 4), t2 <= 32 ? t2 : 32);
      
      RemoteServerName[32]=0;
      t1 = 4 + t2;
      t2 = remote_buffer[t1];
      strncpy(RemoteServerName, (char*)(remote_buffer + t1 + 1), t2 <= 32 ? t2 : 32);
      
      HasServerInfo = true;
      digitalWrite(PIN_LED_NET, LED_OFF);
      return true;
    }
    else
    {
       diag("reply invalid");
    }
  }
  else
  {
    diag("...failed");
  }
  digitalWrite(PIN_LED_NET, LED_OFF);
  blink_status_confirmed(PIN_LED_ERR, ERROR_SIGNAL_REMOTE_CONN_FAILED);
  return false;
}
