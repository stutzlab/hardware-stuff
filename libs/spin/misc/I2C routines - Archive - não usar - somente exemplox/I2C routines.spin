{{┌──────────────────────────────────────────┐
  │ Wrapper for I2C routines                 │
  │ Author: Chris Gadd                       │
  │ Copyright (c) 2013 Chris Gadd            │
  │ See end of file for terms of use.        │
  └──────────────────────────────────────────┘
}}
OBJ
  I2C_PASM  : "I2C PASM driver v1.3"                    ' I2C driver written in PASM with a SPIN handler
  I2C_SPIN  : "I2C Spin driver v1.1"                    ' I2C driver written entirely in SPIN, runs in same cog as calling object
  I2C_slave : "I2C slave v1.0"                          ' I2C slave object written in PASM
  Poller : "I2C poller"                                 ' Displays the address of every device on the I2C bus
  Slave  : "I2C slave demo"                             
  EEPROM : "EEPROM demo"
  Acc    : "Accelerometer demo"
  Alt    : "Altimeter demo"
  Gyro   : "Gyroscope demo"
  RTC    : "Clock demo"
  IO     : "IO expander demo"

PUB blank

DAT                     
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}                                        