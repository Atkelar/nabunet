# nabunet - Modem and Network Specifications
My idea of a network backend for the "Nabu PC" - based on reverse engineering the old device and boot code...

The big question first: **why?** or **why not join any of the other similar projects?** simple: fun! For
me, most of the fun is the reverse engineering and coming-up-with-solutions phase. So joining some
other project here wouldn't do it for me... it is as simple as that. I hope that my view/take provides
something at least remotely unique and if public interest is low... I'll keep it to myself, but I'll
not stop just because "somebody else already did something similar" :)


## Revisions

  - Initial version, 2023-04-23

## References used

  - https://en.wikipedia.org/wiki/NABU_Network
  - https://bitsavers.org/pdf/nabu/Nabu_Computer_Technical_Manual_by_MJP.pdf

Other than those, the only information used was the original chips datasheets; Z-80, TR1863/1865, TMS9918A, AY-3-8910, 9637, 9639 and LS74-logic.

## Introduction

The basic idea for the "modem" is to hook up the Nabu Personal Computer (NPC, Nabu) to the internet.
Since Nabu is an 8-bit system with "just" 64k of RAM and the hookup has to be done via the built in
111kbit serial port, we cannot expect that the NPC is doing any heavy lifting (or any lifting) that
is required to connect to any IP based service directly these days, while still having enough
resources for any functional useful program left. The encryption code and state data alone is probably
eating up all of that RAM.

The modem should - IMHO - also be kept as simple as possible, ideally just forwarding any request
and response to an upstream server. But, at the least, do that already in an encrypted format, so
it supports direct internet connections via established, modern and available connectivity.

So, my idea in a nutshell: do all the required processing in a web service, where resources are plenty,
and let the modem do a very basic, simple translation of the requests/responses.

## High Level Operation

### Booting

The NPC "boots" into a 4k ROM module, although there seem to be 8k versions prepared too. Not sure if
these are ever implemented...

The ROM will initialize the support chips, do a functional check on all components (RAM, ROM, Sound, 
Keyboard and Modem chips) and then start to talk with the modem.

The first request to the modem are (assumed to be) initialization and synchronization commands.

The next command sent will reply with a flag bit either set or cleared to indicate if the modem has
the "channel code" set. This will tune the original cable modem to the appropriate channel but is
only kept in RAM. So a cold boot of the modem will not have that info.

If the modem is lacking the channel code, the NPC prompts the user to enter one. This is a five
digit hex code (00000 to FFFFF) but the last digit is a checksum, resulting in 65536 possible
channels to pick from. No range validation is performed here, and "all zero" is a valid code
that passes the checksum.

Once the channel code is entered, it is sent to the modem and the NPC waits for confirmation.

If either checksum or modem ack fails, the user is prompted to re-enter the code.

Once the modem has the channel code set, the NPC will request the "main program" as a sequence
of blocks. The buffer size that is set aside for loading them led to the assumption that
these blocks are up to 512 bytes in length each, with 16 bytes header and 2 bytes checksum
at the end.

The checksum is a derivative of the CRC-16 CCITT checksum, sometimes referred to as the "BAD"
implementation.

The only header bit used by boot loader is the "completed" bit, that indicates that the transferred
block was the last one of the sequence. Until that one is set, all blocks (without the header!)
are moved into RAM to offset 140Dh and on.

Note that the blocks can have arbitrary sizes, the "end of block" is signalled with a terminating
"10h" byte, followed by any other byte than "10h", with "0E1h" indicating success. Thus, the byte
sequence "10h E1h" terminates the block. To include a "10h" byte inside the payload, it has to
be escaped, i.e. "10h 10h" results in one "10h" byte to be loaded and checksum'd.

Once all blocks are received, the ROM is copied into the same RAM address and turned off, making
the byte range R/W from regular RAM but keeping the ROM code intact for rebooting the system. 
Execution is then passed to address 140Fh - note that it is two bytes AFTER the load offset and 
a rather odd address to start from...

### Boot loader code and "OS" idea...

To use the built in boot loader, we have to make use of the channel code somehow; my idea is to 
have the "00000" code provide a basic "initialize modem parameters" program. This is easy to
remember and can be used to set up the internet facing parameters, like server address to use,
SSID and key for WiFi, IP config for wired... these type of things.

Once set up, the modem can "pretend" to know the channel code, thus skipping the prompt.

