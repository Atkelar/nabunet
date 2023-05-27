EESchema Schematic File Version 4
EELAYER 30 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 1 1
Title "NABU Modem Drop In"
Date "2023-05-05"
Rev "1"
Comp "Atkelar"
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L Interface_LineDriver:UA9637 U2
U 1 1 643FB8B7
P 8375 2075
F 0 "U2" H 8250 2450 50  0000 C CNN
F 1 "UA9637" H 8175 2350 50  0000 C CNN
F 2 "Package_DIP:DIP-8_W7.62mm" H 8375 1675 50  0001 C CNN
F 3 "http://pdf.datasheetcatalog.com/datasheets2/28/284473_1.pdf" H 8375 2075 50  0001 C CNN
	1    8375 2075
	-1   0    0    -1  
$EndComp
$Comp
L Interface_LineDriver:UA9638CD U3
U 1 1 643FBCE6
P 8500 3725
F 0 "U3" H 8475 4125 50  0000 C CNN
F 1 "UA9638CD" H 8600 4025 50  0000 C CNN
F 2 "Package_DIP:DIP-8_W7.62mm" H 8500 3225 50  0001 C CNN
F 3 "http://www.ti.com/lit/ds/symlink/ua9638.pdf" H 8500 3725 50  0001 C CNN
	1    8500 3725
	1    0    0    -1  
$EndComp
$Comp
L Regulator_Linear:AP1117-33 U5
U 1 1 64449CCB
P 1350 4750
F 0 "U5" H 1350 4992 50  0000 C CNN
F 1 "AP1117-33" H 1350 4901 50  0000 C CNN
F 2 "Package_TO_SOT_SMD:SOT-223-3_TabPin2" H 1350 4950 50  0001 C CNN
F 3 "http://www.diodes.com/datasheets/AP1117.pdf" H 1450 4500 50  0001 C CNN
	1    1350 4750
	1    0    0    -1  
$EndComp
$Comp
L Connector:USB_C_Receptacle J1
U 1 1 6444A5E0
P 1375 2350
F 0 "J1" H 1482 3617 50  0000 C CNN
F 1 "USB_C_Receptacle" H 1482 3526 50  0000 C CNN
F 2 "Atkelar_Custom:USB_C_Receptacle_Amphenol_12401548E4-2A-X" H 1525 2350 50  0001 C CNN
F 3 "https://www.usb.org/sites/default/files/documents/usb_type-c.zip" H 1525 2350 50  0001 C CNN
	1    1375 2350
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0101
U 1 1 64453186
P 1375 4175
F 0 "#PWR0101" H 1375 3925 50  0001 C CNN
F 1 "GND" H 1380 4002 50  0000 C CNN
F 2 "" H 1375 4175 50  0001 C CNN
F 3 "" H 1375 4175 50  0001 C CNN
	1    1375 4175
	1    0    0    -1  
$EndComp
$Comp
L power:VCC #PWR0102
U 1 1 6445389B
P 2125 1175
F 0 "#PWR0102" H 2125 1025 50  0001 C CNN
F 1 "VCC" H 2142 1348 50  0000 C CNN
F 2 "" H 2125 1175 50  0001 C CNN
F 3 "" H 2125 1175 50  0001 C CNN
	1    2125 1175
	1    0    0    -1  
$EndComp
$Comp
L power:VDD #PWR0103
U 1 1 64453FFD
P 1850 4725
F 0 "#PWR0103" H 1850 4575 50  0001 C CNN
F 1 "VDD" H 1867 4898 50  0000 C CNN
F 2 "" H 1850 4725 50  0001 C CNN
F 3 "" H 1850 4725 50  0001 C CNN
	1    1850 4725
	1    0    0    -1  
$EndComp
Wire Wire Line
	2125 1175 2125 1350
Wire Wire Line
	2125 1350 1975 1350
Wire Wire Line
	1375 3950 1375 4050
Wire Wire Line
	1075 3950 1075 4050
Wire Wire Line
	1075 4050 1375 4050
Connection ~ 1375 4050
Wire Wire Line
	1375 4050 1375 4175
Wire Wire Line
	1850 4725 1850 4750
Wire Wire Line
	1850 4750 1650 4750
$Comp
L power:VCC #PWR0104
U 1 1 64462047
P 825 4700
F 0 "#PWR0104" H 825 4550 50  0001 C CNN
F 1 "VCC" H 842 4873 50  0000 C CNN
F 2 "" H 825 4700 50  0001 C CNN
F 3 "" H 825 4700 50  0001 C CNN
	1    825  4700
	1    0    0    -1  
$EndComp
Wire Wire Line
	825  4700 825  4750
Wire Wire Line
	825  4750 1050 4750
$Comp
L power:GND #PWR0105
U 1 1 644629E7
P 1350 5375
F 0 "#PWR0105" H 1350 5125 50  0001 C CNN
F 1 "GND" H 1355 5202 50  0000 C CNN
F 2 "" H 1350 5375 50  0001 C CNN
F 3 "" H 1350 5375 50  0001 C CNN
	1    1350 5375
	1    0    0    -1  
$EndComp
$Comp
L Device:CP C2
U 1 1 64463635
P 1850 5050
F 0 "C2" H 1968 5096 50  0000 L CNN
F 1 "10µ" H 1968 5005 50  0000 L CNN
F 2 "Capacitor_SMD:C_2512_6332Metric_Pad1.52x3.35mm_HandSolder" H 1888 4900 50  0001 C CNN
F 3 "~" H 1850 5050 50  0001 C CNN
	1    1850 5050
	1    0    0    -1  
$EndComp
$Comp
L Device:CP C1
U 1 1 64463DBC
P 825 5050
F 0 "C1" H 943 5096 50  0000 L CNN
F 1 "22µ" H 943 5005 50  0000 L CNN
F 2 "Capacitor_SMD:C_2512_6332Metric_Pad1.52x3.35mm_HandSolder" H 863 4900 50  0001 C CNN
F 3 "~" H 825 5050 50  0001 C CNN
	1    825  5050
	1    0    0    -1  
