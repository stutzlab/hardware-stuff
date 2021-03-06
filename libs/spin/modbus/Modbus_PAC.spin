{{
 ┌───────────────────────────────────────────────────────────────────┐
 │               MODBUS RTU SLAVE                                    │
 │                                                                   │
 │                                                                   │
 └───────────────────────────────────────────────────────────────────┘

  
<Revision>

- 0.8

<Author>

- Paul Clyne (pacman on the Forums)


Acknowledgements
- Based on code originally supplied by Olivier Jauzelon
- Kurenko - for his help with word/long/byte confusion
- lots of others of the forums - for answering my many questions




A modbus request to read registers is of the form:-

   [01][03][00][04][00][64][05][E0]

   in above example, We want to read 100 holding registers, starting at 40005 from station 1

   [AA][BB][CC][DD][EE][FF][GG][HH]
   Where:-
        AA = station number being asked for data
        BB = Message type
                03 = Read multiple Holding registers    = 40000 series
                04 = Read Multiple Input registers      = 30000 series                                                               
                16 = Write Multiple Holding registers   = 40000 series
        CC + DD = Start Address of data from {be careful of the offset}
        EE + FF = Number of registers to get
        GG + HH = Checksum


   This implementation is limited to 5 registers,

   The external device would think we hold our status in registers 30001 through 30006 (30000 -> 30005 internally) 
   the external device would think we have our data area in registers 40001 through 40006  (40000 -> 40005 internally) 
    

   So the read message to read all 5 holding registers from station 1 should be [01][03][00][00][00][05][85][C9]
   
   The write message for all 5 registers to station 1 would be [01][10][00][00][00][05][00][01][00][02][00][03][00][A5][00][FF][crc1][crc2]
        40001 = 1
        40002 = 2
        40003 = 3
        40004 = 165
        40005 = 255

}}
CON
_clkmode = xtal1 + pll16x
_xinfreq = 5_000_000

'configure the parameters for the serial interface - the live one, not the debug one                
 RXpin = 16
 TXpin = 14
 Baud = 9600
 MBAddress = 1

 
OBJ

   ser : "FullDuplexSerial"                             ' the _real_ communications driver 
   pst:  "Parallax Serial Terminal"                     ' for debug messages - this instance can be deleted {and any PST objects elsewhere in the code}
   
   
                       
VAR

byte CogNo                      'Variable declaration

word R40000[5]                  ' 40000 series registers - Holding registers (read/write) - NORMALLY this would be defined in the TOP level object
word R30000[5]                  ' 30000 series registers - Input registers (read only) - NORMALLY this would be defined in the TOP level object

byte buffer[75]                 ' Modbus frame buffer - change if want to get more than 32 registers in single frame
byte RawBuffer[75]              ' the raw data in the serial port
byte InBuffer[25]               ' the request from the master
Byte OutBuffer[75]              ' the data we will transmit back to the master 

                             
PUB Main | idx, ExeceptionCode, FrameEndCountOffset, FrameEndFlag, RChar, FrameEndTgt, i, FrameCheck

   'This is run in a new cog
   'it's function is to check the DataIn stream and bung that data into InBuffer[0] to InBuffer[...]
   'When it gets a full buffer or we have recieved a frame end space (3.5 times character length) then set the EndFrameFlag

   ' a single bit is 1/BaudRate of time long,
   '  thus an 11 bit long character is 11 * 1/Baud time long (so for 9600 we get something like 1.14583333 mS)
   '  A frame in RTU is terminated by a 3.5 character long space.

   pst.Start(115_200)           ' start the debug session

   'pre-load some data into the Input registers (remember they are read only by the host}
   '  That way if you poll those registers you get meaningful data
   R30000[0] := 1
   R30000[1] := 22
   R30000[2] := 333
   R30000[3] := 4444
   R30000[4] := 55555



   'the code starts properly here
   Ser.start(RXPin,TXPin,0,Baud)
 
   FrameEndCountOffset := (CLKFREQ / baud * 11 * 35 / 10) ' you can't multiply by a decimal so use integer and then divide by 10  
                                                          ' * 35 / 10 == *3.5
   FrameCheck := False

   idx := 1                     'we start at one as we will use [0] to store the idx count
   
   repeat
             
      RChar := ser.rxcheck
      
      if RChar <> -1                                    'A new char has arrived
                                                        
        RawBuffer[idx++] := RChar                       'so put it in the buffer @ position idx and increment idx
        FrameEndTgt := cnt + FrameEndCountOffset        'and set the 'future' count vale so if we dont get a char between now and then
                                                        ' we know that we have got a frame time timing
        FrameCheck := True
                                                                
      'there isn't a character
      'so we might be at the end of the frame'
      'check to see if we are....
      
      if ((cnt >= FrameEndTgt) AND FrameCheck )OR (idx > 73)

        bytefill (@Inbuffer, 0, 25)
        bytemove (@InBuffer,@RawBuffer,24)              'Copy Incomming Raw Buffer to InBuffer
        InBuffer[0] := idx

        bytefill (@RawBuffer, 0, 75)                    'Clear Raw Buffer
        idx := 1
        FrameCheck := False

        CheckMessage(@InBuffer)
          
