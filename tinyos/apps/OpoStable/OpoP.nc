#include "Timer.h"
#include "printf.h"
#include "Opo.h"

/* 
  This applicaiton implements the Opo Ranging Protocol, a simple protocol 
  designed to offer quick, power efficient broadcast ranging. 
 
  On the transmit side, we first send a 1 ms ultrasonic wake up pulse to let 
  nearby nodes know to expect a lighting/thunder ranging sequence. 20 ms later, 
  we simultaneously send out a 1ms ultrasonic ranging pulse and an rf packet, 
  which the reciever can use to determine range. 

  In theory, we could accopmlish this using a wake up pulse followed by an 
  rf packet x ms later. In practice, it is tough to ensure that an rf packet 
  gets sent exactly x ms later. 

  On the receive side, after receiving the wake up pulse, we disable interrupts 
  from ultrasonic signals and wait for a radio signal. After receiving a packet, 
  we reenable ultrasonic interrupts, and then perform ToF difference ranging 
  based on the next received ultrasonic interrupt. There are also guard timers 
  to compensate for ultrasonic noise waking us up. 

  It is not difficult to adapt this code to perform ultrasonic on off keying 
  communication. However, in limited testing we found that the speed of such 
  communication was highly limited by multipath, making it too slow to be used 
  with mobile nodes. 

  In addition to this core functionality, we have added in a few optimizations. 
  
  The first is that after we successfully receive an ultrasonic ranging 
  sequence, we respond fairly quickly. The idea here is that broadcast is 
  somewhat directional, so nodes that could not see the initial broadcast 
  should see the response broadcast. This results in Node A broadcasting, 
  Node B Broadcasting, and Node A rebroadcasting. This helps with situations 
  where two people are walking towards each other. 

  TODO (Optional): 
  - Add backoff time to compensate for seeing many other nodes

  @author William Huang <wwhuang@umich.edu>
*/ 

module OpoP @safe()
{
  uses {
    /* Timers */
    interface Timer<TMilli> as WakeStartTimer;
    interface Timer<TMilli> as WakeStopTimer;
    interface Timer<TMilli> as RangeStartTimer;
    interface Timer<TMilli> as RangeStopTimer;
    interface Timer<TMilli> as RxGuardTimer;
    interface Timer<TMilli> as UCapStartTimer;
    interface Timer<TMilli> as ReadTimer;
    interface Timer<TMilli> as At45dbPowerDownTimer;
    interface Timer<TMilli> as ZeroWriterTimer;
    interface Timer<TMilli> as ResetTimeTimer;
    interface Timer<TMilli> as RxResetTimer;
    /* Pin setup */
    interface HplMsp430GeneralIO as SFDLatchIntGpIO;
    interface HplMsp430GeneralIO as SFDLatch;
    interface HplMsp430GeneralIO as UCapGpIO;
    interface HplMsp430GeneralIO as SFDCapGpIO;
    interface HplMsp430GeneralIO as TxRxSel;
    interface HplMsp430GeneralIO as TxGate;
    interface HplMsp430GeneralIO as Amp3_ADC;
    interface HplMsp430GeneralIO as leds2gpio;
    /*RF Stuff */
    interface AMSend;
    interface Receive;
    interface AMPacket;
    interface SplitControl as RfControl;
    interface CC2420Packet;
    /* Timer Controls */
    interface Msp430Capture as SFDCapture;
    interface Msp430Capture as UltrasonicCapture; 
    interface Msp430TimerControl as SFDCapControl;
    interface Msp430TimerControl as UCapControl;
    /* Flash Storage */ 
    interface BlockRead; 
    interface BlockWrite;
    interface SplitControl as At45dbPower;
    /* RTC */
    interface HplRV4162; 
    /* Boot and Random Stuff */
    interface Leds;
    interface Boot;
    interface Random;
  }
}