$EndComp
Wire Wire Line
	825  4900 825  4750
Connection ~ 825  4750
Wire Wire Line
	1850 4900 1850 4750
Connection ~ 1850 4750
Wire Wire Line
	1850 5200 1850 5250
Wire Wire Line
	1850 5250 1350 5250
Wire Wire Line
	825  5250 825  5200
Wire Wire Line
	1350 5375 1350 5250
Connection ~ 1350 5250
Wire Wire Line
	1350 5250 825  5250
Wire Wire Line
	1350 5050 1350 5250
NoConn ~ 1975 1850
NoConn ~ 1975 1950
NoConn ~ 1975 2050
NoConn ~ 1975 2150
NoConn ~ 1975 2350
NoConn ~ 1975 2450
NoConn ~ 1975 2650
NoConn ~ 1975 2750
NoConn ~ 1975 2950
NoConn ~ 1975 3050
NoConn ~ 1975 3250
NoConn ~ 1975 3350
NoConn ~ 1975 3550
NoConn ~ 1975 3650
$Comp
L Device:R R1
U 1 1 6446B1E2
P 2325 1800
F 0 "R1" H 2395 1846 50  0000 L CNN
F 1 "5k1" H 2395 1755 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 2255 1800 50  0001 C CNN
F 3 "~" H 2325 1800 50  0001 C CNN
	1    2325 1800
	1    0    0    -1  
$EndComp
$Comp
L Device:R R2
U 1 1 6446B657
P 2600 1800
F 0 "R2" H 2670 1846 50  0000 L CNN
F 1 "5k1" H 2670 1755 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 2530 1800 50  0001 C CNN
F 3 "~" H 2600 1800 50  0001 C CNN
	1    2600 1800
	1    0    0    -1  
$EndComp
Wire Wire Line
	2600 1550 2600 1650
$Comp
L power:GND #PWR0106
U 1 1 6446C180
P 2600 2025
F 0 "#PWR0106" H 2600 1775 50  0001 C CNN
F 1 "GND" H 2605 1852 50  0000 C CNN
F 2 "" H 2600 2025 50  0001 C CNN
F 3 "" H 2600 2025 50  0001 C CNN
	1    2600 2025
	1    0    0    -1  
$EndComp
Wire Wire Line
	2600 2025 2600 2000
Wire Wire Line
	2325 1950 2325 2000
Wire Wire Line
	2325 2000 2600 2000
Connection ~ 2600 2000
Wire Wire Line
	2600 2000 2600 1950
Wire Wire Line
	1975 1550 2600 1550
Wire Wire Line
	2325 1650 1975 1650
$Comp
L power:VDD #PWR0107
U 1 1 64470FB3
P 4750 2100
F 0 "#PWR0107" H 4750 1950 50  0001 C CNN
F 1 "VDD" H 4767 2273 50  0000 C CNN
F 2 "" H 4750 2100 50  0001 C CNN
F 3 "" H 4750 2100 50  0001 C CNN
	1    4750 2100
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0108
U 1 1 644713B8
P 4750 3775
F 0 "#PWR0108" H 4750 3525 50  0001 C CNN
F 1 "GND" H 4755 3602 50  0000 C CNN
F 2 "" H 4750 3775 50  0001 C CNN
F 3 "" H 4750 3775 50  0001 C CNN
	1    4750 3775
	1    0    0    -1  
$EndComp
Wire Wire Line
	4750 2175 4750 2100
$Comp
L RF_Module:ESP-12E U1
U 1 1 64473025
P 4750 2975
F 0 "U1" H 4975 3850 50  0000 C CNN
F 1 "ESP-12E" H 4500 3850 50  0000 C CNN
F 2 "RF_Module:ESP-12E" H 4750 2975 50  0001 C CNN
F 3 "http://wiki.ai-thinker.com/_media/esp8266/esp8266_series_modules_user_manual_v1.1.pdf" H 4400 3075 50  0001 C CNN
	1    4750 2975
	1    0    0    -1  
$EndComp
$Comp
L Connector:DIN-5_180degree J2
U 1 1 644836BD
P 10450 2650
F 0 "J2" V 10496 2420 50  0000 R CNN
F 1 "Nabu PC" V 10405 2420 50  0000 R CNN
F 2 "Atkelar_Custom:MIDI_DIN5-B" H 10450 2650 50  0001 C CNN
F 3 "http://www.mouser.com/ds/2/18/40_c091_abd_e-75918.pdf" H 10450 2650 50  0001 C CNN
	1    10450 2650
	0    -1   -1   0   
$EndComp
$Comp
L Device:R R7
U 1 1 6448ABF9
P 9650 2025
F 0 "R7" H 9720 2071 50  0000 L CNN
F 1 "180" H 9720 1980 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 9580 2025 50  0001 C CNN
F 3 "~" H 9650 2025 50  0001 C CNN
	1    9650 2025
	1    0    0    -1  
$EndComp
Wire Wire Line
	9650 2175 8875 2175
Connection ~ 9650 2175
Wire Wire Line
	8875 1975 9125 1975
Wire Wire Line
	9125 1975 9125 1875
Wire Wire Line
	9125 1875 9650 1875
Wire Wire Line
	9650 1875 10350 1875
Connection ~ 9650 1875
Wire Wire Line
	10350 2350 10350 1875
Wire Wire Line
	10450 2175 10450 2350
Wire Wire Line
	9650 2175 10450 2175
Wire Wire Line
	9100 3525 10450 3525
Wire Wire Line
	10450 3525 10450 2950
Wire Wire Line
	10350 2950 10350 3925
Wire Wire Line
	10350 3925 9100 3925
