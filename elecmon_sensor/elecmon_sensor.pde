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

//----------------------------------------------------------------
//Setup  RF 12 radio
//----------------------------------------------------------------
         
#include <Ports.h>       //need this for rf12 to work - JEENODE
#include <RF12.h>        //rf12 radio
#include <Time.h>        //for timekeeping

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

int updatetime = 10000;

byte myId;              // remember my own node ID
byte needToSend;        // set when we want to send
word counter;           // incremented each second
MilliTimer sendTimer;   // used to send once a second
PacketBuffer payload;   // temp buffer to send out

uint8_t myid = 2;            // radio id - must be unique
uint8_t freq = RF12_868MHZ;  // radio frequency - must be same for all radios
uint8_t group = 30;          // radoi group - must be same for radios
    
char serInString[500];  // array that will hold the different bytes  100=100characters;
                      // -> you must state how long the array will be else it won't work.
int  serInIndx  = 0;    // index of serInString[] in which to insert the next incoming byte

byte debug = 1;        //print strings if 1
byte logging = 1;      //are we logging now 1=yes, 0=no
byte openlogcommandmode = 0;

const char CtrlZ = 26;  //openlog command mode
byte inByte = 0;


#define TIME_HEADER  84    //character T
#define EOLC  0            //asci 0
#define TIME_MSG_LEN  11   // time sync to PC is HEADER followed by unix time_t as ten ascii digits
char c;
//end of RF12 radio setup
//----------------------------------------------------------------



//----------------------------------------------------------------------------
// Start energy monitor
//----------------------------------------------------------------------------
#include "Emon.h"    //Load the library
EnergyMonitor emon;  //Create an instance


 void dbp( char* This ){
   if (debug) {
       Serial.println(This);
   }
 }
//----------------------------------------------------------------------------
// Setup
//----------------------------------------------------------------------------
void setup()
{  
  emon.setPins(5,5);                                 //Energy monitor analog pins, fake the voltage pin to same as current. We are not reading the voltage.
  emon.calibration( 1, 0.171, 1);                    //Energy monitor calibration 0.171
  
  Serial.begin(9600);
  Serial.flush();
  dbp("Current probe v2  ");
  rf12_initialize( myid, freq, group );    //set values manualy, sender need to be same freq and group.
  //myId = rf12_config();                  //use the eeprom values, SEE THE RF12demo sketch how to set this
  setTime(12,35,00,25,5,2011);
  serInString[0] = '/0';
}

//function to send data string via RF12 Radio
void myrf12send(char* This){
rf12_recvDone();
if (rf12_canSend()) {    
        // fill the packet buffer with text to send
          payload.print(This);
          // send out the packet
          rf12_sendStart(0, payload.buffer(), payload.length());
          payload.reset();
          delay(5);
    }
dbp("sent ");
dbp(This);
}

void printDigits(int digits){
// utility function for digital clock display: prints preceding colon and leading 0
  Serial.print(":");
  if(digits < 10)
    Serial.print('0');
  Serial.print(digits);
}

void checkSerialCommand(){
// get a serial command in and into the command array
  
  serInIndx = 0; 
  
  while (Serial.available()){
    delay(1);
     serInString[serInIndx] = Serial.read();
     //increment string pointer
     serInIndx++;
     //mark the end of string in case it is done
      serInString[serInIndx] = '\0';
        
     if (serInIndx > 50 ) {   
      //Serial.println(serInIndx); 
      //myrf12send("more than 60");
      myrf12send(serInString);
      serInIndx = 0; 
      delay(100);
     } 
    }
    
    if (serInIndx > 0 ) {   
      //Serial.println(serInIndx); 
      //myrf12send("more than 60");
      myrf12send(serInString);
      serInIndx = 0; 
     } 
      
 } 
   
    
  


void checkRadioCommand(){
//handle a receive event
     //something available?
     if (rf12_recvDone() && rf12_crc == 0) {      // a packet has been received
        //print the buffer to the serial port
        //if OPenlog is connected it will catch it
        serInIndx = 0;
        for (byte i = 0; i < rf12_len; ++i){
            //print byte for byte
            //Serial.print(rf12_data[i]);
            //also create a string
            serInString[serInIndx] = rf12_data[i];
            //increment string pointer
            serInIndx++;
           //mark te end of string in case it is done
            serInString[serInIndx] = '\0';
          }
     //finish off with an EOL
     //Serial.println();
     //set serInString pointer to 0 for next time
     serInIndx = 0; 
     dbp(serInString);   
     
     }
}

void sendLoggingString(){
//send the loggin data string - Time, Date and Power via RF12 and Serial 
  //has 10 seconds passed
  if (sendTimer.poll(updatetime)) {       // we intend to send every  10000ms = 10 second {TODO - change this to a minute. Average the power use out over that period and send that value....
     //ten seconds have passed so now needtosend = 1
     needToSend = 1;
     ++counter;      
  }

  // can only send when the RF12 driver allows us to and ten seconds have passed
  if (needToSend && rf12_canSend()) {
        needToSend = 0;
          //if logging is set to true - print to serial port
            String hour2 = hour();
            String minute2 = minute();
            String second2 = second();
            String TimeS = hour2 + ":" + minute2 + ":" + second();         
            String DayS = dayStr(weekday());
            String DayN = day();
            String MonthS = monthShortStr(month());
            String YearS = year();
            String DateS = DayS +"," + "" +DayN + " " + MonthS + " " + YearS;
            String FullDate = DateS + ',' + TimeS + ",";
            
          if (logging) {
            Serial.print(FullDate);
            //Serial.print(",");
           // Serial.print(DateS); 
           // Serial.print(","); 
            Serial.println(emon.apparentPower); 
          
          // fill the packet buffer with text to send via rf12 also  
          payload.print(FullDate);
          // send out the packet
          rf12_sendStart(0, payload.buffer(), payload.length());
          payload.reset();
          delay(200);
          payload.print(emon.apparentPower);
          // send out the packet
          rf12_sendStart(0, payload.buffer(), payload.length());
          payload.reset();
          delay(200);
          }
    }
}


