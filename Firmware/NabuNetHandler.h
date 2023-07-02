#ifndef NABUNETAHANDLERH
#define NABUNETAHANDLERH

#include "NabuHandlerAbstraction.h"
#include <ESP8266WiFi.h>

// NabuNet state machine values
#define NN_STATE_UNKNOWN 0
#define NN_STATE_CONNECTING 1
#define NN_STATE_CONNECTED 2
#define NN_STATE_ERROR 3


class NabuNetHandler
  : public NabuHandlerBase
{
  public:
    NabuNetHandler(bool servicing);

    bool handle_buffer(NabuIOHandler* source) override;
    bool handle_idle(NabuIOHandler* source) override;

    void block_received(int blockNumber, int bytes, bool lastBlock) override;
    
    void reset();

  private:
    bool handle_modem_config_command(NabuIOHandler* source, bool isReply, unsigned char* payload, int payloadLength);
    void set_error();
    bool send_packet(NabuIOHandler* source, unsigned char code, bool isReply, unsigned char* bufferAddress, int bufferLength);

    int State;
    bool IsServicing;

    // NabuNet specific modem status...
    unsigned long Started;
    bool Incoming;
    int Checksum;
    unsigned char Code;
    bool IsReply;
    bool HasPayload;
    bool RxDone;
    int PayloadLength;
    int PayloadOffset;
    int ConnectToken;
    bool ConnectInitiated;
    unsigned char Rx_Payload[128];

    // config program specific variables...
    char ReportedConfigProgramVersion[33];
    bool wifi_ScanRunning;
    int wifi_scan_current_page;
    int wifi_scan_page_size;
};


#endif