NoConn ~ 10150 2650
$Comp
L power:VCC #PWR0109
U 1 1 644CB422
P 8375 1425
F 0 "#PWR0109" H 8375 1275 50  0001 C CNN
F 1 "VCC" H 8392 1598 50  0000 C CNN
F 2 "" H 8375 1425 50  0001 C CNN
F 3 "" H 8375 1425 50  0001 C CNN
	1    8375 1425
	1    0    0    -1  
$EndComp
$Comp
L power:VCC #PWR0110
U 1 1 644CB963
P 8400 3025
F 0 "#PWR0110" H 8400 2875 50  0001 C CNN
F 1 "VCC" H 8417 3198 50  0000 C CNN
F 2 "" H 8400 3025 50  0001 C CNN
F 3 "" H 8400 3025 50  0001 C CNN
	1    8400 3025
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0111
U 1 1 644CBDD1
P 8400 4300
F 0 "#PWR0111" H 8400 4050 50  0001 C CNN
F 1 "GND" H 8405 4127 50  0000 C CNN
F 2 "" H 8400 4300 50  0001 C CNN
F 3 "" H 8400 4300 50  0001 C CNN
	1    8400 4300
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0112
U 1 1 644CC1B1
P 8375 2500
F 0 "#PWR0112" H 8375 2250 50  0001 C CNN
F 1 "GND" H 8380 2327 50  0000 C CNN
F 2 "" H 8375 2500 50  0001 C CNN
F 3 "" H 8375 2500 50  0001 C CNN
	1    8375 2500
	1    0    0    -1  
$EndComp
Wire Wire Line
	8375 1775 8375 1425
Wire Wire Line
	8375 2375 8375 2500
Wire Wire Line
	8400 3025 8400 3325
Wire Wire Line
	8400 4125 8400 4300
$Comp
L Interface_LineDriver:UA9637 U2
U 2 1 644D5EA4
P 8825 5825
F 0 "U2" H 8825 6306 50  0000 C CNN
F 1 "UA9637" H 8825 6215 50  0000 C CNN
F 2 "Package_DIP:DIP-8_W7.62mm" H 8825 5425 50  0001 C CNN
F 3 "http://pdf.datasheetcatalog.com/datasheets2/28/284473_1.pdf" H 8825 5825 50  0001 C CNN
	2    8825 5825
	-1   0    0    -1  
$EndComp
$Comp
L Interface_LineDriver:UA9638CD U3
U 2 1 644D6385
P 10425 5775
F 0 "U3" H 10425 6356 50  0000 C CNN
F 1 "UA9638CD" H 10425 6265 50  0000 C CNN
F 2 "Package_DIP:DIP-8_W7.62mm" H 10425 5275 50  0001 C CNN
F 3 "http://www.ti.com/lit/ds/symlink/ua9638.pdf" H 10425 5775 50  0001 C CNN
	2    10425 5775
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0113
U 1 1 644DE7EF
P 9775 5950
F 0 "#PWR0113" H 9775 5700 50  0001 C CNN
F 1 "GND" H 9780 5777 50  0000 C CNN
F 2 "" H 9775 5950 50  0001 C CNN
F 3 "" H 9775 5950 50  0001 C CNN
	1    9775 5950
	1    0    0    -1  
$EndComp
Wire Wire Line
	9775 5950 9775 5775
Wire Wire Line
	9775 5775 9825 5775
$Comp
L power:GND #PWR0114
U 1 1 644DF7BF
P 9575 6125
F 0 "#PWR0114" H 9575 5875 50  0001 C CNN
F 1 "GND" H 9580 5952 50  0000 C CNN
F 2 "" H 9575 6125 50  0001 C CNN
F 3 "" H 9575 6125 50  0001 C CNN
	1    9575 6125
	1    0    0    -1  
$EndComp
Wire Wire Line
	9575 6125 9575 5925
Wire Wire Line
	9575 5725 9325 5725
Wire Wire Line
	9325 5925 9575 5925
Connection ~ 9575 5925
Wire Wire Line
	9575 5925 9575 5725
NoConn ~ 8325 5825
NoConn ~ 11025 5575
NoConn ~ 11025 5975
$Comp
L Device:LED D1
U 1 1 644F4098
P 2825 4150
F 0 "D1" V 2864 4033 50  0000 R CNN
F 1 "IO" V 2773 4033 50  0000 R CNN
F 2 "LED_SMD:LED_0603_1608Metric" H 2825 4150 50  0001 C CNN
F 3 "~" H 2825 4150 50  0001 C CNN
	1    2825 4150
	0    -1   -1   0   
$EndComp
$Comp
L Device:LED D2
U 1 1 6450EF8E
P 3175 4150
F 0 "D2" V 3214 4033 50  0000 R CNN
F 1 "NET" V 3123 4033 50  0000 R CNN
F 2 "LED_SMD:LED_0603_1608Metric" H 3175 4150 50  0001 C CNN
F 3 "~" H 3175 4150 50  0001 C CNN
	1    3175 4150
	0    -1   -1   0   
$EndComp
$Comp
L Device:LED D3
U 1 1 645112DF
P 3550 4150
F 0 "D3" V 3589 4032 50  0000 R CNN
F 1 "ERR" V 3498 4032 50  0000 R CNN
F 2 "LED_SMD:LED_0603_1608Metric" H 3550 4150 50  0001 C CNN
F 3 "~" H 3550 4150 50  0001 C CNN
	1    3550 4150
	0    -1   -1   0   
$EndComp
$Comp
L Device:R R4
U 1 1 6451A971
P 2825 3750
F 0 "R4" H 2895 3796 50  0000 L CNN
F 1 "1k" H 2895 3705 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 2755 3750 50  0001 C CNN
F 3 "~" H 2825 3750 50  0001 C CNN
	1    2825 3750
	1    0    0    -1  
$EndComp
$Comp
L Device:R R5
U 1 1 6451AE9D
P 3175 3750
F 0 "R5" H 3245 3796 50  0000 L CNN
F 1 "1k" H 3245 3705 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 3105 3750 50  0001 C CNN
F 3 "~" H 3175 3750 50  0001 C CNN
	1    3175 3750
	1    0    0    -1  
