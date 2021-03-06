'' =================================================================================================
''
''   File....... jm_hd485.spin
''   Purpose.... Half-duplex, true-mode serial IO for EIA-485 network
''   Author..... Jon "JonnyMac" McPhalen
''               Copyright (c) 2009-2012 Jon McPhalen
''               -- see below for terms of use
''   E-mail..... 
''   Started....  
''   Updated.... 15 FEB 2012
''
'' =================================================================================================


{{

  Example interface

               +5v           +5v
                              
                │             │
            10k              │                   
            3k3 │ ┌─────────┐ │                   
      rx ────┻─┤1°      8├─┘                   
     txe ──────┳─┤2       7├────────┳────────── Pin 2  
                ┣─┤3       6├────────┼─┳──────── Pin 3 
      tx ──────┼─┤4       5├─┐      │ │    ┌─── Pin 1  
                │ └─────────┘ │      │ │    │               
            10k    MAX485    │      │ └ ┐  └ ┐ 
                │             │  120  ┌ ┘  ┌ ┘ 
                │             │      │ │    │   
                                   └─┘                                              

   1  RO   Receive output
   2  /RE  Receive enable  (active low)
   3  DE   Transmit enable (active high)
   4  DI   Transmit input
   5  Vss  ground
   6  A    differential IO
   7  B    differential IO
   8  Vdd  +5v

   Note: 3.3k into RX pin limits current when output is driven.  10K pull-up
         on RX keeps RX at idle when RO disabled, allowing this circuit to
         work with full-duplex drivers (e.g., FDS)

}}


con

  BUF_SIZE = 128                                                ' power of 2  (2..512)
  BUF_MASK = BUF_SIZE - 1

  TXE_US   = 15                                                 ' 15us txe delay
    

var

  long  cog                                                     ' cog flag/id

  long  rxhead                                                  ' rx head index
  long  rxtail                                                  ' rx tail index
  long  txhead                                                  ' tx head index
  long  txtail                                                  ' tx tail index

  long  rxpin                                                   ' rx pin (in)
  long  txpin                                                   ' tx pin (out)
  long  txepin                                                  ' tx enable pin (out)
  long  ledpin                                                  ' tx active led (out)

  long  txeticks                                                ' tx enable delay (ticks)
  long  bitticks                                                ' bit timing (ticks)

  long  rxhub                                                   ' hub address of rxbuf
  long  txhub                                                   ' hub address of txbuf

  byte  rxbuf[BUF_SIZE]
  byte  txbuf[BUF_SIZE]


pub start(rxd, txd, txe, baud)

'' Start without using TX LED

  return startx(rxd, txd, txe, -1, baud)
  

pub startx(rxd, txd, txe, txled, baud)

'' Half-duplex, true mode UART 
'' -- rxd is rx pin (in)
'' -- txd is tx pin (out)
'' -- txe is tx enable pin (out)
'' -- txled is led for tx indication
'' -- baud is baud rate for coms

  stop                                                          ' stop UART driver

  longfill(@rxhead, 0, 4)                                       ' clear (for restart)
  longmove(@rxpin, @rxd, 4)                                     ' copy pins
  txeticks := clkfreq / 1_000_000 * TXE_US                      ' set txe delay (in ticks)
  bitticks := clkfreq / baud                                    ' set bit time for baud rate
  rxhub    := @rxbuf
  txhub    := @txbuf

  result := cog := cognew(@hd485, @rxhead) + 1                  ' start UART cog


pub stop

'' Stops UART cog

  if cog
    cogstop(cog~ - 1)


con

  ' ***** RX methods *****
  

pub rx 

'' Pulls c from receive buffer if available
'' -- will wait if buffer is empty

  repeat while (rxtail == rxhead)                               ' wait for byte in buffer
  result := rxbuf[rxtail]                                            ' get it
  rxtail := (rxtail + 1) & BUF_MASK                             ' update tail pointer


pub rxcheck

'' Pulls c from receive buffer if available
'' -- returns -1 if buffer is empty

  result := -1

  if (rxtail <> rxhead)                                         ' something in buffer?
    result := rxbuf[rxtail]                                     ' get it
    rxtail := (rxtail + 1) & BUF_MASK                           ' update tail pointer
    

pub rxtime(ms) | t, mstix

'' Wait ms milliseconds for a byte to be received
'' -- returns -1 if no byte received, $00..$FF if byte

  mstix := clkfreq / 1000                                       ' ticks per millisecond

  t := cnt
  repeat until (((result := rxcheck) => 0) or (((cnt - t) / mstix) > ms))


pub rxtix(tix) | t 

'' Waits tix clock ticks for a byte to be received
'' -- returns -1 if no byte received

  t := cnt
  repeat until (((result := rxcheck) => 0) or ((cnt - t) > tix))  



