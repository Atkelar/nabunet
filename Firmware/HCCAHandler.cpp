
#include "HCCAHandler.h"
#include "ConfigFile.h"
#include "Utilities.h"
#include "Arduino.h"
#include "ServerAbstraction.h"
#include "Diag.h"
#include "ModemHandler.h"


HCCAHandler::HCCAHandler(bool forceChannelQuery, int channelNumber) : NabuHandlerBase()
{
  State = HCCA_STATE_BOOT;
  ForceChannelQuery = forceChannelQuery;
  ChannelNumber = channelNumber;
}

unsigned char hcca_transfer_buffer[300];

bool HCCAHandler::handle_buffer(NabuIOHandler* source) 
{
  int readByte;
  
  switch (State)
  {
    case HCCA_STATE_BOOT:
      readByte = source->read_byte();
      if (readByte == 0x83)
      {
        // we got the init sequence;
        source->clear_send();
        source->send_byte(0x10);
        source->send_byte(0x06);
        source->send_byte(0xe4);
        source->clear_receive(); // need to make sure we start over for the next byte in the sequence...
        State = HCCA_STATE_INIT_1;
      }
//      else
//        source->clear_receive(); // in "boot" state, we just ignore everything else to avoid buffer overflows.
      break;
    case HCCA_STATE_INIT_1:
      // wait for command code 0x82... ignore anything else...
      readByte = source->read_byte();
      if (readByte == 0x82)
      {
        source->clear_send();
        source->send_byte(0x10);
        source->send_byte(0x06);
        State = HCCA_STATE_INIT_2;
      }
      else
        if(readByte != -1)
          State = HCCA_STATE_BOOT;
      break;
    case HCCA_STATE_INIT_2:
      // wait for command code 0x01... ignore anything else...
      readByte = source->read_byte();
      if (readByte == 0x01)
      {
        source->clear_send();
        // now we get dynamic...
        if (ForceChannelQuery || (ServerHandler::current()->has_virtual_servers() && !ServerHandler::current()->validate_virtual_server(ChannelNumber)))
        // we need no prompt in servicing mode, this will be "0000" channel anyway...
          source->send_byte(0x80);
        else
          source->send_byte(0x00);
        
        source->send_byte(0x10);
        source->send_byte(0xe1);
        State =  ForceChannelQuery ? HCCA_STATE_WAIT_FOR_CODE : HCCA_STATE_WAIT_FOR_BOOT;
      }
      else
        if(readByte != -1)
          State = HCCA_STATE_BOOT;
      break;
    case HCCA_STATE_WAIT_FOR_CODE:
      readByte = source->read_byte();
      if (readByte == 0x85)
      {
        source->send_byte(0x10);
        source->send_byte(0x06);
        State = HCCA_STATE_RECEIVE_CODE;
      }
      else
        if (readByte != -1)
        {
          // stay here...
        }
      break;
    case HCCA_STATE_RECEIVE_CODE:
      if (source->input_length() >= 2)
      {
        ChannelNumber = source->read_byte() << 8;
        ChannelNumber |= source->read_byte();
        bool codeIsValid = false;
        if (ChannelNumber != 0)
        {
          codeIsValid = ServerHandler::current()->has_virtual_servers() && ServerHandler::current()->validate_virtual_server(ChannelNumber);
        }
        else
          codeIsValid = true; // channel zero MUST be supported by all servers.
        if (codeIsValid)
        {
          source->send_byte(0xE4);  // send confirmation...
          State = HCCA_STATE_WAIT_FOR_BOOT;
        }
        else
        {
          source->send_byte(0xFF);  // send failed...
          State = HCCA_STATE_BOOT;
        }
      }
      break;
    case HCCA_STATE_WAIT_FOR_BOOT:
      readByte = source->read_byte();
      if (readByte == 0x81)
      {
        source->send_byte(0x10);
        source->send_byte(0x06);
        State = HCCA_STATE_BOOT_REQUESTED;
      }
      break;
    case HCCA_STATE_BOOT_REQUESTED:
      readByte = source->read_byte();
      if (readByte == 0x8F)
      {
        State = HCCA_STATE_BOOT_RUNNING;
      }
      else
      {
        if (readByte >=0)
        {
          State = HCCA_STATE_WAIT_FOR_BOOT;
        }
      }
      // NABU does ROM->RAM copy now and shows "PLEASE WAIT" before continuing;
      break;
    case HCCA_STATE_BOOT_RUNNING:
      readByte = source->read_byte();
      if (readByte == 5)
      {
        source->send_byte(0xE4);
        State = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;
        // This should now tritter the "please wait" message on the NABU...
      }
      else
      {
        if (readByte != -1)
        {
          source->send_byte(0x06);  // NOT E4, should cause error.
          State = HCCA_STATE_WAIT_FOR_BOOT;
        }
      }
      break;
    case HCCA_STATE_WAIT_FOR_BLOCK_REQUEST:
      // this is the command to load a block by a number; 
      // likely 0x00 00 01 ?? for the main program,
      // where ?? is incremented from 0 efter every "not last" block.
      // NOTE: this one might also transition to HCCA_STATE_RUN eventually, 
      // because it's basically the last known command that boots the OS.
      readByte = source->read_byte();
      if (readByte == 0x84)
      {
        source->send_byte(0x10);
        source->send_byte(0x06);
        State = HCCA_STATE_WAIT_FOR_BLOCK_NUM;
      }
      else
      {
        if (readByte != -1)
        {
          if (readByte == 0 && ServerHandler::current()->virtual_server_is_nabunet(ChannelNumber))
          {
            Modem.switch_mode_nabunet();
            return source->handle_received(0);
          }
          source->send_byte(0x00);
          State = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;  // try to re-sync...
        }
      }
      break;
    case HCCA_STATE_WAIT_FOR_BLOCK_NUM:
      if (source->input_length() >= 4)    // get 4 bytes, first is block number (0..n) second-fourth unknown, but 1-0-0 now.
      {
        readByte = source->read_byte();
        RequestedBlockNumber = readByte;
        BlockReady = false;
        unsigned char a1 = source->read_byte();
        unsigned char a2 = source->read_byte();
        unsigned char a3 = source->read_byte();
        source->send_byte(0xE4);
        if (!source->request_block_for_hcca(ChannelNumber, a1, a2, a3, RequestedBlockNumber, 256, hcca_transfer_buffer + 0x10))  // TODO: add transfer buffer!!
        {
          State = HCCA_STATE_WAIT_FOR_BLOCK_NUM;
          // we failed for the block request..
          // if the 91 code takes too long (about 5 seconds) the load is aborted
          // and the "see "if something goes wrong" in the owners guide"
          // message is shown.
          source->send_byte(0xFF);
        }
        else
        {
          State = HCCA_STATE_SEND_BLOCK;
        }
      }
      break;
    case HCCA_STATE_SEND_BLOCK_GO:
      if (source->input_length() >= 2)
      {
        readByte = source->read_byte();
        if (readByte != 0x10)
        {
          State = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;
          break;
        }
        readByte = source->read_byte();
        if (readByte != 0x6)
        {
          State = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;
          break;
        }
       
        for(int i = 0; i < SendBlockSize; i++)
        {
          source->send_byte(hcca_transfer_buffer[i]);
          
          if (hcca_transfer_buffer[i] == 0x10)  // escape 0x10...
            source->send_byte(0x10);
        }
        source->send_byte(0x10);
        source->send_byte(0xe1);
  
        State = HCCA_STATE_WAIT_FOR_BLOCK_REQUEST;   // even at the last loaded block, wait for another one, it might be the last one is broken...
      }
      break;
    case HCCA_STATE_RUN:
      break;
      // We got the Nabu PC with a proper control program now, anything should happen within this section now.
      // TODO: handle actual requests... might need reworking when we have info about the old NABU protocol...
      //if (handle_nabunet_communication())
        //return hcca_flush();
      // TODO: here we have the boot loader deployed; depending on the server, either we will be called as "native"
      // Modem or the hosting implementation will switch to the NabuNet handler...
  }
  return true;
}

