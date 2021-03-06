#include "OpoFlashStore.h"

configuration OpoFlashStoreC {}

implementation {
    components OpoFlashStoreP, MainC, LedsC;
    OpoFlashStoreP.Boot -> MainC.Boot;
    OpoFlashStoreP.Leds -> LedsC.Leds;

    components RandomMtC;
    OpoFlashStoreP.RandomMt -> RandomMtC.RandomMt;

    components OpoC;
    OpoFlashStoreP.Opo -> OpoC.Opo;

    components ActiveMessageC;
    components CC2420PacketC;
    components new AMSenderC(OPO_FLASH_STORE) as OpoRfSend;
    components new AMReceiverC(OPO_FLASH_STORE) as OpoRfReceive;

    OpoC.AMSend -> OpoRfSend.AMSend;
    OpoC.AMReceive -> OpoRfReceive.Receive;
    OpoC.RfControl -> ActiveMessageC.SplitControl;
    OpoFlashStoreP.Packet -> ActiveMessageC.Packet;
    OpoFlashStoreP.PacketAcks -> ActiveMessageC.PacketAcknowledgements;
    OpoFlashStoreP.CC2420Packet -> CC2420PacketC.CC2420Packet;

    components CC2420ControlC;
    OpoFlashStoreP.CC2420Config -> CC2420ControlC.CC2420Config;

    components HplAt45dbC;
    OpoFlashStoreP.HplAt45db -> HplAt45dbC.HplAt45db;

    components RV4162C;
    OpoFlashStoreP.HplRV4162 -> RV4162C.HplRV4162;

    components new TimerMilliC() as TxTimer;
    components new TimerMilliC() as RxTimer;
    components new TimerMilliC() as LedTimer;
    OpoFlashStoreP.TxTimer -> TxTimer;
    OpoFlashStoreP.RxTimer -> RxTimer;
    OpoFlashStoreP.LedTimer -> LedTimer;
}