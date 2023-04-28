# Research about the Nabu boot ROM

## Boot process, overview

At a high level, the boot process is as follows: Set up the ROM execution environment, 
initialize the support chips, and in case of a cold boot, perform a series of hardware
checks. Then, initialize the cable modem, and prompt the user for the channel code 
if the modem wants it. The last step is for it to load the actual "OS" from the 
modem and pass excution to that. While the IO devices are all connected with the 
interrupt system, the boot loader uses polling to wait for a required condition 
instead. *opinion: I think this is to avoid any non-linear code paths in the ROM code.*

![Flow chart of high level operation](BootProcess.png?raw=true "Flowchart")