Pri CheckMessage (mesg)   | CRCVal, CRCpos1, CRCpos2

  'NOTE the first element of the array contains the length of the array
      
  if (byte[mesg][0] < 8)
    'Frame Too Short
    'ExeceptionCode := 
    'SendResponse
    'Set Clear Flag
    PST.newline
    PST.str(string("Frame Too short"))

  elseif (byte[mesg][0] > 70)
    'Frame too long
    'ExeceptionCode :=
    'SendResponse
    'Set Clear Flag
    PST.newline
    PST.str(string("Frame Too long"))
    
  elseif (byte[mesg][1] <> MBAddress)
    'not for this station so ignore it
    PST.newline
    PST.str(string("Wrong Stn"))
    'Set Clear Flag
                 
       
  else

    ' we have a correctly addressed, sized, message

    ' Lets check its CRC

     CRCVal := CheckCRC(mesg)
     CRCpos1 := byte[mesg][0] - 1
     CRCpos2 := byte[mesg][0] - 2
     
     
    If byte[@CRCval][0] <> byte[mesg][CRCpos2] OR byte[@CRCval][1] <> byte[mesg][CRCpos1]

       PST.newline
       PST.str(string("CRC mismatch"))

      'Registers out of range
      'ExeceptionCode := $81
      'SendResponse
      'Set Clear Flag

    else

       ' might be OK, check command type
   
      Case byte[mesg][2]

        $03, $04:
          '03h = Read Holding Register(s) - Read/Write registers -(40000 Series)
          '04h = Read Input Register(s) - Read only registers -(30000 Series)   

          if ((byte[mesg][5] > 0) or (byte[mesg][6] > 5))
            'Only 5 registers supported in this version
            PST.newline
            PST.str(string("Too many registers requested"))
           'ExeceptionCode := 3
           'SendResponse
           'Set Clear Flag

          elseif (byte[mesg][3] <> 0) OR (byte[mesg][4] > 4) OR (byte[mesg][4] + byte[mesg][6] > 5)
            'Only 5 registers supported in this version
            ' thus if 03 > 0 then we are asking for more than 5
            ' or if start address {mesg[4]} > 4
            ' or if start address plus register count to return > 5
            PST.newline
            PST.str(string("Out Of Range"))
            'Registers out of range
            'ExeceptionCode := 
            'SendResponse
            'Set Clear Flag 
           
          else
            ReadRegisters(mesg)
        
        $06 :
          '06h = Write Single Holding register (40000 Series)
          
          if ((byte[mesg][4] > 5))
            'Only 5 registers supported in this version
            PST.newline
            PST.str(string("Out Of Range"))
          ' 'ExeceptionCode := 3
          ' 'SendResponse
          ' 'Set Clear Flag
          else
            ProcessCode06(mesg)

          
        $10 :
          '10h = Write Multiple Holding registers (40000 Series)
          if (byte[mesg][3] <> 0) OR (byte[mesg][4] > 4) OR (byte[mesg][5] > 0) OR (byte[mesg][6] > 5) OR (byte[mesg][4] + byte[mesg][6] > 5) OR (byte[mesg][7] > 10)
            'Only 5 registers supported in this version
            ' thus if byte 3 {high Starting address} > 0 then we are asking for a register higher than our 5
            ' or if byte 4 {low Starting address} > 4
            ' or if byte 5 {high register count} > 0
            ' or if byte 6 {low register count} > 5  
            ' or if start address plus register count to return > 10.(remember 2 bytes per register)
            ' or number of bytes > 10
            PST.newline
            PST.str(string("Out Of Range"))
          else
            ProcessCode10(mesg)
