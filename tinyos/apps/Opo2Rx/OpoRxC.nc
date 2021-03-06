#include "OpoRx.h"

configuration OpoRxC {}

implementation {
    components MainC, LedsC, OpoRxP;
    OpoRxP.Boot -> MainC.Boot;
    OpoRxP.Leds -> LedsC.Leds;

    components RandomC;
    OpoRxP.Random -> RandomC;

    components OpoC;
    OpoRxP.Opo -> OpoC.Opo;

    components ActiveMessageC;
    components CC2420PacketC;
    components new AMSenderC(OPO_RX_TX) as OpoRfSend;
    components new AMReceiverC(OPO_RX_TX) as OpoRfReceive;
    components new AMSenderC(OPO_RX_BASE) as BaseSend;

    OpoRxP.Packet -> ActiveMessageC.Packet;
    OpoRxP.BaseSend -> BaseSend;
    OpoRxP.RfControl -> ActiveMessageC.SplitControl;
    OpoRxP.CC2420Packet -> CC2420PacketC.CC2420Packet;
    OpoC.AMSend -> OpoRfSend;
    OpoC.AMReceive -> OpoRfReceive;
    OpoC.RfControl -> ActiveMessageC.SplitControl;

    components CC2420ControlC;
    OpoRxP.CC2420Config -> CC2420ControlC.CC2420Config;

    components HplSST25VF064C;
    OpoRxP.Flash -> HplSST25VF064C.HplSST25VF064;

    components new TimerMilliC() as RxTimer;
    components new TimerMilliC() as BaseTimer;
    OpoRxP.RxTimer -> RxTimer;
    OpoRxP.BaseTimer -> BaseTimer;
}