pub rxflush

'' Flush receive buffer

  repeat while (rxcheck => 0)


con

  ' ***** TX methods *****


pub tx(c)

'' Move c into transmit buffer if room is available
'' -- will wait if buffer is full

  repeat until (txtail <> ((txhead + 1) & BUF_MASK))
  txbuf[txhead] := c
  txhead := (txhead + 1) & BUF_MASK


pub str(pntr)

'' Transmit z-string at pntr

  repeat strsize(pntr)
    tx(byte[pntr++])
    
    
pub dec(value) | i, x                  
                                       
'' Print a decimal number              
                                       
  x := (value == negx)                                          ' mark max negative
                     
  if (value < 0)                                                ' if negative                   
    value := ||(value + x)                                      ' make positive and adjust
    tx("-")                                                     ' print sign
                                       
  i := 1_000_000_000                                            ' set divisor
                                       
  repeat 10                            
    if value => i                                               ' non-zero digit for this divisor?                  
      tx(value / i + "0" + x * (i == 1))                        '  print digit                    
      value //= i                                               '  remove from value
      result~~                                                  '  set printing flag                      
    elseif result or (i == 1)                                   ' if printing or last digit            
      tx("0")                                                   '  print zero
    i /= 10                                                     ' update divisor

  
pub rjdec(val, width, pchar) | tmpval, pad

'' Print right-justified decimal value
'' -- val is value to print
'' -- width is width of (pchar padded) field for value

'  Original code by Dave Hein
'  Modified by Jon McPhalen

  if (val => 0)                                                 ' if positive
    tmpval := val                                               '  copy value
    pad := width - 1                                            '  make room for 1 digit
  else                                                           
    if (val == negx)                                            '  if max negative
      tmpval := posx                                            '    use max positive for width
    else                                                        '  else
      tmpval := -val                                            '    make positive
    pad := width - 2                                            '  make room for sign and 1 digit
                                                                 
  repeat while (tmpval => 10)                                   ' adjust pad for value width > 1
    pad--                                                        
    tmpval /= 10                                                 
                                                                 
  repeat pad                                                    ' print pad
    tx(pchar)                                                      
                                                                 
  dec(val)                                                      ' print value

  
pub hex(value, digits)

'' Print a hexadecimal number

  value <<= (8 - digits) << 2
  repeat digits
    tx(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))


pub bin(value, digits)

'' Print a binary number

  value <<= (32 - digits)
  repeat digits
    tx((value <-= 1) & 1 + "0")       


pub txflush

'' Wait for transmit buffer to empty, then wait for byte to transmit

  repeat until (txtail == txhead)
  repeat 11                                                     ' start + 8 + 2
    waitcnt(bitticks + cnt)


con

  ' ***** UART driver ***** 
  

dat

                        org     0

hd485                   mov     t1, par                         ' start of structure
                        mov     rxheadpntr, t1                  ' save hub address of rxhead

                        add     t1, #4
                        mov     rxtailpntr, t1                  ' save hub address of rxtail

                        add     t1, #4
                        mov     txheadpntr, t1                  ' save hub address of txhead

                        add     t1, #4
                        mov     txtailpntr, t1                  ' save hub address of txtail

                        add     t1, #4
                        rdlong  t2, t1                          ' get rxpin
                        mov     rxmask, #1                      ' make pin mask
                        shl     rxmask, t2
                        andn    dira, rxmask                    ' force to input

                        add     t1, #4
                        rdlong  t2, t1                          ' get txpin
                        mov     txmask, #1                      ' make pin mask
                        shl     txmask, t2
                        or      outa, txmask                    ' set to idle
                        or      dira, txmask                    ' make output

                        add     t1, #4
                        rdlong  t2, t1                          ' get txepin
                        mov     txemask, #1                     ' make pin mask
                        shl     txemask, t2
                        andn    outa, txemask                   ' set to disabled
                        or      dira, txemask                   ' make output
                                 
                        add     t1, #4
                        rdlong  t2, t1                          ' get tx led
                        cmps    t2, #0                  wc, wz  ' check 
        if_b            mov     txledmask, #0                   ' don't use
        if_ae           mov     txledmask, #1                   ' make pin mask
                        shl     txledmask, t2
                        andn    outa, txledmask                 ' set to disabled
                        or      dira, txledmask                 ' make output 
                        
                        add     t1, #4
                        rdlong  txetix, t1                      ' get txe timing

                        add     t1, #4
                        rdlong  bit1x0tix, t1                   ' read bit timing
                        mov     bit1x5tix, bit1x0tix            ' create 1.5 bit timing
                        shr     bit1x5tix, #1
                        add     bit1x5tix, bit1x0tix

                        add     t1, #4
                        rdlong  rxbufpntr, t1                   ' read address of rxbuf[0]

                        add     t1, #4
                        rdlong  txbufpntr, t1                   ' read address of txbuf[0]

                        

