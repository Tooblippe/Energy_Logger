/*
  Arduino based RF12 enabled energy logger
  Created by Tobie Nortje, tobie.nortje@navitas.co.za
  http://navitas.co.za/tobienortje/
  https://github.com/Tooblippe/Energy_Logger/wiki
  GNU GPL
  
  The current Arduino RX buffer is set to 128 bytes.
  Increased the buffer size to 256, by changing line

OLD
----
  
  #if (RAMEND < 1000)
  #define RX_BUFFER_SIZE 32
#else
  #define RX_BUFFER_SIZE 128    //128 default
#endif

NEW
---- 
 
 #if (RAMEND < 1000)
  #define RX_BUFFER_SIZE 32
#else
  #define RX_BUFFER_SIZE 256     //changes to 256
#endif
*/


