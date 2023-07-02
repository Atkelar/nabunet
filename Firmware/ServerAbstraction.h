#ifndef SERVERABSTRACTIONH
#define SERVERABSTRACTIONH

#include "Definitions.h"
#include "Arduino.h"

class ServerHandler;
class ConfigServerHandler;

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
    virtual bool virtual_server_is_nabunet(int code) override { return true; } 

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
    virtual bool virtual_server_is_nabunet(int code) override { return true; } 

    bool request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target) override {return false;}
    bool has_virtual_servers() override { return false; }
    unsigned char api_level() override { return 0; }
    bool has_login() { return false; }
    bool is_logged_in() { return false; }
    bool is_read_only() { return true; }
    String server_name() { return "Modem Configuration"; }
    String server_version() { return NABUNET_MODEM_FIRMWARE_VERSION; }
    bool is_connected() { return false ; }
};

class RemoteServerHandler
  : public ServerHandler
{
  public: 
    RemoteServerHandler();

    bool validate_virtual_server(int code) override 
    {
      return code == 0; // we only support 0 here.
    }

    virtual bool virtual_server_is_nabunet(int code) override { return true; } 

    bool request_block_for_hcca(int channelNumber, unsigned char a1, unsigned char a2, unsigned char a3, int blockNumber, int blockLength, void * target) override {return false;}
    bool has_virtual_servers() override { return false; }
    unsigned char api_level() override { return 0; }
    bool has_login() { return false; }
    bool is_logged_in() { return false; }
    bool is_read_only() { return true; }
    String server_name() { return "Modem Configuration"; }
    String server_version() { return NABUNET_MODEM_FIRMWARE_VERSION; }
    bool is_connected() { return false; }

    void disconnect();
    bool connect();
};

extern ConfigServerHandler ConfigServerInstance;
extern LocalServerHandler LocalServerInstance;
extern RemoteServerHandler RemoteServerInstance;

#endif