To re-configure the modem, it should have a type of "reset" button; while a simple modem
reboot would serve the same purpose, I think it's a better idea to allow storing the modem
config in NVRAM somewhere to avoid the rather lengthy server/IP config every time...

The program provided for a known channel ID can then already be a "core OS", provided either
in parts or completely by the selected server.

### Security?!

Note: Any mandatory login or authentication beyond the server configuration is.. well...
taking away from the immersion of "ye-old-device". To keep the server somewhat secure and
proper suited for a modern internet with lots of bad players, the access to the information
available via the modem is considered "mostly read only" and "public"!

Once the modem is connected to the server with the proper credentials validated, the modem
will run with a simple "shared access token" against that server. This is by no means
"secure" and thus no highly sensitive information should ever be stored inside that 
environment! I'm talking personal information like credit card numbers and similar things.

Passing such information through the network to a server sided "callback" that does not
store anything inside the NPC accessible ranges should be fine, since the modem would
connect to the server via TLS... This still needs a proper security analysis of the
finished system though, so better assume that anything you enter into an application
will eventually become "public".

### Servers...

It is possible to use "physical" and "logical" servers. In order to function, the 
"channel zero" initialization has to point the modem to a physical server. During the
setup and configuration phase, that server can tell the modem if it supports "virtual"
servers. To keep the specs simple, there can be up to "FFF0h" virtual servers defined
per physical server, the numbers 1-F being reserved for "internal servers" if this
feature is enabled on the physical server... I'm thinking of "developer" and "diag"
servers mostly... If the physical server does NOT support virtual servers, it is
automaticalls assumed to be a single pre-selected virtual server for the rest of this
specification.

### Virtual Server

Each virtual server is a walled off environment, akin to a cable network. The main
purpose is to provide individual OS kernels during the boot process.

To switch to a differnet virtual server, a special reboot command is needed to tell
the modem to "forget" the current channel code. When the user is then prompted to
re-type the channel code, they can either use 00000 to go to the physical configuration
or any other number - if supported - to switch to another virtual server. The ROM
code doesn't have that provision to "force selection", this has to be done with
a flag in the modem;

I am also considering to have a "Nabu compatible" mode that keeps the communication 
between NPC and Modem 100% compatible with the original protocol, but that depends 
on me FINDING the specs for that protocol first... the problem here is that I don't
know if the original software would have an option to re-enter the channel code?
At worst case, the modem reset button would have to be used...

### DOS or not DOS?

The specs call the OS "DOS" for "Downloadable OS"... in contrast to the integrated
OS that boots the system. I am working on a reasonable implementation for simple
access to the different screen modes, sound chip and peripherals like the printer
port. My goal is to keep that OS below at least the 32k boundary, so the upper 32k
would always be available for program code. This doesn't sound like much, but keep
in mind that "loading a block from tape" or similar can now be considered "load
a block from the internet" at speeds that these devices are not used to. I think
almost any program can be made like that; The final decision on the memory 
requirements of the OS kernel are not set yet, so it might as well be much more.

Programs that make use of that "standard OS" could have simplified load code
provided, with a program browser as an initial app loaded from the server...

### R/W access?

A downside of the original NPC was the lack of storage space. But this is the age
of "cloud computing"... as much as I personally dislike that concept, it does
fit well with this system. During connection of the NPC with the server, personal
user info can be provided (think user/password) and when successful, the server
can provide storage space for that account. Note that the physical server can
choose if that space applies to logical servers and what part is server specific...
NPC doesn't see that difference. This would allow programs like - e.g. - a BASIC
interpreter to save/load programs from a "virtual disk" with ease.

To keep the stored information as secure as possible, the server will allow access
based on an access policy (private, server only, public) based on "virtual disk"
units. This would allow sharing information or keeping it private.

The resulting security model would however make it possible to use a guessed or
hijacked token to write to or just erase that information... to safeguard against
that possibility, a "snapshot" based system should be implemented on the server,
where these snapshots are invisible to the NPC and only controllable via the regular
internet facing, browser based management UI of your account. This should mitigate
any "attack" to the "less secure" data inside your Nabu Storage...

### Server software

Once sufficiently mature - i.e. as soon as it works at least a little bit :) - the 
server software along with the core OS will be published here as an open source 
project.

The overall concept would see it that anybody can code against the NPC and provide
their applications to the server(s) running this software.

I am - naturally - looking into hosting one of these myself as a "central default"
server...
