#ifndef MODEMHANDLERH
#define MODEMHANDLERH

#include "Diag.h"

// ****************  Modem State Machine; this is the high-level functionallity of the system

// Overall modem state codes.
#define STATE_BOOT 0
#define STATE_RUN 1
#define STATE_SERVICING 2
#define STATE_CONNECT_SD 3
#define STATE_CONNECT_WIFI 4
#define STATE_CONNECTING_WIFI 5
#define STATE_START 6
#define STATE_CONNECT_REMOTE_SERVER 7

#define STATE_ERROR 0xFF

class NabuIOHandler;

class NabuNetModem
{
  public:
    // called during the hardware init phase to start up low level hadware connections.
    void init();

    // called once every "loop"; handle state machine processing and return "false" for fatal error (will reboot!)
    bool handle_state_loop();

    void panic_now(int code);
    int panic_code();

    void wifi_disconnected();
    void wifi_connected();

    bool has_wifi();

    void switch_mode_nabunet();
    
  private:
    bool wait_signal_released();
    bool confirm_install_setup_image();
    bool check_setup_image_on_card();
    void replace_setup_image_from_card();
    bool handle_modem_running();
    bool check_and_initilize_local_server();
    bool check_and_initilize_wifi();
    bool check_and_initilize_remote_server();
    

    int ModemState;
    int PanicCode;
    bool SDCardDetected;
    // State change indicator helpers...
    // specifically, the "reset" modem command sequence: 0x83, 0x83, 0x83, 0x83, 0x81, etc... with at least 500ms delay in between is important...
    int HCCAResetSequenceCount;
    unsigned long LastHCCAInput;
    int LastHCCAByte;

    
    // operational varaibles...
    bool ForceChannelQuery;
    bool LocalServerAvailbale;
    bool RemoteServerAvailable;
    bool WiFiAvailable;
    bool WiFiConnected;
    bool IsServicingMode;

    int WiFiConnectTimeout;
};

extern NabuNetModem Modem;

#endif
