

hallo =  """
Arduino data logger by Tobie Nortje - tobie.nortje@navitas.co.za
find project info at - www.navitas.co.za/tooblogger
-----------------------------------------------------------------
Project components
1 or 2 arduinos with or without an RF 12 radio
1 x 100 AMP CT
1st arduino with CT logs energy and send via RF12 radio and serial
2nd arduino receives RF12 signal and send value via serial port
This software can read eiter, or both if ran on seperate computers or ports
-----------------------------------------------------------------
Function
Listens to serial port at port number = port at baud = baud
Arduino only sents one value every couple of seconds.
This code should be able to read the sensor board and the client board.
Do with the code what you want. \n
-----------------------------------------------------------------
File format : logs to csv in DATE, TIME, POWER
-----------------------------------------------------------------
Arduino UNO - connected current probe and RF12 Radio
Current probe - 100A, SCT-013-00, order from NETRAM - http://www.netram.co.za/Sensors/Non-invasive-AC-current-sensor-100A.html
Current probe - http://www.seeedstudio.com/depot/noninvasive-ac-current-sensor-100a-max-p-547.html
Current probe - bias resistors 2x10kOhm and 10uF Capacitor. Burden Resistor - 56 OHMS (used 6 330 OHM in parralel )
Current probe - more info at - http://openenergymonitor.org/emon/node/28
------------------------------------------------------------------------------------------------------------------------------
RF 12 radio connected via SPI - all my notes here - http://forum.jeelabs.net/comment/728#comment-728
------------------------------------------------------------------------------------------------------------------------------
"""

import sys
import string
import serial
import time
import eeml

#pachube keys
API_KEY = 'cQJdEUnKaHA00J1N-PKDtpARMrnv5ShkB3Es9Tz-y74'
API_URL = '/api/24461.xml'
port = 4
baud = 9600
pachube_update = 6   #roughtly update pachube every 60s
cperkwh = 72

#date formatting
fmt1 = '%m/%d/%Y'
fmt2 = '%H:%M:%S'

#log to filename
filename = "C:\\temp\\openlog.csv"



#setup serial comms
ser = serial.Serial(port, baud)

print hallo
print "Logging data to csv file in format DATE, TIME, POWER: " + filename
print "Listening to port: " + str(port) + " at " +str(baud) + "baud"
print "The following was sent by the arduino at startup"
print "-----------------------------------------------------------------"
print ser.readline()
print ser.readline()              #arduino resets when connected. get rid of initial inputs sent
print ser.readline()
print ser.readline()
print ser.readline()
print ser.readline()
print ser.readline()
print ser.readline()

minute = 0
average = 0.0
halfhour = [ 0 for i in range(29)]
energy = 0
cost = 0
instP = 0

print "INCOMING DATA FROM ARDUINO"
print "----------------------------------------------------"
print "    DATE       TIME       POWER              AVERAGE"
print "----------------------------------------------------"
while 1:
  val = ser.readline()
  if val > 0 :
    
    minute = minute +1
        
    average = (average + float(val))/ 2.0
    readingstring = str(val)
    tests = readingstring[0:len(readingstring)-1]  #remove newline caracter received from arduino
    instP = float(tests)/1000
    energy = energy + (float(tests) * (10.0/60.0/60.0) /1000.0)

    cost = (cost + energy*cperkwh)/100.0

    

    try:
      f = open( filename, "a" )                       #log it to file
      f.write( time.strftime(fmt1) +"," + time.strftime(fmt2) +"," + tests )
      f.close()
    except:
      print "that file could not be opened - " + filename
    
    print time.strftime(fmt1) + " , " + time.strftime(fmt2)+ " , " + tests + "W , " + "" + str(minute) + " ave " +str(round(average,2)) +", SUM Energy " + str(round(energy,3)) + "kWh, Cost R" + str(round(cost,2)) + " ,R/Minute " +str(round(instP*(1/60)/100.0*cperkwh,2)) + " ,R/Hour " +str(round(instP*cperkwh/100.0,2)) +" ,R/month " +str(round(instP*cperkwh/100.0*24*30.0,2))

    if minute == pachube_update:                         #update pachube
      try:
        pac = eeml.Pachube(API_URL, API_KEY)
        pac.update([eeml.Data(0, average) ])
        pac.put()
        print "updated pachube"
        print "----------------------------------------------------"
        print "    DATE       TIME       POWER              AVERAGE"
        print "----------------------------------------------------"
        minute = 0
        avarage = val
      except:
        print "pachube not available - will try next time"
        print "----------------------------------------------------"
        print "    DATE       TIME       POWER              AVERAGE"
        print "----------------------------------------------------"
        minute = 0
        avarage = val

        
    #add the half hour incrementer here and send to different file!