$EndComp
$Comp
L Device:R R6
U 1 1 6451B371
P 3550 3750
F 0 "R6" H 3620 3796 50  0000 L CNN
F 1 "1k" H 3620 3705 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 3480 3750 50  0001 C CNN
F 3 "~" H 3550 3750 50  0001 C CNN
	1    3550 3750
	1    0    0    -1  
$EndComp
Wire Wire Line
	2825 3900 2825 4000
Wire Wire Line
	3175 3900 3175 4000
Wire Wire Line
	3550 3900 3550 4000
NoConn ~ 4150 2775
NoConn ~ 4150 2975
$Comp
L Logic_LevelTranslator:TXS0108EPW U6
U 1 1 6457E345
P 7250 2050
F 0 "U6" H 7625 2625 50  0000 C CNN
F 1 "TXS0108EPW" H 7675 2750 50  0000 C CNN
F 2 "Package_SO:TSSOP-20_4.4x6.5mm_P0.65mm" H 7250 1300 50  0001 C CNN
F 3 "www.ti.com/lit/ds/symlink/txs0108e.pdf" H 7250 1950 50  0001 C CNN
	1    7250 2050
	1    0    0    -1  
$EndComp
$Comp
L power:VCC #PWR0120
U 1 1 6457F42B
P 7350 1275
F 0 "#PWR0120" H 7350 1125 50  0001 C CNN
F 1 "VCC" H 7367 1448 50  0000 C CNN
F 2 "" H 7350 1275 50  0001 C CNN
F 3 "" H 7350 1275 50  0001 C CNN
	1    7350 1275
	1    0    0    -1  
$EndComp
$Comp
L power:VDD #PWR0121
U 1 1 6457F913
P 7150 1275
F 0 "#PWR0121" H 7150 1125 50  0001 C CNN
F 1 "VDD" H 7167 1448 50  0000 C CNN
F 2 "" H 7150 1275 50  0001 C CNN
F 3 "" H 7150 1275 50  0001 C CNN
	1    7150 1275
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0122
U 1 1 645836CB
P 7250 2900
F 0 "#PWR0122" H 7250 2650 50  0001 C CNN
F 1 "GND" H 7255 2727 50  0000 C CNN
F 2 "" H 7250 2900 50  0001 C CNN
F 3 "" H 7250 2900 50  0001 C CNN
	1    7250 2900
	1    0    0    -1  
$EndComp
Wire Wire Line
	7350 1275 7350 1350
$Comp
L Switch:SW_Push SW1
U 1 1 645E1F41
P 2325 4250
F 0 "SW1" V 2250 4025 50  0000 L CNN
F 1 "Signal" V 2350 3975 50  0000 L CNN
F 2 "Button_Switch_THT:SW_PUSH_6mm_H4.3mm" H 2325 4450 50  0001 C CNN
F 3 "http://www.apem.com/int/index.php?controller=attachment&id_attachment=488" H 2325 4450 50  0001 C CNN
	1    2325 4250
	0    1    1    0   
$EndComp
$Comp
L Connector:Micro_SD_Card_Det J3
U 1 1 6460E1C7
P 5125 6550
F 0 "J3" V 5029 7230 50  0000 L CNN
F 1 "SD-Card" V 5120 7230 50  0000 L CNN
F 2 "Atkelar_Custom:microSD_A" H 7175 7250 50  0001 C CNN
F 3 "https://www.hirose.com/product/en/download_file/key_name/DM3/category/Catalog/doc_file_id/49662/?file_category_id=4&item_id=195&is_series=1" H 5125 6650 50  0001 C CNN
	1    5125 6550
	0    1    1    0   
$EndComp
$Comp
L power:GND #PWR0126
U 1 1 6465B558
P 4625 7525
F 0 "#PWR0126" H 4625 7275 50  0001 C CNN
F 1 "GND" H 4630 7352 50  0000 C CNN
F 2 "" H 4625 7525 50  0001 C CNN
F 3 "" H 4625 7525 50  0001 C CNN
	1    4625 7525
	1    0    0    -1  
$EndComp
Wire Wire Line
	4625 7525 4625 7350
$Comp
L power:VDD #PWR0127
U 1 1 64661196
P 5525 5200
F 0 "#PWR0127" H 5525 5050 50  0001 C CNN
F 1 "VDD" H 5542 5373 50  0000 C CNN
F 2 "" H 5525 5200 50  0001 C CNN
F 3 "" H 5525 5200 50  0001 C CNN
	1    5525 5200
	1    0    0    -1  
$EndComp
Wire Wire Line
	5025 5550 5025 5650
$Comp
L power:GND #PWR0128
U 1 1 646768B3
P 4275 5725
F 0 "#PWR0128" H 4275 5475 50  0001 C CNN
F 1 "GND" H 4280 5552 50  0000 C CNN
F 2 "" H 4275 5725 50  0001 C CNN
F 3 "" H 4275 5725 50  0001 C CNN
	1    4275 5725
	1    0    0    -1  
$EndComp
Wire Wire Line
	4725 5650 4725 5550
Wire Wire Line
	4725 5550 5025 5550
Wire Wire Line
	6850 2150 6775 2150
Wire Wire Line
	6775 2150 6775 2250
Wire Wire Line
	7250 2825 7250 2750
Wire Wire Line
	6850 2250 6775 2250
Connection ~ 6775 2250
Wire Wire Line
	6775 2250 6775 2350
Wire Wire Line
	6850 2350 6775 2350
Connection ~ 6775 2350
Wire Wire Line
	6775 2350 6775 2450
Wire Wire Line
	6850 2450 6775 2450
Connection ~ 6775 2450
Wire Wire Line
	6775 2450 6775 2825