' ==========
'  RECEIVE
' ==========
                        
rxserial                mov     rxtimer, cnt                    ' start timer 
                        test    rxmask, ina             wc      ' look for start bit
        if_c            jmp     #txserial                       ' if no start, check tx

receive                 mov     rxwork, #0                      ' clear work var
                        mov     rxcount, #8                     ' rx eight bits
                        add     rxtimer, bit1x5tix              ' skip start bit
                        
rxbit                   waitcnt rxtimer, bit1x0tix              ' hold for middle of bit
                        test    rxmask, ina             wc      ' rx --> c
                        shr     rxwork, #1                      ' prep for new bit
                        muxc    rxwork, #%1000_0000             ' c --> rxwork.7
                        djnz    rxcount, #rxbit                 ' update bit count
                        waitpeq rxmask, rxmask                  ' wait for stop bit
                        
putrxbuf                rdlong  t1, rxheadpntr                  ' t1 := rxhead
                        add     t1, rxbufpntr                   ' t1 := rxbuf[rxhead]
                        wrbyte  rxwork, t1                      ' rxbuf[rxhead] := rxwork
                        sub     t1, rxbufpntr                   ' t1 := rxhead 
                        add     t1, #1                          ' inc t1
                        and     t1, #BUF_MASK                   ' rollover if needed
                        wrlong  t1, rxheadpntr                  ' rxhead := t1
                        jmp     #rxserial


' ==========
'  TRANSMIT
' ==========

txserial                rdlong  t1, txheadpntr                  ' t1 = txhead  
                        rdlong  t2, txtailpntr                  ' t2 = txtail
                        cmp     t1, t2                  wz      ' byte(s) to tx?
        if_nz           jmp     #txenable                       ' yes, enable transmitter 

txdisable               andn    outa, txemask                   ' no, disable transmitter
                        andn    outa, txledmask                 ' kill tx led
                        jmp     #rxserial                       ' check rx

txenable                or      outa, txledmask                 ' show tx mode
                        test    txemask, ina            wc      ' already enabled?
        if_c            jmp     #gettxbuf                       ' yes, skip txe delay

                        or      outa, txemask                   ' enable transmit
                        mov     txtimer, txetix                 ' set timer
                        add     txtimer, cnt                    ' start it
                        waitcnt txtimer, #0                     ' let timer expire

gettxbuf                mov     t1, txbufpntr                   ' t1 := @txbuf[0]
                        add     t1, t2                          ' t1 := @txbuf[txtail]
                        rdbyte  txwork, t1                      ' txwork := txbuf[txtail] 

updatetxtail            add     t2, #1                          ' inc txtail
                        and     t2, #BUF_MASK                   ' wrap to 0 if necessary
                        wrlong  t2, txtailpntr                  ' save

transmit                or      txwork, STOP_BITS               ' preset stop bit(s) 
                        shl     txwork, #1                      ' add start bit
                        mov     txcount, #11                    ' start + 8 data + 2 stop
                        mov     txtimer, bit1x0tix              ' load bit timing
                        add     txtimer, cnt                    ' sync with system counter

txbit                   shr     txwork, #1              wc      ' move bit0 to C
                        muxc    outa, txmask                    ' output the bit
                        waitcnt txtimer, bit1x0tix              ' let timer expire, reload   
                        djnz    txcount, #txbit                 ' update bit count
                        jmp     #txserial        


' -------------------------------------------------------------------------------------------------

STOP_BITS               long    $FFFF_FF00

rxmask                  res     1                               ' rx pin mask
txmask                  res     1                               ' tx pin mask
txemask                 res     1                               ' rx pin mask
txledmask               res     1                               ' tx led pin mask

txetix                  res     1                               ' timing for txe
bit1x0tix               res     1                               ' bit timing
bit1x5tix               res     1                               ' 1.5 bit timing (rx)

rxheadpntr              res     1                               ' head pointer
rxtailpntr              res     1                               ' tail pointer
rxbufpntr               res     1                               ' hub address of rxbuf[0]
rxwork                  res     1                               ' rx byte in
rxcount                 res     1                               ' bits to receive
rxtimer                 res     1                               ' timer for bit sampling

txheadpntr              res     1                               ' head pointer
txtailpntr              res     1                               ' tail pointer
txbufpntr               res     1                               ' hub address of txbuf[0]
txwork                  res     1                               ' tx byte out
txcount                 res     1                               ' bits to transmit
txtimer                 res     1                               ' timer for bit output

t1                      res     1                               ' work vars
t2                      res     1
t3                      res     1
                                 
                        fit     496
                        

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