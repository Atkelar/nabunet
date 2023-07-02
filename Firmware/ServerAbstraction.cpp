
#include "ServerAbstraction.h"
#include "ConfigFile.h"
#include "NabuHandlerAbstraction.h"
#include "Diag.h"

ConfigServerHandler ConfigServerInstance;
LocalServerHandler LocalServerInstance;
RemoteServerHandler RemoteServerInstance;


static ServerHandler* _Current = NULL;


RemoteServerHandler::RemoteServerHandler()
{
  
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

void RemoteServerHandler::disconnect()
{
  
}
bool RemoteServerHandler::connect()
{
  return false;
}