$Comp
L Device:CP C4
U 1 1 64726FEB
P 700 7275
F 0 "C4" H 818 7321 50  0000 L CNN
F 1 "22µ" H 818 7230 50  0000 L CNN
F 2 "Capacitor_SMD:C_2512_6332Metric_Pad1.52x3.35mm_HandSolder" H 738 7125 50  0001 C CNN
F 3 "~" H 700 7275 50  0001 C CNN
	1    700  7275
	1    0    0    -1  
$EndComp
$Comp
L Device:C C5
U 1 1 64728ACF
P 1125 7275
F 0 "C5" H 1240 7321 50  0000 L CNN
F 1 "10n" H 1240 7230 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric_Pad1.05x0.95mm_HandSolder" H 1163 7125 50  0001 C CNN
F 3 "~" H 1125 7275 50  0001 C CNN
	1    1125 7275
	1    0    0    -1  
$EndComp
$Comp
L Device:C C6
U 1 1 64729D51
P 1525 7275
F 0 "C6" H 1640 7321 50  0000 L CNN
F 1 "10n" H 1640 7230 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric_Pad1.05x0.95mm_HandSolder" H 1563 7125 50  0001 C CNN
F 3 "~" H 1525 7275 50  0001 C CNN
	1    1525 7275
	1    0    0    -1  
$EndComp
$Comp
L Device:C C7
U 1 1 6472A2F8
P 2175 7275
F 0 "C7" H 2290 7321 50  0000 L CNN
F 1 "10n" H 2290 7230 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric_Pad1.05x0.95mm_HandSolder" H 2213 7125 50  0001 C CNN
F 3 "~" H 2175 7275 50  0001 C CNN
	1    2175 7275
	1    0    0    -1  
$EndComp
$Comp
L Device:C C8
U 1 1 6472C1F2
P 2550 7275
F 0 "C8" H 2665 7321 50  0000 L CNN
F 1 "10n" H 2665 7230 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric_Pad1.05x0.95mm_HandSolder" H 2588 7125 50  0001 C CNN
F 3 "~" H 2550 7275 50  0001 C CNN
	1    2550 7275
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0129
U 1 1 6473C177
P 1875 7525
F 0 "#PWR0129" H 1875 7275 50  0001 C CNN
F 1 "GND" H 1880 7352 50  0000 C CNN
F 2 "" H 1875 7525 50  0001 C CNN
F 3 "" H 1875 7525 50  0001 C CNN
	1    1875 7525
	1    0    0    -1  
$EndComp
$Comp
L power:VCC #PWR0130
U 1 1 6473C841
P 2550 6950
F 0 "#PWR0130" H 2550 6800 50  0001 C CNN
F 1 "VCC" H 2567 7123 50  0000 C CNN
F 2 "" H 2550 6950 50  0001 C CNN
F 3 "" H 2550 6950 50  0001 C CNN
	1    2550 6950
	1    0    0    -1  
$EndComp
$Comp
L power:VDD #PWR0131
U 1 1 6473CED6
P 1125 6925
F 0 "#PWR0131" H 1125 6775 50  0001 C CNN
F 1 "VDD" H 1142 7098 50  0000 C CNN
F 2 "" H 1125 6925 50  0001 C CNN
F 3 "" H 1125 6925 50  0001 C CNN
	1    1125 6925
	1    0    0    -1  
$EndComp
Wire Wire Line
	1125 6925 1125 7000
Wire Wire Line
	2550 6950 2550 7000
Wire Wire Line
	2175 7125 2175 7000
Wire Wire Line
	2175 7000 2550 7000
Connection ~ 2550 7000
Wire Wire Line
	2550 7000 2550 7125
Wire Wire Line
	700  7125 700  7000
Wire Wire Line
	700  7000 1125 7000
Connection ~ 1125 7000
Wire Wire Line
	1125 7000 1125 7125
Wire Wire Line
	1125 7000 1525 7000
Wire Wire Line
	1525 7000 1525 7125
Wire Wire Line
	700  7425 700  7475
Wire Wire Line
	1875 7525 1875 7475
Wire Wire Line
	700  7475 1125 7475
Connection ~ 1875 7475
Wire Wire Line
	1875 7475 2175 7475
Wire Wire Line
	1525 7425 1525 7475
Connection ~ 1525 7475
Wire Wire Line
	1525 7475 1875 7475
Wire Wire Line
	1125 7425 1125 7475
Connection ~ 1125 7475
Wire Wire Line
	1125 7475 1525 7475
Wire Wire Line
	2175 7425 2175 7475
Connection ~ 2175 7475
Wire Wire Line
	2175 7475 2550 7475
Wire Wire Line
	2550 7425 2550 7475
$Comp
L Device:C C10
U 1 1 647ABEE4
P 1875 7275
F 0 "C10" H 1990 7321 50  0000 L CNN
F 1 "10n" H 1990 7230 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric_Pad1.05x0.95mm_HandSolder" H 1913 7125 50  0001 C CNN
F 3 "~" H 1875 7275 50  0001 C CNN
	1    1875 7275
	1    0    0    -1  
$EndComp
Wire Wire Line
	1875 7425 1875 7475
Wire Wire Line
	1875 7125 1875 7000
Wire Wire Line
	1875 7000 1525 7000
Connection ~ 1525 7000
Wire Wire Line
	5400 1075 5400 1175
Wire Wire Line
	5400 1175 5650 1175
Wire Wire Line
	5650 1175 5650 1075
$Comp
L power:VDD #PWR0118
U 1 1 6482B694
P 5650 1075
F 0 "#PWR0118" H 5650 925 50  0001 C CNN
F 1 "VDD" H 5667 1248 50  0000 C CNN
F 2 "" H 5650 1075 50  0001 C CNN
F 3 "" H 5650 1075 50  0001 C CNN
	1    5650 1075
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0119
U 1 1 6482BD9D
P 4900 1250
F 0 "#PWR0119" H 4900 1000 50  0001 C CNN
F 1 "GND" H 4905 1077 50  0000 C CNN
F 2 "" H 4900 1250 50  0001 C CNN
F 3 "" H 4900 1250 50  0001 C CNN
	1    4900 1250
	1    0    0    -1  
