/*
 * 
 * main header for the firmware definition; 
 * all class definitions and globals are in here, to keep them together.
 * 
 * 
 * 
 */

#ifndef NABUNETFIRMWARE
#define NABUNETFIRMWARE

//  ***********************   Includes for general libraries....

// Yes, we want to connect to the WiFi...
#include <ESP8266WiFi.h>

// We need to avoid clashing with the SD File class later...
#define FS_NO_GLOBALS
// ...which would happen if we just include FS.h
#include <FS.h>


// Tried to use the "SD" library... did NOT work, even after three full days of scope diagnostics...
// it might clash with the FS library, or other somesuch nice effects. SdFat works, even with larger SD cards.
#include <SdFat.h>


// ************************ specific feature includes...

#include "Definitions.h"
#include "Diag.h"
#include "ConfigFile.h"
#include "ModemHandler.h"
#include "Utilities.h"

//  ***********************  Constants


#endif