//---------------------------- ------------------------------------------------
// Main loop
//----------------------------------------------------------------------------
void loop()
{
  //we can send commands in by serial aswell
  checkSerialCommand();
  //have we received an order via RF12?  
  checkRadioCommand();  
  
  if (logging){                    //are we in command mode? need to reset to get out of it, exclusice use to uart
    //Energy Monitor calc function
    //Rerurns value in emon.apparentPower
    //need to start doing some averaging here
    emon.calc(50,2000);                  
    //send the logged value via RF12 and serial
    sendLoggingString();    
   } 
  
  //now analyse the command  
    if (strcmp(serInString, "debug")  == 0 )
    {
      debug = !debug;
      serInString[1] = '\0';
      myrf12send("debugging toggled");
      serInIndx = 0; 
      serInString[0] = '\0';
    }
   
   if (strcmp(serInString, "--")  == 0 )
    {
      updatetime = updatetime - 1000;
      serInString[1] = '\0';
      myrf12send("Loggin decremented");
      serInIndx = 0; 
      serInString[0] = '\0';
    }
    
    if (strcmp(serInString, "++")  == 0 )
    {
      
      updatetime = updatetime + 1000;
      serInString[1] = '\0';
      myrf12send("Loggin incremented");
      serInIndx = 0; 
      serInString[0] = '\0';
      
    }
    
    if (strcmp(serInString, "logging")  == 0 )
    {
      logging = !logging;
      serInString[1] = '\0';
      myrf12send("remote logging toggled ");
      serInIndx = 0; 
      serInString[0] = '\0';
  
    }
    
    if (serInString[0] == TIME_HEADER)    //did we get a T for the time message
    {
      
      //reset the command string
      serInString[0] = '\0';
      // create a time variable                     
      time_t pctime = 0;
      for(int i=0; i < TIME_MSG_LEN -1; i++){   
       // convert the sting into a number
        c = serInString[i];         
        if( c >= '0' && c <= '9'){   
          pctime = (10 * pctime) + (c - '0') ; // convert digits to a number    
        }
      }   
      setTime(pctime);   // Sync Arduino clock to the time received on the serial port
      myrf12send("TIME SET");
      serInIndx = 0; 
      serInString[0] = '\0';
  
    }
    
    if (strcmp(serInString, "clock")  == 0 )
    {
      //change this to a functiom amd write to opemlog
      serInString[1] = '\0';
      Serial.print(hour());
      printDigits(minute());
      printDigits(second());
      Serial.print(" ");
      Serial.print(dayStr(weekday()));
      Serial.print(" ");
      Serial.print(day());
      Serial.print(" ");
      Serial.print(monthShortStr(month()));
      Serial.print(" ");
      Serial.print(year()); 
      Serial.println(); 
      serInString[0] = '\0';
      serInIndx = 0; 

  
    }
     
   if (strcmp(serInString, "zzz")  == 0 )
    {
      Serial.print( 26, BYTE );
      Serial.print( 26, BYTE );
      Serial.print( 26, BYTE );
      logging = 0;
      debug = 0;
      int wait = 200;
      delay(wait);
      openlogcommandmode = 1;          //we are now in command mode
      myrf12send("openlog opened");  
      serInIndx = 0;   
      serInString[0] = '\0' ;
      Serial.print( 13, BYTE );
      Serial.print( 13, BYTE );
      Serial.print( 13, BYTE );
      
      
    }
    
     if (strcmp(serInString, "disk")  == 0 )
    {
       Serial.print( 13, BYTE );
       int wait = 200;
       delay(wait);
       Serial.flush();
       
      Serial.println( "disk");
      serInIndx = 0;   
      serInString[0] = '\0';
     
    }  

    if (strcmp(serInString, "set") == 0)
    {
       Serial.print( 13, BYTE );
       int wait = 200;
       delay(wait);
       Serial.flush();
       Serial.println( "set");
       serInIndx = 0;   
       serInString[0] = '\0';
    } 
  
  if (strcmp(serInString, "???") == 0)
    {
      Serial.print( 13, BYTE );
      Serial.print( 13, BYTE );
      Serial.print( 13, BYTE );
      Serial.print( 13, BYTE );
       int wait = 200;
       delay(wait);
       Serial.flush();
       delay(wait);
       Serial.flush();
       delay(wait);
       Serial.flush();
       Serial.println( "?");
       delay(20);
       serInIndx = 0;   
       serInString[0] = '\0';
      
    } 
    if (strcmp(serInString, "ls") == 0)
    {
      Serial.print( 13, BYTE );
       int wait = 200;
       delay(wait);
       Serial.flush();
       Serial.println( "ls");
       serInIndx = 0;   
       serInString[0] = '\0';
      
    } 
    
    if (strcmp(serInString, "flush") == 0)
    {
      Serial.flush();
    } 
      
    
    
   
    
    
    
}      
      