$EndComp
Wire Wire Line
	4100 2375 4150 2375
$Comp
L Device:R R8
U 1 1 645409D2
P 6625 3775
F 0 "R8" H 6695 3821 50  0000 L CNN
F 1 "10k" H 6695 3730 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 6555 3775 50  0001 C CNN
F 3 "~" H 6625 3775 50  0001 C CNN
	1    6625 3775
	1    0    0    -1  
$EndComp
$Comp
L power:VDD #PWR0132
U 1 1 64540F93
P 6900 3500
F 0 "#PWR0132" H 6900 3350 50  0001 C CNN
F 1 "VDD" H 6917 3673 50  0000 C CNN
F 2 "" H 6900 3500 50  0001 C CNN
F 3 "" H 6900 3500 50  0001 C CNN
	1    6900 3500
	1    0    0    -1  
$EndComp
NoConn ~ 7650 2150
NoConn ~ 7650 2250
NoConn ~ 7650 2350
NoConn ~ 7650 2450
Wire Wire Line
	4900 1075 4900 1250
$Comp
L Device:R R11
U 1 1 645B5968
P 6650 2125
F 0 "R11" H 6450 2175 50  0000 L CNN
F 1 "10k" H 6450 2075 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 6580 2125 50  0001 C CNN
F 3 "~" H 6650 2125 50  0001 C CNN
	1    6650 2125
	1    0    0    -1  
$EndComp
$Comp
L Device:R R10
U 1 1 645CD2F0
P 6900 3775
F 0 "R10" H 6970 3821 50  0000 L CNN
F 1 "10k" H 6970 3730 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 6830 3775 50  0001 C CNN
F 3 "~" H 6900 3775 50  0001 C CNN
	1    6900 3775
	1    0    0    -1  
$EndComp
NoConn ~ 4150 3475
$Comp
L power:VDD #PWR0135
U 1 1 6462207B
P 3875 2350
F 0 "#PWR0135" H 3875 2200 50  0001 C CNN
F 1 "VDD" H 3892 2523 50  0000 C CNN
F 2 "" H 3875 2350 50  0001 C CNN
F 3 "" H 3875 2350 50  0001 C CNN
	1    3875 2350
	1    0    0    -1  
$EndComp
Wire Wire Line
	3875 2350 3875 2575
Wire Wire Line
	3875 2575 4150 2575
$Comp
L Device:R R9
U 1 1 64658C4A
P 2325 3550
F 0 "R9" H 2395 3596 50  0000 L CNN
F 1 "10k" H 2395 3505 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 2255 3550 50  0001 C CNN
F 3 "~" H 2325 3550 50  0001 C CNN
	1    2325 3550
	1    0    0    -1  
$EndComp
Wire Wire Line
	2325 3400 2325 3350
$Comp
L power:VDD #PWR0136
U 1 1 6467DD4A
P 2325 3350
F 0 "#PWR0136" H 2325 3200 50  0001 C CNN
F 1 "VDD" H 2342 3523 50  0000 C CNN
F 2 "" H 2325 3350 50  0001 C CNN
F 3 "" H 2325 3350 50  0001 C CNN
	1    2325 3350
	1    0    0    -1  
$EndComp
NoConn ~ 4150 3175
NoConn ~ 4625 5650
$Comp
L Connector:Conn_01x06_Male J4
U 1 1 648061B3
P 5200 875
F 0 "J4" V 5035 803 50  0000 C CNN
F 1 "Prog" V 5126 803 50  0000 C CNN
F 2 "Connector_PinHeader_2.54mm:PinHeader_2x03_P2.54mm_Vertical" H 5200 875 50  0001 C CNN
F 3 "~" H 5200 875 50  0001 C CNN
	1    5200 875 
	0    1    1    0   
$EndComp
Wire Wire Line
	4750 3675 4750 3775
$Comp
L power:GND #PWR0123
U 1 1 64749FFF
P 6650 2350
F 0 "#PWR0123" H 6650 2100 50  0001 C CNN
F 1 "GND" H 6655 2177 50  0000 C CNN
F 2 "" H 6650 2350 50  0001 C CNN
F 3 "" H 6650 2350 50  0001 C CNN
	1    6650 2350
	1    0    0    -1  
$EndComp
Wire Wire Line
	6650 2275 6650 2350
$Comp
L Device:R R15
U 1 1 6482EDAD
P 5525 5425
F 0 "R15" H 5300 5450 50  0000 L CNN
F 1 "10k" H 5300 5350 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 5455 5425 50  0001 C CNN
F 3 "~" H 5525 5425 50  0001 C CNN
	1    5525 5425
	-1   0    0    1   
$EndComp
Wire Wire Line
	5525 5650 5525 5600
Wire Wire Line
	7150 1275 7150 1350
Wire Wire Line
	6625 3550 6900 3550
Wire Wire Line
	6625 3550 6625 3625
Wire Wire Line
	6900 3550 7175 3550
Connection ~ 6900 3550
Wire Wire Line
	7175 3550 7175 3625
Wire Wire Line
	6900 3550 6900 3625
Wire Wire Line
	6900 3925 6900 4425
Wire Wire Line
	6625 3925 6625 4250
Wire Wire Line
	3175 3425 3175 3500
Wire Wire Line
	4150 3275 3625 3275
Wire Wire Line
	6850 1950 6775 1950
Wire Wire Line
	6775 1950 6775 2050
Connection ~ 6775 2150
Wire Wire Line
	6850 2050 6775 2050
Connection ~ 6775 2050
Wire Wire Line
	6775 2050 6775 2150
NoConn ~ 7650 1950
NoConn ~ 7650 2050
Wire Wire Line
	7650 1750 7875 1750
Wire Wire Line
	7875 1750 7875 2075