"""
//------------------------------------------------------------------------------------------------------------------------------
// Current monitor and logger
// tobie.nortje@navitas.co.za
// www.navitas.co.za
//------------------------------------------------------------------------------------------------------------------------------
// Setup
// Arduino UNO - connected current probe and RF12 Radio
// Current probe - 100A, SCT-013-00, order from NETRAM - http://www.netram.co.za/Sensors/Non-invasive-AC-current-sensor-100A.html
// Current probe - http://www.seeedstudio.com/depot/noninvasive-ac-current-sensor-100a-max-p-547.html
// Current probe - bias resistors 2x10kOhm and 10uF Capacitor. Burden Resistor - 56 OHMS (used 6 330 OHM in parralel )
// Current probe - more info at - http://openenergymonitor.org/emon/node/28
//------------------------------------------------------------------------------------------------------------------------------
// RF 12 radio connected via SPI - all my notes here - http://forum.jeelabs.net/comment/728#comment-728
//------------------------------------------------------------------------------------------------------------------------------

// This example shows how to fill a packet buffer with strings and send them
// 2010-MM-DD <jcw@equi4.com> http://opensource.org/licenses/mit-license.php
// $Id: packetBuf.pde 6049 2010-09-27 09:21:37Z jcw $

// Note: this demo code sends with broadcasting, so each node will see data
// from every other node running this same sketch. The node ID's don't matter
// (they can even be the same!) but all the nodes have to be in the same group.
// Use the RF12demo sketch to initialize the band/group/nodeid in EEPROM.
 
#include <Ports.h>
#include <RF12.h>

// Utility class to fill a buffer with string data

class PacketBuffer : public Print {
public:
    PacketBuffer () : fill (0) {}
    
    const byte* buffer() { return buf; }
    byte length() { return fill; }
    void reset() { fill = 0; }

    virtual void write(uint8_t ch)
        { if (fill < sizeof buf) buf[fill++] = ch; }
    
private:
    byte fill, buf[RF12_MAXDATA];
};

byte myId;              // remember my own node ID
byte needToSend;        // set when we want to send
word counter;           // incremented each second
MilliTimer sendTimer;   // used to send once a second
PacketBuffer payload;   // temp buffer to send out

void setup () {
    Serial.begin(9600);
          Serial.println("I am listening");
         Serial.println("--------------");
          myId = rf12_config();
         Serial.println("--------------");
}
void loop () {
    if (rf12_recvDone() && rf12_crc == 0) {
        // a packet has been received
        //Serial.print("RX OK -  ");
        for (byte i = 0; i < rf12_len; ++i)
            Serial.print(rf12_data[i]);
        Serial.println();                    
    }
   
   
}
"""