implementation {

  enum {TX, RX_WAKE, RX_RANGE} m_state;

  // State Variables
  bool firstBoot = TRUE; // When true, we export flash data to serial
  bool rxResponse = TRUE; //Fast ranging response or not

  // Timing and ranging
  uint32_t sfd_time = 0; // SFD trigger time.
  uint32_t utime = 0; // Ultrasonic trigger time.
  uint32_t range = 0; // Based on ToF difference between rf and ultrasonic
  bool rfValid = FALSE; // Validtes that the SFD went high due a valid packet 

  // Backoff timers in ms
  uint32_t randguard = 0; // general randomized backoff timer 
  uint16_t wakestartmin = 1000; // normal wake start minimum

  // Rf variables.
  message_t packet; // rf packet struct. see Opo.h  
  bool rfSendLock = FALSE;  // Set to TRUE when we are sending a packet.
  uint32_t range_sequence = 0; // Broadcast ranging number. 

  // Flash storage variables
  opo_rec_t opo_read_store;  // used to store data as we read it and export it
  opo_rec_t opo_store_buffer[93]; // buffers data. disk buffer is 256 bytes
  uint32_t flash_w_addr = 0; // Current address to store to.
  uint32_t flash_r_addr = 0; // Current address to read from.  
  uint8_t flash_valid = 77; //Determines if read data is junk or not
  uint16_t opo_buffer_index = 0; // tells us which buffer address to write to
  uint16_t opo_buffer_count = 0; // after x transmits, flush buffer to disk
  uint16_t opo_zero_count = 0; // Used when zeroing out the flash drive
  uint32_t current_array_address = 0; //used when flushing data to disk 

  // Timer variable
  uint16_t TACTL_RESTORE; //we keep the default TACTL value in here

  /* Helper function prototypes */
  void startTransducer(); // directly writes registers to start pwm
  void stopTransducer(); // directly writes registers tos top pwm
  void setupUltrasonicPWM(); // Sets up TimerA for PWM
  void setupTACTL(); // Modifies TACTL. TACTL must be default for flash writes.
  void enableReceive(); // Sets the analog switch to rx and turns the pfet off
  void enableTransmit(); // Sets the analog switch to tx and turns the pfet on
  void setupPins(); // sets pins to proper input/module state
  void setRandGuard(); // Sets randguard, which is our randomized guard time.

  // debug function to let us ranging related info. 
  task void displayRangeInfo() {
    printf("utime %lu\n", utime);
    printf("sfd_time %lu\n", sfd_time);
    printf("timediff %lu\n", (utime - sfd_time));
    printf("range %lu\n", range);
    printfflush(); 
  }

  // flush our buffer to disk
  task void WriteInfoToDisk() {
    TACTL = TACTL_RESTORE;
    printf("TX: %lu\n", opo_buffer_count);
    printf("RX: %lu\n", opo_buffer_index);
    printfflush();
    call At45dbPowerDownTimer.stop();
    call At45dbPower.start();
  }

  task void WriteTimeToRecord() {
    TACTL = TACTL_RESTORE;
    call Leds.led0Off();
    call Leds.led1Off();
    call HplRV4162.readFullTime();
  }

/********************************* Boot Up ************************************/

  /*
   * On boot, we set our: 
   * - pin functionality, 
   * - ultrasonic PWM timer module (TimerA1)
   * After that, we enable receive, and set a ranging sequence to start at a 
   * randomized later time between 2 and 4 seconds from boot. 
   * 
  */
  event void Boot.booted() {
    TACTL_RESTORE = TACTL;
    call CC2420Packet.setPower(&packet, 31);
    call HplRV4162.writeSTBit();
    printf("BOOTED\n");
    printfflush();
  }

  /*************************** Opo Transmit ***********************************/

  /* Transmit Side 
   * Transmit Process is set up as a series of timers. 
   * Each timer fire is responsible for one specific part of the transmit, 
   * such as triggering the wake up pulse.
   * The first timer starts the wake up ping. 
   * The second timer stops the wake up ping. 
   * The third timer  starts the rang ping and radio packet. 
   * THe fourth timer stops the range ping. 

   * Generally, the way everything works is by setting a state variable,
  */
  /****************************************************************************/

  /*
   * Disables receive side interrupts, checks if buffer flush should happen,
   * starts ultrasonic wake up pulse if no flush neccessary
  */
  event void WakeStartTimer.fired() {
    call RxResetTimer.stop();
    call RxGuardTimer.stop();
    enableTransmit();
    opo_buffer_count++;
    
    if(opo_buffer_index >= 80 || opo_buffer_count >= 40) {
      post WriteInfoToDisk();
    }
    else {
      setupTACTL();
      startTransducer();
      call SFDLatch.set();
      call WakeStopTimer.startOneShot(2);
    }
  }

  /*
   * Stops the wake up pulse
  */
  event void WakeStopTimer.fired() {
    stopTransducer();
    call SFDLatch.clr();
    call RangeStartTimer.startOneShot(40);
  }

  /*
   * Initiates rf and ultrasonic ranging packets
  */ 
  event void RangeStartTimer.fired() {
    startTransducer();
    call RfControl.start();
  }

  /*
   * Sets up the next ranging sequence. 
   * Increments the ranging sequence and puts the chip into receive mode. 
  */
  event void RangeStopTimer.fired() {
    stopTransducer();
    call SFDLatch.clr();
    setRandGuard();
    call WakeStartTimer.startOneShot(wakestartmin + randguard);
    enableReceive();
  }

  /*****************************  Opo Receive *********************************/

  /*
   * This event is responsible for starting up the radio upon a wake up pulse
   * And doing the ranging calculations upon a ranging pulse. 
   * Guard timers are NOT set up here since this an async event.
  */
  async event void UltrasonicCapture.captured(uint16_t time) {
    // One interrupt per ultrasonic pulse. 
    call UltrasonicCapture.setEdge(MSP430TIMER_CM_NONE);
    call UCapControl.clearPendingInterrupt();
    call Leds.led0On();
    
    // Wake up pulse
    if(m_state == RX_WAKE) { 
      m_state = RX_RANGE;
      call RfControl.start();
    }
 
    // Ranging Pulse
    else {
      utime = time; // Get pulse time
      if (utime > sfd_time && sfd_time != 0) {
        //Speed of sound = 10634 uM / tick
        atomic range = (utime - sfd_time) * 10634; // range in microm
      }
      atomic { 
        opo_store_buffer[opo_buffer_index].range = range;
        if(rfValid == TRUE) {
          post WriteTimeToRecord();
        }
      }
    } 

    if (call UltrasonicCapture.isOverflowPending()) {
      call UltrasonicCapture.clearOverflow();
    }
  }

  /*
   * Captures time of SFD line going high. 
   * AmReceive confirms correct packet and sets rfValid to last SFD high 
  */
  async event void SFDCapture.captured(uint16_t time) {
    // Right now we capture the time of the FIRST SFD high we see
    if(m_state == RX_RANGE && sfd_time == 0) {
      atomic sfd_time = time; 
      call Leds.led1On();
      call UltrasonicCapture.setEdge(MSP430TIMER_CM_RISING);
    }
    else if(m_state == TX) {
      call SFDLatch.set();
    }
    
    if (call SFDCapture.isOverflowPending()) {
      call SFDCapture.clearOverflow();
    }
  }  

  //Turns off the radio if we woke up due to ultrasonic noise
  event void RxGuardTimer.fired() {
    call RfControl.stop();
  }

  event void RxResetTimer.fired() {
    enableReceive();
  }

  /* 
   * Used to delay the ultrasonic interrupt enable.
   * Compensates for the voltage spike from switching the analog switch.
  */
  event void UCapStartTimer.fired() {
    call UltrasonicCapture.setEdge(MSP430TIMER_CM_RISING);
    call UCapControl.clearPendingInterrupt();
  }

/************************* RF STUFF *******************************************/

  event void RfControl.startDone(error_t err) {
    if(m_state == TX) {
      opo_rf_msg_t *payload;
      payload = (opo_rf_msg_t*) call AMSend.getPayload(&packet, 
                                                       sizeof(opo_rf_msg_t));
      payload -> sequence = range_sequence;
      payload -> tx_pwr = call CC2420Packet.getPower(&packet);

      call SFDCapture.setEdge(MSP430TIMER_CM_RISING);
      call AMSend.send(AM_BROADCAST_ADDR, 
                       &packet, 
                       sizeof(opo_rf_msg_t));
    }
    else if (m_state == RX_RANGE) {
      call WakeStartTimer.stop(); 
      call RxGuardTimer.startOneShot(75);
    }
  }

  event void RfControl.stopDone(error_t err) {
    call SFDCapture.setEdge(MSP430TIMER_CM_NONE);
    if (m_state != TX) {
      setRandGuard();
      call WakeStartTimer.startOneShot(wakestartmin + randguard);
      call RxResetTimer.startOneShot(25);
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    range_sequence++;
    call RangeStopTimer.startOneShot(2);
    call RfControl.stop();
  }

  event message_t* Receive.receive(message_t *msg, void *payload, uint8_t len) {
    if(m_state != TX) {
      opo_rf_msg_t *mData = (opo_rf_msg_t *) payload;
      opo_store_buffer[opo_buffer_index].valid = flash_valid;
      opo_store_buffer[opo_buffer_index].sequence = mData->sequence;
      opo_store_buffer[opo_buffer_index].id = call AMPacket.source(msg);
      opo_store_buffer[opo_buffer_index].rssi = call CC2420Packet.getRssi(msg);
      opo_store_buffer[opo_buffer_index].tx_pwr = mData->tx_pwr;

      atomic {
        rfValid = TRUE;
        if (range > 0) {
          post WriteTimeToRecord();
        }
      }

      call RxGuardTimer.stop();
      call RfControl.stop();
    }
    return msg;
    
  }

/******************** Block Storage Stuff *************************************/
   
  event void BlockWrite.writeDone(storage_addr_t addr, 
                       void* buf, storage_len_t len, 
                       error_t error) {
    call BlockWrite.sync();
  }

  event void BlockWrite.eraseDone(error_t err) {
    if(firstBoot == TRUE) {
      call ZeroWriterTimer.startOneShot(75);
    }
    else {
      setupUltrasonicPWM();
      setupPins();  

      setRandGuard();
      call WakeStartTimer.startOneShot(wakestartmin + randguard);

      enableReceive();
      call At45dbPowerDownTimer.startOneShot(10);
    }
  }

  event void BlockWrite.syncDone(error_t err) {
    if(firstBoot == TRUE) {
      opo_zero_count++;
      if (opo_zero_count == 10) {
        firstBoot = FALSE;
        call BlockWrite.erase();
      }
      else {
        call ZeroWriterTimer.startOneShot(75);
      }
    }
    else {
      flash_w_addr += ( (opo_buffer_index) * sizeof(opo_rec_t) );
      opo_buffer_count = 0;
      opo_buffer_index = 0;

      setRandGuard();
      call WakeStartTimer.startOneShot(wakestartmin + randguard);
      call At45dbPowerDownTimer.startOneShot(1000);
      printf("SD\n");
      printfflush();
    }
  }

  event void BlockRead.readDone(storage_addr_t addr, 
                      void* buf, storage_len_t len, 
                      error_t error) {

    flash_r_addr += sizeof(opo_rec_t);
    
    if(opo_read_store.valid == flash_valid) {
      printf("id:%u\n", opo_read_store.id);
      printf("r:%lu\n", opo_read_store.range);
      printf("sq:%lu\n", opo_read_store.sequence);
      printf("s:%u\n", opo_read_store.seconds);
      printf("m:%u\n", opo_read_store.minutes);
      printf("h:%u\n", opo_read_store.hours);
      printf("rs:%i\n", opo_read_store.rssi);
      printf("tx: %u\n", opo_read_store.tx_pwr);
      printfflush();
      call ReadTimer.startOneShot(70);
    }
    else {
      call BlockWrite.erase();
    }
  }

  event void ZeroWriterTimer.fired() {
      uint8_t zerowrite[16] = {0};
      storage_addr_t m_index = opo_zero_count * 16;
      call BlockWrite.write(m_index, &zerowrite, sizeof(uint8_t) * 16);
  }

  event void BlockRead.computeCrcDone(storage_addr_t addr, 
                            storage_len_t len,
                            uint16_t crc, error_t error) {}

  event void At45dbPower.startDone(error_t err) {
    if(firstBoot == TRUE) {
      call BlockRead.read(flash_r_addr, 
                          &opo_read_store, 
                          sizeof(opo_read_store));
    }
    else {
      call BlockWrite.write(flash_w_addr, 
                          &opo_store_buffer, 
                          ( (opo_buffer_index) * sizeof(opo_rec_t) ) );
    }
  }

  event void At45dbPower.stopDone(error_t err) {}

  event void ReadTimer.fired() {
    call BlockRead.read(flash_r_addr, &opo_read_store, sizeof(opo_read_store));
  }

  /* 
   * This timer is used to delay the deep power down command, which if given 
   * While the at45db is still doing i/o results in bad things. 
  */
  event void At45dbPowerDownTimer.fired() {
    call At45dbPower.stop();
  }

  /************************ RTC Stuff *****************************************/

  event void HplRV4162.readSecondsDone(error_t err, uint8_t sec) {

  }

  event void HplRV4162.readMinutesDone(error_t err, uint8_t min) {

  }

  event void HplRV4162.readFullTimeDone(error_t err, uint8_t* fullTime) {
    atomic {
      opo_store_buffer[opo_buffer_index].seconds = fullTime[1];
      opo_store_buffer[opo_buffer_index].minutes = fullTime[2];
      opo_store_buffer[opo_buffer_index].hours = fullTime[3];
      atomic opo_buffer_index++;
    }
  }

  event void HplRV4162.writeSTBitDone(error_t err) {
    call ResetTimeTimer.startOneShot(20);

  }

  event void HplRV4162.writeMinutesDone(error_t err) {

  }

  event void HplRV4162.resetTimeDone(error_t err) {
    call At45dbPower.start();
  }

  event void ResetTimeTimer.fired() {
    call HplRV4162.resetTime();
  }


  /************************ Helper Functions **********************************/

  inline void setupPins() {
    call TxGate.makeOutput();
    call TxGate.set();
    call TxRxSel.makeOutput();

    call leds2gpio.makeOutput();

    // Sets up SFD Time Capture, although not enabled on any edge
    call SFDCapGpIO.selectModuleFunc();
    call SFDCapGpIO.makeInput();
    call SFDCapControl.setControlAsCapture(1);
    call SFDCapControl.enableEvents();
    call SFDCapControl.clearPendingInterrupt();
    call SFDCapture.setEdge(MSP430TIMER_CM_NONE);

    // set up SFD Latch
    call SFDLatch.makeOutput();

    // Sets up Ultrasonic Time Capture, although not enabled on any edge 
    call UCapGpIO.selectModuleFunc();
    call UCapGpIO.makeInput();
    call UCapControl.setControlAsCapture(1);
    call UCapControl.enableEvents();
    call UCapControl.clearPendingInterrupt();
    call UltrasonicCapture.setEdge(MSP430TIMER_CM_NONE);

    call SFDLatchIntGpIO.makeInput();
    call Amp3_ADC.makeInput();

  }

  /* 
   * TACCR0 = Compare Register, what the timer counts to before rolling over 
   * TACCR1 = Compare register, triggers output changes. 
   * Zero these out to disable the ultrasonic PWM
  */
  inline void startTransducer() {
    atomic {
      TACCR0 = 0x000C;
      TACCR1 = 0x0005;
    }
  }

  inline void stopTransducer() {      
    atomic {
      TACCR0 = 0x0000;
      TACCR1 = 0x0000; 
    }
  }

  /*
   * Sets up Timer A for PWM. 
   * Specifically, this sets up TACCTL1, or Timer A Compare Output 1. 
  */
  inline void setupUltrasonicPWM() {

    // Sets Port16 to be a Timer A module and an output.
    P1SEL = P1SEL | BIT6; 
    P1DIR = P1DIR | BIT6; 

    // Timer A PWM signal controlled by TACCR0 and TACCR1
    // See Start and Stop Transducer for more.     
    // TACTl = Timer A Control Register 
    // TASSEL_2 = Timer A Clock Source select 2 - SMCLK
    // ID_1 = Timer A Input (Clock) Divider - 2
    // MC_1 = Mode Control - Up Mode
    // TAIE = Interrupt Enabled 
    atomic {
      TACTL = 0x0000;
      TACTL = TASSEL_2 | ID_1 | MC_1;
    }
     
    // Timer A Compare register settings
    // CM0 = Capture Mode 0 - Compare instead of Capture
    // CCIS_0 = Capture/compare input select done from CCI1A
    // OUTMOD_3 = Outmode 3, PWM Set on TACCR1, Reset on TACCR0
    // CCIE = Interrupt Enabled 
    atomic {
      TACCTL1 = 0x0000;
      TACCTL1 = CM0 | CCIS_0 | OUTMOD_3 | CCIE;
    }
  }

  inline void setupTACTL() {
    atomic {
      TACTL = 0x0000;
      TACTL = TASSEL_2 | ID_1 | MC_1;
    }
  }

  /*
   * Enables Ultrasnoic Pulse capture
   * Sets SPDT to Receive and turns off Tx power gate
   * Sets up default values
   * this and enableTransmit are oppositues, so you 
   * cannot receive and transmit at the same time
  */ 
  inline void enableReceive() {

    if(opo_buffer_index >= 80) {
      post WriteInfoToDisk();
    }
    else {
      call TxRxSel.clr();
      call TxGate.set();
      call SFDCapture.setEdge(MSP430TIMER_CM_NONE);

      atomic{
          sfd_time = 0;
          rfValid = FALSE; 
          utime = 0;
          range = 0;
          m_state = RX_WAKE;
      }
      call UCapStartTimer.startOneShot(30);
    }
  }

  /* 
   * Disables Ultrasonic and SFD Capture 
   * Sets up SPDT and turns on tx power gate (pfet)
   * Changes isTx to True
   * this and enableReceive are opposites, so you
   * cannot receive and transmit at the same time
  */
  inline void enableTransmit() {
    call UltrasonicCapture.setEdge(MSP430TIMER_CM_NONE);
    call SFDCapture.setEdge(MSP430TIMER_CM_NONE);

    call TxRxSel.set();
    call TxGate.clr();
    
    atomic{
      m_state = TX;
    }
  }

  /* 
   * Sets ranguard to a random multiple of 5, ranging from 0 - 50
   * Meant to be used as a randomized guard time, where the time is 
   * calculated in ms
  */ 
  inline void setRandGuard() {
    atomic{
      randguard = call Random.rand32();
      randguard = (randguard % 51) * 40;
    }
  }

}
