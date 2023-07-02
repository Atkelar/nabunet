#ifndef NABUHANDLERABSTRACTIONH
#define NABUHANDLERABSTRACTIONH

// some base classes for handling communication with the NABU; 
// i.e. "native" or "NabuNet" mode.

#include "Definitions.h"

class NabuIOHandler;

class NabuHandlerBase
{
  public:
    NabuHandlerBase();

    virtual bool handle_buffer(NabuIOHandler* source) = 0;
    virtual bool handle_idle(NabuIOHandler* source) = 0;
    virtual void block_received(int blockNumber, int bytes, bool lastBlock) = 0;

  protected:
    
};

class NabuIOHandler
{
  public:
    NabuIOHandler();
    
    void clear_send();
    void clear_receive();

    void set_active_handler(NabuHandlerBase* newHandler);

    bool handle_received(unsigned char input);
    bool handle_idle();

    bool send_byte(unsigned char what);
    bool flush_send();

    int read_byte();
    int input_length();

    bool request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target);
    void report_block_for_hcca(int blockNumber, int blockLength, bool isFinal);

  private:
    NabuHandlerBase* _ActiveHandler;
    
    // HCCA TX/RX buffers.
    unsigned char SendBuffer[HCCA_BUFFER_SIZE];
    unsigned char ReceiveBuffer[HCCA_BUFFER_SIZE];
    
    int RxStart, RxEnd, TxStart, TxEnd;
   
};

extern NabuIOHandler NabuIO;
#endif
