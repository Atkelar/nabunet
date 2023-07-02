
#include "ServerAbstraction.h"
#include "ConfigFile.h"
#include "NabuHandlerAbstraction.h"
#include "Diag.h"
#include "Utilities.h"
#include <ESP8266WiFi.h>


ConfigServerHandler ConfigServerInstance;
LocalServerHandler LocalServerInstance;
RemoteServerHandler RemoteServerInstance;


static ServerHandler* _Current = NULL;


RemoteServerHandler::RemoteServerHandler()
{
  Connection = NULL;
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
  RemoteServerApiLevel = 0;
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
    shared_buffer[0] = 0;
    WiFi.macAddress(shared_buffer + 1);
    shared_buffer[7] = 1;  // TODO: SERVER API REQUESTED!
    shared_buffer[8] = t1 = strlen(NABUNET_MODEM_FIRMWARE_VERSION);
    strncpy((char*)(shared_buffer+9), NABUNET_MODEM_FIRMWARE_VERSION, t1);
    shared_buffer[9+t1] = t2 = strlen(ModemConfig.ActiveConfig.ConfigImageVersion);
    strncpy((char*)(shared_buffer + 10 + t1), ModemConfig.ActiveConfig.ConfigImageVersion, t2);
    Connection->send(shared_buffer, 10+t1+t2);
    // expect init-reply #01 - SRVAPI, FLAGS, SERVERNAME
    t1 = Connection->getMessage(shared_buffer,128);
    if (t1 > 4 && shared_buffer[0] == 1)
    {
      RemoteServerApiLevel = shared_buffer[1];
      t2 = shared_buffer[2]; 
      // TODO: flags...
      t2 = shared_buffer[3];
      strncpy(RemoteServerVersion, (char*)(shared_buffer + 4), t2);
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