void HCCAHandler::block_received(int blockNumber, int bytes, bool lastBlock)
{
  if(blockNumber == RequestedBlockNumber) // we ignore any mis-sent block...
  {
    IsLastBlock = lastBlock;
    BlockReadBytes = bytes;
    BlockReady = true;
  }

}

bool HCCAHandler::handle_idle(NabuIOHandler* source)
{
  switch (State)
  {
    case HCCA_STATE_SEND_BLOCK:
      if (BlockReady)
      {
        memset(hcca_transfer_buffer, 0, 0x10);  // clear "header"..
  
        // TODO: use callback for loading block; either from remote server, local server or local config program...
  //      if (IsServicingMode) // in servicing mode, we force to the boot channel...
    //    {
          //isLastBlock = read_block_from_config_image(HCCARequestedBlockNum, &readByteCount, shared_buffer + 0x10);
        //}
      //  else 
          //return false;  // TODO
  
        hcca_transfer_buffer[0xb] = IsLastBlock ? 0x10 : 0; // set "last block" flag...
  
        append_crc16(hcca_transfer_buffer, BlockReadBytes + 0x12);
  
        // we done loading the block! Send other code on load fail here!
        // if the 91 code takes too long (about 5 seconds) the load is aborted
        // and the "see "if something goes wrong" in the owners guide"
        // message is shown.
        source->send_byte(0x91);
  
        SendBlockSize = BlockReadBytes + 0x12;
  
        State = HCCA_STATE_SEND_BLOCK_GO; // here we wait for input again...
        BlockReady = false; // make sure we don't get trapped again...
      }
      break;
  }
  return true;
}
