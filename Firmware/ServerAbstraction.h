#ifndef SERVERABSTRACTIONH
#define SERVERABSTRACTIONH

#include "Definitions.h"
#include "Arduino.h"
#include "WebSocketClient.h"

class ServerHandler;
class ConfigServerHandler;


#define SERVER_FLAG_GUEST 1
#define SERVER_FLAG_LOGIN 2
#define SERVER_FLAG_READONLY 4
#define SERVER_FLAG_VIRTUAL 8


// abstract class for interfacing with different servers: local, remote and config image.
class ServerHandler
{
  public:
    ServerHandler();

    virtual bool validate_virtual_server(int code) = 0;
    virtual bool request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target) = 0;

    virtual bool virtual_server_is_nabunet(int code) = 0;

    virtual bool has_virtual_servers()  = 0;
    virtual unsigned char api_level() = 0;
    virtual bool has_login() = 0;
    virtual bool is_logged_in() = 0;
    virtual bool is_read_only() = 0;
    virtual String server_name() = 0;
    virtual String server_version() = 0;
    virtual bool is_connected() = 0;
    virtual int feature_flags()  = 0;

    static ServerHandler* current();
    static bool set_current(ServerHandler* newTarget);
};

class ConfigServerHandler
  : public ServerHandler
{
  public: 
    ConfigServerHandler();

    bool validate_virtual_server(int code) override 
    {
      return code == 0; // we only support 0 here.
    }

    bool request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target) override;
    bool virtual_server_is_nabunet(int code) override { return true; } 
    
    int feature_flags() override { return SERVER_FLAG_READONLY; }

    bool has_virtual_servers() override { return false; }
    unsigned char api_level() override { return 0; }
    bool has_login() override { return false; }
    bool is_logged_in() override { return false; }
    bool is_read_only() override { return true; }
    String server_name() override { return "Modem Configuration"; }
    String server_version() override { return NABUNET_MODEM_FIRMWARE_VERSION; }
    bool is_connected() override { return ServerHandler::current() == this; }
};


class LocalServerHandler
  : public ServerHandler
{
  public: 
    LocalServerHandler();

    bool validate_virtual_server(int code) override 
    {
      return code == 0; // we only support 0 here.
    }
    bool virtual_server_is_nabunet(int code) override { return true; } 

    int feature_flags() override { return SERVER_FLAG_READONLY; }

    bool request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target) override {return false;}
    bool has_virtual_servers() override { return false; }
    unsigned char api_level() override { return 0; }
    bool has_login() override { return false; }
    bool is_logged_in() override { return false; }
    bool is_read_only() override { return true; }
    String server_name() override { return "Modem Configuration"; }
    String server_version() override { return NABUNET_MODEM_FIRMWARE_VERSION; }
    bool is_connected() override { return false ; }
};

extern const String NotConnectedServerName;
extern const String LoadingServerInfoServerName;
extern const String NotConnectedServerVersion;

class RemoteServerHandler
  : public ServerHandler
{
  public: 
    RemoteServerHandler();

    bool validate_virtual_server(int code) override;

    bool virtual_server_is_nabunet(int code) override; 

    bool request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target) override;
    bool has_virtual_servers() override { return false; }
    unsigned char api_level() override { return RemoteServerApiLevel; }
    bool has_login() override;
    bool is_logged_in() override { return false; }
    bool is_read_only() override { return true; }
    String server_name() override { return is_connected() ? (HasServerInfo ? RemoteServerName : LoadingServerInfoServerName) : NotConnectedServerName; }
    String server_version() override { return is_connected() ? RemoteServerVersion : NotConnectedServerVersion; }
    char* config_image_version();
    char* firmware_image_version();
    bool is_connected() override;
    int feature_flags() override;

    void disconnect();
    bool connect();

  private:
    WebSocketClient* Connection;

    void fetch_image_versions();

    int RemoteServerApiLevel;
    char RemoteServerVersion[33];
    char RemoteServerName[33];
    bool HasServerInfo;
    int RemoteFlags;

    char* RemoteServerConfigImageVersion;
    char* RemoteServerFirmwareImageVersion;

    int validatedCode;
    int validatedKernel;
    int validatedLoader;
    bool validatedIsNabuNet;

    unsigned char* remote_buffer;

    int RemoteCall(byte sendCode, int sendSize, byte expectResultCode);
};

extern ConfigServerHandler ConfigServerInstance;
extern LocalServerHandler LocalServerInstance;
extern RemoteServerHandler RemoteServerInstance;

#endif
