#include "Opo.h"
#include "printf.h"
#include "StorageVolumes.h"
configuration OpoC {}

implementation {

  components MainC, OpoP, LedsC, RandomMtC;
  OpoP.Boot -> MainC.Boot;
  OpoP.Leds -> LedsC;
  OpoP.Random -> RandomMtC;

  components new BlockStorageC(VOLUME_BLOCKSTORE); 
  OpoP.BlockRead -> BlockStorageC.BlockRead;
  OpoP.BlockWrite -> BlockStorageC.BlockWrite;

  components At45dbPowerC;
  OpoP.At45dbPower -> At45dbPowerC.SplitControl;

  components PrintfC;
  components SerialStartC;

  components ActiveMessageC;
  components new AMSenderC(AM_URANGE) as AMSend;
  components new AMReceiverC(AM_URANGE) as AmReceive;
  OpoP.Receive -> AmReceive;
  OpoP.AMSend -> AMSend;
  OpoP.RfControl -> ActiveMessageC.SplitControl;
  OpoP.AMPacket -> ActiveMessageC.AMPacket;

  components CC2420PacketC;
  OpoP.CC2420Packet -> CC2420PacketC.CC2420Packet;

  components HplMsp430GeneralIOC as GpIO;
  OpoP.SFDLatchIntGpIO -> GpIO.SFDPIN; // alt interrupt handler for SFD Line
  OpoP.UCapGpIO -> GpIO.UCAPPIN;
  OpoP.SFDCapGpIO -> GpIO.SFDCAPPIN;
  OpoP.SFDLatch -> GpIO.SFDLATCH;
  OpoP.TxRxSel -> GpIO.TXRXSEL;
  OpoP.TxGate -> GpIO.TXGATE;
  OpoP.Amp3_ADC -> GpIO.AMP3_ADC;
  OpoP.leds2gpio -> GpIO.leds2gpio;

  components Msp430TimerC;
  OpoP.SFDCapture -> Msp430TimerC.SFDCAPTURE;
  OpoP.SFDCapControl -> Msp430TimerC.SFDCAPCONT;
  OpoP.UltrasonicCapture -> Msp430TimerC.UCAPTURE; 
  OpoP.UCapControl -> Msp430TimerC.UCAPCONT;

  components RV4162C;
  OpoP.HplRV4162 -> RV4162C.HplRV4162;

  components new TimerMilliC() as WakeStartTimer;
  components new TimerMilliC() as WakeStopTimer;
  components new TimerMilliC() as RangeStartTimer; 
  components new TimerMilliC() as RangeStopTimer;  
  components new TimerMilliC() as RxGuardTimer;
  components new TimerMilliC() as UCapStartTimer;
  components new TimerMilliC() as ReadTimer;
  components new TimerMilliC() as At45dbPowerDownTimer;
  components new TimerMilliC() as ZeroWriterTimer;
  components new TimerMilliC() as ResetTimeTimer;
  components new TimerMilliC() as RxResetTimer; 
  OpoP.WakeStartTimer -> WakeStartTimer;
  OpoP.WakeStopTimer -> WakeStopTimer;
  OpoP.RangeStartTimer -> RangeStartTimer;
  OpoP.RangeStopTimer ->RangeStopTimer;
  OpoP.RxGuardTimer -> RxGuardTimer;
  OpoP.UCapStartTimer -> UCapStartTimer;
  OpoP.ReadTimer -> ReadTimer;
  OpoP.At45dbPowerDownTimer -> At45dbPowerDownTimer;
  OpoP.ZeroWriterTimer -> ZeroWriterTimer;
  OpoP.ResetTimeTimer -> ResetTimeTimer;
  OpoP.RxResetTimer -> RxResetTimer;
}
