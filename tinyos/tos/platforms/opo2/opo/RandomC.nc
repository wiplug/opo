/*
 * Copyright (c) 2002-2005 The Regents of the University  of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the University of California nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * Random interface wired to M twist PRNG.
 *
 * @author  William Huang
 * @date    2013
 */

configuration RandomC {
  provides interface Init;
  provides interface ParameterInit<uint16_t> as SeedInit;
  provides interface Random;
}

implementation {
  components RandomMlcgC, MainC;

  MainC.SoftwareInit -> RandomMlcgC;

  Init = RandomMlcgC;
  SeedInit = RandomMlcgC;
  Random = RandomMlcgC;

}


/*
configuration RandomC {
  provides {
  	interface Init;
  	interface ParameterInit<uint32_t> as SeedInit;
  	interface Random;
  }
}

implementation {
  components RandomMlcgC, MainC, LedsC;
  //RandomMtC.Leds -> LedsC.Leds;
  MainC.SoftwareInit -> RandomMlcgC;

  Init = RandomMlcgC;
  SeedInit = RandomMlcgC;
  Random = RandomMlcgC;

  //components Ds2411C;
  //RandomMtC.IdReader -> Ds2411C.ReadId48;
}
*/