'           
        other :
'                ExeceptionCode := $81
                'SendResponse
                'Set Clear Flag



PRI PrintBuffer(print) | k

  ' Just dumped the buffer to the debug terminal

  '  this method can be deleted once all testing has been done
  '  Any call to Printbuffer can then ALSO be deleted.  

    PST.newline
    PST.str(string ("PrintBuffer "))


    repeat k from 0 to  (byte[print][0] -1)
       PST.newline
       PST.hex(k,2)
       PST.str(string (" : "))
       PST.hex(byte[print][k],2)
  
PRI ReadRegisters (buf) | i, BaseReg, ResponseBuf[6], CRCval, CRCpos1, CRCpos2

   'Read Multiple registers
   ' input registers are the 30000 series and are accessed by a type 04 command
   ' holding registers are the 40000 series and are accessed by a type 03 command

    ResponseBuf.byte[1] := byte[buf][1]       'the first byte of any response is the station number
    
    ResponseBuf.byte[2] := byte[buf][2]       'the next byte of any response is the function code used to call the data

    ResponseBuf.byte[3] := byte[buf][6] * 2   'the next byte is the number of bytes of data we are retuning, NB: 2 bytes per register   

    BaseReg := byte[buf][4]         ' the first register we need to return data from
    
    repeat i from 4 to ResponseBuf.byte[3] + 3

      Case byte[buf][2]
        3:
          '03 = Read holding registers - Holding registers are the 40000 series
          ResponseBuf.byte[i++] := R40000{0}.byte[2*BaseReg+1]  'High byte of R40000[x]
          ResponseBuf.byte[i] := R40000{0}.byte[2*BaseReg]   'Low byte of R40000[x]
          
        4:
          '04 = Read INPUT registers - Input registers are the 30000 series
          ResponseBuf.byte[i++] := R30000{0}.byte[2*BaseReg+1]  'High byte of R30000[x]
          ResponseBuf.byte[i] := R30000{0}.byte[2*BaseReg]   'Low byte of R30000[x]
                   
      BaseReg++

      
    ResponseBuf.byte[0] := i + 2                        '+ 2 for CRC space

    CRCval := CheckCRC(@responseBuf)

    CRCpos1 := ResponseBuf.byte[0] - 1
    CRCpos2 := ResponseBuf.byte[0] - 2     
     
    ResponseBuf.byte[CRCpos2] := byte[@CRCval][0]
    ResponseBuf.byte[CRCpos1] := byte[@CRCval][1]
    
    SendOut(@ResponseBuf)

