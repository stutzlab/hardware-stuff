'' ******************************************************************************
'' * MCP320016 i2c Bus Expander Object                                          *
'' * James Burrows Oct 07                                                       *
'' * Version 2.0                                                                *
'' ******************************************************************************
''
'' MCP23016 i2c I/O expander object.
''
'' For a simple example write a 0 to the I/O register to set all 8 pins output, and
'' 255 or %1111_1111 to GP0 or GP1 to make the pins +5V.  Attach some LED's!  
''
'' www.microchip.com
''
'' this object provides the PUBLIC functions:
''  -> WriteIOregister0 - set the output register bank 0
''  -> WriteIOregister1 - set the output register bank 1
''  -> WriteGP0 - set the GP register bank 0 
''  -> WriteGP1 - set the GP register bank 1
''  -> ReadGP0 - read the GP register bank 0
''  -> ReadGP1 - read the GP register bank 0
''
'' this object provides the PRIVATE functions:
''  -> None
''
'' this object uses the following sub OBJECTS:
''  -> i2cObject
''
'' Revision History:
''  -> V2    - re-Release
'' 
'' The default address is %0100_0000

CON
  ' MCP constants
  _MCP23016_GP0   = $0
  _MCP23016_GP1   = $1
  _MCP23016_OLAT0 = $2
  _MCP23016_OLAT1 = $3
  _MCP23016_IPOL0 = $4
  _MCP23016_IPOL1 = $5    
  _MCP23016_IODIR0 = $6
  _MCP23016_IODIR1 = $7
  _MCP23016_INTCAP0 = $8
  _MCP23016_INTCAP1 = $9
  _MCP23016_IOCON0 = $A
  _MCP23016_IOCON1 = $B 


OBJ
  i2cObject         : "Basic_I2C_Driver"

  
PUB WriteIOregister0(i2cSCL,_deviceAddress,i2cData) : ackbit
  ' write to the I/O register port 0
  ackbit := i2cObject.WriteLocation(i2cSCL,_deviceAddress, _MCP23016_IODIR0,i2cData)
  return ackbit  

PUB WriteIOregister1(i2cSCL,_deviceAddress,i2cData) : ackbit
  ' write to the I/O register port 1
  ackbit := i2cObject.WriteLocation(i2cSCL,_deviceAddress, _MCP23016_IODIR1,i2cData)
  return ackbit  
     
PUB WriteGP0(i2cSCL,_deviceAddress,i2cData) : ackbit
  ' write to the General Purpose (GP) Port register 0
  ackbit := i2cObject.WriteLocation(i2cSCL,_deviceAddress, _MCP23016_GP0,i2cData)
  return ackbit

PUB WriteGP1(i2cSCL,_deviceAddress,i2cData) : ackbit
  ' write to the General Purpose (GP) Port register 1
  ackbit := i2cObject.WriteLocation(i2cSCL,_deviceAddress, _MCP23016_GP1,i2cData)
  return ackbit

PUB ReadGP0(i2cSCL,_deviceAddress) : i2cData
  ' Read the General Purpose (GP) Port register 0
  i2cData := i2cObject.readLocation(i2cSCL,_deviceAddress, _MCP23016_GP0)
  return i2cData

PUB ReadGP1(i2cSCL,_deviceAddress) : i2cData
  ' Read the General Purpose (GP) Port register 1
 i2cData := i2cObject.readLocation(i2cSCL,_deviceAddress, _MCP23016_GP1)
  return i2cData
      