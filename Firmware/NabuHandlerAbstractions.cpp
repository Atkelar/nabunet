
#include "NabuHandlerAbstraction.h"

#include "Definitions.h"
#include "Arduino.h"
#include "ServerAbstraction.h"

NabuIOHandler NabuIO;

NabuHandlerBase::NabuHandlerBase()
{
  
}

NabuIOHandler::NabuIOHandler()
{
  _ActiveHandler = NULL;
  RxStart = RxEnd = TxStart = TxEnd = 0;
}

void NabuIOHandler::report_block_for_hcca(int blockNumber, int blockLength, bool isFinal)
{
  if (_ActiveHandler)
    _ActiveHandler->block_received(blockNumber, blockLength, isFinal);
}

void NabuIOHandler::clear_send()
{
  TxStart = TxEnd = 0;
}
void NabuIOHandler::clear_receive()
{
  RxStart = RxEnd = 0;
}

void NabuIOHandler::reset_handler()
{
  if (_ActiveHandler)
    _ActiveHandler->reset_handler();
}

void NabuIOHandler::set_active_handler(NabuHandlerBase* newHandler)
{
  if (_ActiveHandler)
    delete _ActiveHandler;
  _ActiveHandler = newHandler;
}

bool NabuIOHandler::request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target)
{
  return ServerHandler::current()->request_block_for_hcca(channelNumber, a1, a2, a3, blockNumber, blockLength, target);
}

bool NabuIOHandler::handle_received(unsigned char input)
{
  int bufEnd = (RxEnd + 1) % HCCA_BUFFER_SIZE;
  if (bufEnd == RxStart)  // overflow!
    return false;

  ReceiveBuffer[RxEnd] = input;
  RxEnd = bufEnd;
  if (_ActiveHandler)
    return _ActiveHandler->handle_buffer(this);
  return true;
}

bool NabuIOHandler::handle_idle()
{
  if (_ActiveHandler)
    return _ActiveHandler->handle_idle(this);
  return true;
}

bool NabuIOHandler::send_byte(unsigned char what)
{
  int bufEnd = (TxEnd + 1) % HCCA_BUFFER_SIZE;
  if (bufEnd == TxStart)  // overflow!
    return false;

  SendBuffer[TxEnd] = what;
  TxEnd = bufEnd;
  return true;
}
bool NabuIOHandler::flush_send()
{
  while (TxStart != TxEnd)
  {
    delay(1);  // tune...
  #ifndef DISABLE_HCCA
    Serial.write(SendBuffer[TxStart]);
  #else
    Serial.print(SendBuffer[TxStart], HEX);
  #endif
    TxStart = (TxStart + 1) % HCCA_BUFFER_SIZE;
  }
  return true;  
}

int NabuIOHandler::read_byte()
{
  if (RxStart == RxEnd)
    return -1;
  int value = ReceiveBuffer[RxStart];
  RxStart = (RxStart + 1) % HCCA_BUFFER_SIZE;
  return value;
}

int NabuIOHandler::input_length()
{
  if (RxStart == RxEnd)
    return 0;
  if (RxEnd > RxStart)
    return RxEnd - RxStart;
  return (HCCA_BUFFER_SIZE + RxEnd) - RxStart;
}