PRI ProcessCode06 (buf)| i, ResponseBuf[9], CRCval, Reg

  'code 06 Hex = Write Single Holding register (40000 Series)
   
  PST.newline
  PST.str(string("Process Code 06h"))


  Reg := byte[buf][4]         ' the register we are writing to

  R40000[reg] := byte[buf][5] * 256 + byte[buf][6]

  pst.newline
  pst.dec(byte[buf][5] * 256 + byte[buf][6])

  ' now generate and send the normal response (which is an echo of the request)


  ResponseBuf.byte[1] := byte[buf][1]       'the first byte of any response is the station number
    
  ResponseBuf.byte[2] := byte[buf][2]       'the next byte of any response is the function code used to call the data
  
  ResponseBuf.byte[3] := byte[buf][3]       'the next byte is the high byte of the starting address
  
  ResponseBuf.byte[4] := byte[buf][4]       'then the low byte of the starting address
     
  ResponseBuf.byte[5] := byte[buf][5]       'Data high byte
  
  ResponseBuf.byte[6] := byte[buf][6]       'Data low byte


  ResponseBuf.byte[0] := 9                  '+ 2 for CRC space
 
  CRCval := CheckCRC(@responseBuf)
   
  ResponseBuf.byte[7] := byte[@CRCval][0]
  ResponseBuf.byte[8] := byte[@CRCval][1]

  SendOut(@ResponseBuf)
    
PRI ProcessCode10 (buf)| i, ResponseBuf[9], CRCval 

  'code 10 Hex = Write Multiple Holding registers (40000 Series)
   
  PST.newline
  PST.str(string("Process Code 10h"))

  
  '  currently code 10 does NOT work
  '  I've not figured out the algorthym for mapping the data correctly
  ' for now I'll just return the normal response - and fix it later 

 ' repeat i from byte[buf][4] to byte[buf][6]
  '  R40000{0}.byte[2*i+1] := buf[8 + 2*i] * 256         ' high byte
  '  R40000{0}.byte[2*i] := buf[9 + 2*i]                 ' low byte
  '  i++

         
  ' now generate and send the normal response

  ResponseBuf.byte[1] := byte[buf][1]       'the first byte of any response is the station number
    
  ResponseBuf.byte[2] := byte[buf][2]       'the next byte of any response is the function code used to call the data

  ResponseBuf.byte[3] := byte[buf][3]       'the next byte is the high byte of the starting address

  ResponseBuf.byte[4] := byte[buf][4]       'then the low byte of the starting address
     
  ResponseBuf.byte[5] := byte[buf][5]       'number of registers written high byte

  ResponseBuf.byte[6] := byte[buf][6]       'number of registers written low byte


  ResponseBuf.byte[0] := 9                  '+ 2 for CRC space 
 
  CRCval := CheckCRC(@responseBuf)
   
  ResponseBuf.byte[7] := byte[@CRCval][0]
  ResponseBuf.byte[8] := byte[@CRCval][1]

  SendOut(@ResponseBuf)

PRI SendOut (buf)| j

  ' Transmits the data back to the host system.

  '  params:  buf - the data stream we want to transmit             
  '  return:  none
  
  'NOTE the first element of the array contains the length of the array       
  ' thus we need to send out buf[0] bytes of data

  PST.newline
  PST.str(string("Send Buf"))
  PrintBuffer(buf) ' just for debugging - delete later if required 
  
    
  repeat j from 1 to byte[buf][0] -1 
      
      Ser.TX(byte[buf][j])

PRI CheckCRC(buf) | i, CRCVal

  'Generate our own CRC values and return it

  '  params:  buf - the data stream we want to generate the CRC for             
  '  return:  CRCVal - the result of the CRC calculation [2 bytes 'wide']


   'remember that the first byte of Packet contains the length of the messgage
   'and the last two elements of InBuffer are the CRC

    

   CRCVal := $FFFF

   if byte[buf][0] > 2         ' no point in even doing this if we are only two byes long 
    
     i:= 1
     repeat while i < ((byte[buf][0])-2)

        CRCVal ^= byte[buf][i++] 'XOR and store back in CRCVal 
                                          
      repeat 8
         CRCVal := CRCVal >> 1 ^ ($A001 & (CRCVal & 1 <> 0))  'XOR and store back in result

   result := CRCVal

dat

{{

  Terms of Use: MIT License

  Permission is hereby granted, free of charge, to any person obtaining a copy of this
  software and associated documentation files (the "Software"), to deal in the Software
  without restriction, including without limitation the rights to use, copy, modify,
  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be included in all copies
  or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

}}   