"""
CT monitor side

//------------------------------------------------------------------------------------------------------------------------------
// Current monitor and logger
// tobie.nortje@navitas.co.za
// www.navitas.co.za
//------------------------------------------------------------------------------------------------------------------------------
// Setup
// Arduino UNO - connected current probe and RF12 Radio
// Current probe - 100A, SCT-013-00, order from NETRAM - http://www.netram.co.za/Sensors/Non-invasive-AC-current-sensor-100A.html
// Current probe - http://www.seeedstudio.com/depot/noninvasive-ac-current-sensor-100a-max-p-547.html
// Current probe - bias resistors 2x10kOhm and 10uF Capacitor. Burden Resistor - 56 OHMS (used 6 330 OHM in parralel )
// Current probe - more info at - http://openenergymonitor.org/emon/node/28
//------------------------------------------------------------------------------------------------------------------------------
// RF 12 radio connected via SPI - all my notes here - http://forum.jeelabs.net/comment/728#comment-728
//------------------------------------------------------------------------------------------------------------------------------

//SD CARD for shield
const int   SDSelect = 4;   //SD card select on pin 4 on Eternet Shield
char*     logFile = "17APRIL.txt";

//----------------------------------------------------------------
//Setup  RF 12 radio
//----------------------------------------------------------------
#include <SD.h>
#include <Ports.h>
#include <RF12.h>

class PacketBuffer : public Print {
public:
    PacketBuffer () : fill (0) {}
    
    const byte* buffer() { return buf; }
    byte length() { return fill; }
    void reset() { fill = 0; }

    virtual void write(uint8_t ch)
        { if (fill < sizeof buf) buf[fill++] = ch; }
    
private:
    byte fill, buf[RF12_MAXDATA];
};

byte myId;              // remember my own node ID
byte needToSend;        // set when we want to send
word counter;           // incremented each second
MilliTimer sendTimer;   // used to send once a second
PacketBuffer payload;   // temp buffer to send out
//end of RF12 radio setup
//----------------------------------------------------------------

//SETUP SD CARD
//---------------------------------------------------------------------------
//----------------------------------------------------------------------------


//----------------------------------------------------------------------------
// Start energy monitor
//----------------------------------------------------------------------------
#include "Emon.h"    //Load the library
EnergyMonitor emon;  //Create an instance

//----------------------------------------------------------------------------
// Setup
//----------------------------------------------------------------------------
void setup()
{  
  
  
  emon.setPins(5,5);                                 //Energy monitor analog pins, fake the voltage pin to same as current. We are not reading the voltage.
  emon.calibration( 1, 0.171, 1);                    //Energy monitor calibration
  
  Serial.begin(9600);
  Serial.println("-------------------- ");
  Serial.println(" Current probe  ");
  Serial.println("-------------------- ");
  myId = rf12_config();
  Serial.print("Radio ready with ID: "); 
  Serial.println(myId,DEC);
  Serial.println("---------------------");
}

//---------------------------- ------------------------------------------------
// Main loop
//----------------------------------------------------------------------------
void loop()
{
  //Serial.println("hallo");
  emon.calc(50,2000);              //Energy Monitor calc function
  
  
  //send the value of apparentPower as calculator from emon.calc above
  Serial.print(emon.apparentPower);
  //Serial.println(" W ");
  
  //rf12 radio------------------------------------------------------------------
    rf12_recvDone();                  // need to call this all the time
 
    if (sendTimer.poll(10000)) {       // we intend to send every  10000ms = 10 second {TODO - change this to a minute. Average the power use out over that period and send that value....
        needToSend = 1;
        ++counter;      
    }

    // can only send when the RF12 driver allows us to
    if (needToSend && rf12_canSend()) {
        needToSend = 0;
        // fill the packet buffer with text to send
          //payload.print(counter);
          //payload.print(" P: ");
          payload.print(emon.apparentPower);
          //payload.print("W");
        // send out the packet
          rf12_sendStart(0, payload.buffer(), payload.length());
          payload.reset();
    }
    //rf12 radio------------------------------------------------------------------
    
    if (!SD.begin(SDSelect)) {
        ///Serial.println( "N" );
          File dataFile = SD.open( logFile, FILE_WRITE);
            // if the file is available, write to it:
             if (dataFile) {
             dataFile.println(emon.apparentPower);
             dataFile.close();   
             Serial.println("logged to sd");
             
      } else {    }
    }
      
  delay(200);
}
//----------------------------------------------------------------------------

"""