Wire Wire Line
	7825 3725 7825 1850
Wire Wire Line
	7825 1850 7650 1850
Wire Wire Line
	7825 3725 7900 3725
Entry Wire Line
	6150 1750 6250 1650
Entry Wire Line
	6150 1850 6250 1750
Entry Wire Line
	6150 1950 6250 1850
Wire Wire Line
	6250 1650 6650 1650
Wire Wire Line
	6250 1750 6850 1750
Wire Wire Line
	6250 1850 6850 1850
Text Label 6250 1650 0    50   ~ 0
5V_ENABLE
Text Label 6250 1750 0    50   ~ 0
RX_3V3
Text Label 6250 1850 0    50   ~ 0
TX_3V3
Wire Wire Line
	6775 2825 7250 2825
Wire Wire Line
	7250 2825 7250 2900
Connection ~ 7250 2825
Entry Wire Line
	5000 1400 5100 1500
Entry Wire Line
	5100 1400 5200 1500
Entry Wire Line
	5200 1400 5300 1500
Entry Wire Line
	5300 1400 5400 1500
Wire Wire Line
	5300 1400 5300 1075
Wire Wire Line
	5200 1075 5200 1400
Wire Wire Line
	5100 1075 5100 1400
Wire Wire Line
	5000 1075 5000 1400
Text Label 5300 1400 1    50   ~ 0
TX_3V3
Text Label 5200 1400 1    50   ~ 0
RX_3V3
Text Label 5000 1400 1    50   ~ 0
PROG_EN
Text Label 5100 1400 1    50   ~ 0
RESET
Wire Wire Line
	4275 5550 4275 5725
Wire Wire Line
	4725 5550 4275 5550
Connection ~ 4725 5550
Entry Wire Line
	6050 2375 6150 2475
Wire Wire Line
	6050 2375 5350 2375
Text Label 6050 2375 2    50   ~ 0
PROG_EN
Entry Wire Line
	6050 2475 6150 2575
Wire Wire Line
	5350 2475 6050 2475
Text Label 6050 2475 2    50   ~ 0
TX_3V3
Entry Wire Line
	6050 2675 6150 2775
Wire Wire Line
	5350 2675 6050 2675
Text Label 6050 2675 2    50   ~ 0
RX_3V3
Entry Wire Line
	6050 3175 6150 3275
Wire Wire Line
	6050 3175 5350 3175
Text Label 6050 3175 2    50   ~ 0
SCLK
Entry Wire Line
	6050 3075 6150 3175
Entry Wire Line
	6050 2975 6150 3075
Entry Wire Line
	6050 2875 6150 2975
Wire Wire Line
	5350 3075 6050 3075
Wire Wire Line
	5350 2975 6050 2975
Wire Wire Line
	5350 2875 6050 2875
Text Label 6050 3075 2    50   ~ 0
MOSI
Text Label 6050 2975 2    50   ~ 0
MISO
Text Label 6050 2875 2    50   ~ 0
SD_CS
Wire Wire Line
	4825 5650 4825 5600
Wire Wire Line
	4825 5600 5525 5600
Wire Wire Line
	5525 5575 5525 5600
Connection ~ 5525 5600
Wire Wire Line
	5525 5200 5525 5250
Wire Wire Line
	5525 5250 5225 5250
Wire Wire Line
	5225 5250 5225 5650
Connection ~ 5525 5250
Wire Wire Line
	5525 5250 5525 5275
Entry Wire Line
	4825 4725 4925 4825
Wire Wire Line
	4925 4825 4925 5650
Text Label 4925 4825 3    50   ~ 0
MISO
Wire Wire Line
	5125 5650 5125 4825
Wire Wire Line
	5325 5650 5325 4825
Wire Wire Line
	5425 5650 5425 4825
Entry Wire Line
	5025 4725 5125 4825
Entry Wire Line
	5225 4725 5325 4825
Entry Wire Line
	5325 4725 5425 4825
Text Label 5125 4825 3    50   ~ 0
SCLK
Text Label 5325 4825 3    50   ~ 0
MOSI
Text Label 5425 4825 3    50   ~ 0
SD_CS
Entry Wire Line
	6150 4675 6250 4575
Entry Wire Line
	6150 4525 6250 4425
Entry Wire Line
	6150 4350 6250 4250
Wire Wire Line
	7175 3925 7175 4575
$Comp
L Device:R R16
U 1 1 6485BEB3
P 7175 3775
F 0 "R16" H 7245 3821 50  0000 L CNN
F 1 "10k" H 7245 3730 50  0000 L CNN
F 2 "Resistor_SMD:R_0603_1608Metric" V 7105 3775 50  0001 C CNN
F 3 "~" H 7175 3775 50  0001 C CNN
	1    7175 3775
	1    0    0    -1  
$EndComp
Wire Wire Line
	6900 3550 6900 3500
Wire Wire Line
	6250 4250 6625 4250
Text Label 6275 4250 0    50   ~ 0
MOSI
Wire Wire Line
	6250 4425 6900 4425
Wire Wire Line
	6250 4575 7175 4575
Text Label 6275 4425 0    50   ~ 0
MISO
Text Label 6275 4575 0    50   ~ 0
SCLK
Wire Wire Line
	5350 3375 6050 3375
Entry Wire Line
	6050 3375 6150 3475
Text Label 6050 3375 2    50   ~ 0
BTN_SIG
$Comp
L power:GND #PWR0115
U 1 1 650E4112
P 2325 4525
F 0 "#PWR0115" H 2325 4275 50  0001 C CNN
F 1 "GND" H 2330 4352 50  0000 C CNN
F 2 "" H 2325 4525 50  0001 C CNN
F 3 "" H 2325 4525 50  0001 C CNN
	1    2325 4525
	1    0    0    -1  
$EndComp
Wire Wire Line
	2325 4525 2325 4450
Entry Wire Line
	4000 1500 4100 1600
Wire Wire Line
	4100 1600 4100 2375
