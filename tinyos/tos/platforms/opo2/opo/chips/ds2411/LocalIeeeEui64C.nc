// $Id: LocalIeeeEui64C.nc,v 1.1 2010/02/23 06:45:38 sdhsdh Exp $
/*
 * Copyright (c) 2007, Vanderbilt University
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 *
 * IN NO EVENT SHALL THE VANDERBILT UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE VANDERBILT
 * UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * THE VANDERBILT UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE VANDERBILT UNIVERSITY HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 * Author: Janos Sallai
 * Epic port by Stephen Dawson-Haggerty <stevedh@eecs.berkeley.edu>
 */

configuration LocalIeeeEui64C {
  provides interface LocalIeeeEui64;
  
} implementation {
  
  // Presented interface
  components DallasId48ToIeeeEui64C;
  LocalIeeeEui64 = DallasId48ToIeeeEui64C;
  
  // Onewire
  components PlatformOneWireLowLevelC;
  components OneWireMasterC;
  components BusyWaitMicroC;
  components HplMsp430GeneralIOC as Hpl;
  components new Msp430GpioC() as Gpio;
  
  Gpio.HplGeneralIO -> Hpl.Port24;
  DallasId48ToIeeeEui64C.OneWire -> OneWireMasterC;
  OneWireMasterC.Pin -> Gpio;
  OneWireMasterC.BusyWait -> BusyWaitMicroC;

}
