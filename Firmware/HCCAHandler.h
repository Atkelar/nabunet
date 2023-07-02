#ifndef HCCAHANDLERH
#define HCCAHANDLERH

#include "NabuHandlerAbstraction.h"

// *************** HCCA communication handler

// The communication with the NABU is done in a state machine. That way, we can switch between
// states in the individual control loops at any time; Note that the main loop will run the
// hcca_ methods on every loop, so "hopping" from one to the other state is simply done by
// changing to the desired new one and exiting the current loop.
// This is done so that the WiFi and IP core can get as many chances to wake up as possible.
// And also we try to avoid the watchdogs!
#define HCCA_STATE_BOOT 0
#define HCCA_STATE_CONTACTED 1
#define HCCA_STATE_INIT_1 2
#define HCCA_STATE_INIT_2 3
#define HCCA_STATE_WAIT_FOR_CODE 4
#define HCCA_STATE_WAIT_FOR_BOOT 5
#define HCCA_STATE_SEND_BLOCK 6
#define HCCA_STATE_RECEIVE_CODE 7
#define HCCA_STATE_BOOT_REQUESTED 8
#define HCCA_STATE_BOOT_RUNNING 9
#define HCCA_STATE_WAIT_FOR_BLOCK_REQUEST 10
#define HCCA_STATE_WAIT_FOR_BLOCK_NUM 11
#define HCCA_STATE_RUN 13
#define HCCA_STATE_SEND_BLOCK_GO 14

class HCCAHandler
  : public NabuHandlerBase
{
  public:
    HCCAHandler(bool forceChannelQuery, int channelNumber);

    bool handle_buffer(NabuIOHandler* source) override;
    bool handle_idle(NabuIOHandler* source) override;

    void block_received(int blockNumber, int bytes, bool lastBlock) override;

  private:
    int State;
    bool ForceChannelQuery;
    int ChannelNumber;

    int RequestedBlockNumber;
    bool BlockReady;
    int BlockReadBytes;
    bool IsLastBlock;
    int SendBlockSize;
  
};


#endif