Text Label 4100 1600 3    50   ~ 0
RESET
Entry Wire Line
	3550 4625 3650 4725
Text Label 3550 4625 1    50   ~ 0
LED_ERR
Wire Wire Line
	3550 3600 3550 3500
Wire Wire Line
	3550 4300 3550 4625
Wire Wire Line
	3175 4300 3175 4625
Wire Wire Line
	2825 4300 2825 4625
Entry Wire Line
	3175 4625 3275 4725
Entry Wire Line
	2825 4625 2925 4725
Text Label 3175 4625 1    50   ~ 0
LED_NET
Text Label 2825 4625 1    50   ~ 0
LED_IO
$Comp
L power:VDD #PWR0116
U 1 1 6521C093
P 3175 3425
F 0 "#PWR0116" H 3175 3275 50  0001 C CNN
F 1 "VDD" H 3192 3598 50  0000 C CNN
F 2 "" H 3175 3425 50  0001 C CNN
F 3 "" H 3175 3425 50  0001 C CNN
	1    3175 3425
	1    0    0    -1  
$EndComp
Wire Wire Line
	3550 3500 3175 3500
Connection ~ 3175 3500
Wire Wire Line
	3175 3500 3175 3600
Wire Wire Line
	3175 3500 2825 3500
Wire Wire Line
	2825 3500 2825 3600
Entry Wire Line
	3525 3175 3625 3275
Text Label 3625 3275 0    50   ~ 0
LED_ERR
Entry Wire Line
	6050 2775 6150 2875
Entry Wire Line
	6050 2575 6150 2675
Wire Wire Line
	5350 2575 6050 2575
Wire Wire Line
	5350 2775 6050 2775
Text Label 6050 2775 2    50   ~ 0
LED_IO
Text Label 6050 2575 2    50   ~ 0
LED_NET
Wire Wire Line
	6650 1975 6650 1650
Connection ~ 6650 1650
Wire Wire Line
	6650 1650 6850 1650
Wire Wire Line
	5350 3275 6050 3275
Entry Wire Line
	6050 3275 6150 3375
Text Label 6050 3275 2    50   ~ 0
5V_ENABLE
Wire Wire Line
	2325 3700 2325 3875
Entry Wire Line
	2575 4625 2675 4725
Wire Wire Line
	2575 3875 2325 3875
Connection ~ 2325 3875
Wire Wire Line
	2325 3875 2325 4050
Wire Wire Line
	2575 3875 2575 4625
Text Label 2575 4625 1    50   ~ 0
BTN_SIG
NoConn ~ 4150 3375
NoConn ~ 4150 3075
$Comp
L power:VCC #PWR0117
U 1 1 6533B647
P 8825 5225
F 0 "#PWR0117" H 8825 5075 50  0001 C CNN
F 1 "VCC" H 8842 5398 50  0000 C CNN
F 2 "" H 8825 5225 50  0001 C CNN
F 3 "" H 8825 5225 50  0001 C CNN
	1    8825 5225
	1    0    0    -1  
$EndComp
Wire Wire Line
	8825 5225 8825 5525
$Comp
L power:VCC #PWR0124
U 1 1 65352563
P 10325 5075
F 0 "#PWR0124" H 10325 4925 50  0001 C CNN
F 1 "VCC" H 10342 5248 50  0000 C CNN
F 2 "" H 10325 5075 50  0001 C CNN
F 3 "" H 10325 5075 50  0001 C CNN
	1    10325 5075
	1    0    0    -1  
$EndComp
Wire Wire Line
	10325 5075 10325 5375
$Comp
L power:GND #PWR0125
U 1 1 65367E25
P 8825 6300
F 0 "#PWR0125" H 8825 6050 50  0001 C CNN
F 1 "GND" H 8830 6127 50  0000 C CNN
F 2 "" H 8825 6300 50  0001 C CNN
F 3 "" H 8825 6300 50  0001 C CNN
	1    8825 6300
	1    0    0    -1  
$EndComp
Wire Wire Line
	8825 6125 8825 6300
$Comp
L power:GND #PWR0133
U 1 1 653711C0
P 10325 6350
F 0 "#PWR0133" H 10325 6100 50  0001 C CNN
F 1 "GND" H 10330 6177 50  0000 C CNN
F 2 "" H 10325 6350 50  0001 C CNN
F 3 "" H 10325 6350 50  0001 C CNN
	1    10325 6350
	1    0    0    -1  
$EndComp
Wire Wire Line
	10325 6175 10325 6350
$Comp
L Switch:SW_Push SW2
U 1 1 64702229
P 2700 5200
F 0 "SW2" V 2625 4975 50  0000 L CNN
F 1 "Reset" V 2725 4925 50  0000 L CNN
F 2 "Button_Switch_THT:SW_PUSH_6mm_H4.3mm" H 2700 5400 50  0001 C CNN
F 3 "http://www.apem.com/int/index.php?controller=attachment&id_attachment=488" H 2700 5400 50  0001 C CNN
	1    2700 5200
	0    1    1    0   
$EndComp
$Comp
L power:GND #PWR0134
U 1 1 6470222F
P 2700 5475
F 0 "#PWR0134" H 2700 5225 50  0001 C CNN
F 1 "GND" H 2705 5302 50  0000 C CNN
F 2 "" H 2700 5475 50  0001 C CNN
F 3 "" H 2700 5475 50  0001 C CNN
	1    2700 5475
	1    0    0    -1  
$EndComp
Wire Wire Line
	2700 5475 2700 5400
Wire Wire Line
	2700 4825 2700 5000
Entry Wire Line
	2700 4825 2800 4725
Wire Bus Line
	3525 1500 3525 3300
Wire Bus Line
	3525 1500 6150 1500
Wire Bus Line
	2525 4725 6150 4725
Wire Bus Line
	6150 1500 6150 4725
Text Label 2700 4850 3    50   ~ 0
RESET
$EndSCHEMATC
