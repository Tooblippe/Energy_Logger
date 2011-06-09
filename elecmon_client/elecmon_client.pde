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

#include <LiquidCrystal.h>
LiquidCrystal lcd(3, 4, 5, 6, 7, 8);
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
byte needToSend = 0;        // set when we want to send
word counter;           // incremented each second
MilliTimer sendTimer;   // used to send once a second
PacketBuffer payload;   // temp buffer to send out
uint8_t myid = 1;
uint8_t freq = RF12_868MHZ;
uint8_t group = 30;

byte ledPin = 9;
byte inByte = 0;
char serInString[30];  // array that will hold the different bytes  100=100characters;
char radioInString[50];  // array that will hold the different bytes  100=100characters;
                      // -> you must state how long the array will be else it won't work.
int  serInIndx  = 0;    // index of serInString[] in which to insert the next incoming byte
int  radioIndx = 0;
int  loadlimit = 2800;  //lets check for geyser


void blink(byte n ){
 pinMode( ledPin, OUTPUT );
 for (byte i = 0; i <n; ++i){
    digitalWrite( ledPin, HIGH ); 
    delay(200); 
    digitalWrite( ledPin, LOW );
  }
}



void setup () {
    Serial.begin(9600);
    Serial.flush();
    Serial.println("I am listening for CT board V2");
    //myId = rf12_config();                  //use the eeprom values
    rf12_initialize( myid, freq, group );    //set values manualy, sender need to be same freq and group.
    
    // start the LCD in 2 rows by 16 characters mode
    lcd.begin(16, 2);
     lcd.setCursor(0, 0);
    lcd.print("waiting...");
    pinMode( ledPin, OUTPUT );
   
}

void loop () {
  
     //set LCD Cursor top left on 16x2 Display
     lcd.setCursor(0, 0);
     
     
     
     //handle a receive event
     //something available?
     if (rf12_recvDone() && rf12_crc == 0) {      // a packet has been received
        //print the buffer to the serial port
        //if OPenlog is connected it will catch it    
        radioIndx = 0;      
        for (byte i = 0; i < rf12_len; ++i){
          // lets create a string beacuse we do not understand c++ data types 
          radioInString[ radioIndx++ ] = rf12_data[i];
        } 
       
        // add EOL
        radioInString[ radioIndx ] = '\0';
        // send it to the terminal
        Serial.print( radioInString );
        
        String instring = String(radioInString);
        // lets look for the reading value...there is a "." in the string somewhere
        if (instring.indexOf(".")>0){
         // found it so print it to the lcd
         lcd.setCursor(0, 0);
         lcd.print(instring);
         
         //now convert the string to a long
         char carray[instring.length() + 1]; //determine size of the array
         instring.toCharArray(carray, sizeof(carray)); //put readStringinto an array
         float invalue = atof( carray );
         
         //lets print something to the lcd if a threshold have been met.
         if (invalue > loadlimit ){
           lcd.print(" ON  ");
           digitalWrite( ledPin, HIGH );
         } else {
             lcd.print( " OFF   ");
             digitalWrite( ledPin, LOW );
         }
        
        }
      }
     
        
     
     //populates an array serInString with the received characters
     while (Serial.available() > 0) {
       // get incoming byte:
       inByte = Serial.read();
       serInString[serInIndx] = inByte;
       serInIndx++;
       //mark te end of string in case it is done
       serInString[serInIndx] = '\0';
       //can we send?
       needToSend = 1;
       delay(20);
     }
     
     //if serial data was received and we can send, send the content of serInString
     if (needToSend && rf12_canSend()) {
            //yes we can sent
            // put serinstring into the buffer           
            payload.print(serInString);
            //now send it to the other side
            rf12_sendStart(0, payload.buffer(), payload.length());
            payload.reset();
            // lets wait a while
            delay(200);
            //Reset needToSend and serInIndx for next time to be set by the serial receive
            needToSend = 0;
            serInIndx = 0;
            Serial.println(serInString);
    }   
    
    
    
}
