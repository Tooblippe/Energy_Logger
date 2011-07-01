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
//FloatToString function from http://www.arduino.cc/playground/Main/FloatToString
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

int updatetime = 10000;  //update frequency

//byte myId;              // remember my own node ID
byte needToSend;        // set when we want to send
word counter;           // incremented each second
MilliTimer sendTimer;   // used to send once a second
PacketBuffer payload;   // temp buffer to send out

uint8_t myid = 2;            // radio id - must be unique
uint8_t freq = RF12_868MHZ;  // radio frequency - must be same for all radios
uint8_t group = 30;          // radoi group - must be same for radios
    
char serInString[100];  // array that will hold the different bytes  100=100characters;
                      // -> you must state how long the array will be else it won't work.
int  serInIndx  = 0;    // index of serInString[] in which to insert the next incoming byte

byte debug = 0;        //print strings if 1
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



// Start energy monitor
#include "Emon.h"    //Load the library
EnergyMonitor emon;  //Create an instance

//debug printing function. this thing logs to an openlog. everything sent to the serial port will be logged. this turns it off.
void dbp( char* This ){
   if (debug) {
       Serial.println(This);
   }
 }

// Setup function
void setup()
{  
  emon.setPins(5,5);                                 //Energy monitor analog pins, fake the voltage pin to same as current this is important. We are not reading the voltage.
  emon.calibration( 1, 0.171, 1);                    //Energy monitor calibration 0.171, EnergyMonitor::calibration(double _VCAL, double _ICAL, double _PHASECAL)
  
  Serial.begin(4800);                      //we need to chat as slow as possible to OPENLOG and as fast as possible witht RF12 radio to get the data ou and avoid serial data loss
  Serial.flush();
  dbp("Current probe v2  ");
  rf12_initialize( myid, freq, group );    //set values manualy, sender need to be same freq and group.
  //myId = rf12_config();                  //use the eeprom values, SEE THE RF12demo sketch how to set this
  setTime(12,35,00,25,5,2011);
  serInString[0] = '/0';
}

//function to convert a float to a char array
char * floatToString(char* outstr, float value, int places, int minwidth, bool rightjustify) {
    // source - http://www.arduino.cc/playground/Main/FloatToString  
    // this is used to write a float value to string, outstr.  oustr is also the return value.
    int digit;
    float tens = 0.1;
    int tenscount = 0;
    int i;
    float tempfloat = value;
    int c = 0;
    int charcount = 1;
    int extra = 0;
    // make sure we round properly. this could use pow from <math.h>, but doesn't seem worth the import
    // if this rounding step isn't here, the value  54.321 prints as 54.3209

    // calculate rounding term d:   0.5/pow(10,places)  
    float d = 0.5;
    if (value < 0)
        d *= -1.0;
    // divide by ten for each decimal place
    for (i = 0; i < places; i++)
        d/= 10.0;    
    // this small addition, combined with truncation will round our values properly 
    tempfloat +=  d;

    // first get value tens to be the large power of ten less than value    
    if (value < 0)
        tempfloat *= -1.0;
    while ((tens * 10.0) <= tempfloat) {
        tens *= 10.0;
        tenscount += 1;
    }

    if (tenscount > 0)
        charcount += tenscount;
    else
        charcount += 1;

    if (value < 0)
        charcount += 1;
    charcount += 1 + places;

    minwidth += 1; // both count the null final character
    if (minwidth > charcount){        
        extra = minwidth - charcount;
        charcount = minwidth;
    }

    if (extra > 0 and rightjustify) {
        for (int i = 0; i< extra; i++) {
            outstr[c++] = ' ';
        }
    }

    // write out the negative if needed
    if (value < 0)
        outstr[c++] = '-';

    if (tenscount == 0) 
        outstr[c++] = '0';

    for (i=0; i< tenscount; i++) {
        digit = (int) (tempfloat/tens);
        itoa(digit, &outstr[c++], 10);
        tempfloat = tempfloat - ((float)digit * tens);
        tens /= 10.0;
    }

    // if no places after decimal, stop now and return

    // otherwise, write the point and continue on
    if (places > 0)
    outstr[c++] = '.';


    // now write out each decimal place by shifting digits one by one into the ones place and writing the truncated value
    for (i = 0; i < places; i++) {
        tempfloat *= 10.0; 
        digit = (int) tempfloat;
        itoa(digit, &outstr[c++], 10);
        // once written, subtract off that digit
        tempfloat = tempfloat - (float) digit; 
    }
    if (extra > 0 and not rightjustify) {
        for (int i = 0; i< extra; i++) {
            outstr[c++] = ' ';
        }
    }

    outstr[c++] = '\0';
    return outstr;
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
    delay(50);
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
    //delay(1);
     serInString[serInIndx++] = Serial.read();
     //increment string pointer
     //serInIndx++;
     //mark the end of string in case it is done
      serInString[serInIndx] = '\0'; 
      if (serInIndx > 50 ) {   
        //Serial.println(serInIndx); 
        //myrf12send("more than 60");
        myrf12send(serInString);
        serInIndx = 0; 
        //delay(100);
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



if (sendTimer.poll(updatetime)) {       
   // we intend to send every  10000ms = 10 second {TODO - change this to a minute. Average the power use out over that period and send that value....
   //ten seconds have passed so now needtosend = 1
   needToSend = 1;
   ++counter;      
}


  // can only send when the RF12 driver allows us to and ten seconds have passed
  if (needToSend && rf12_canSend()) {
            needToSend = 0;
            //if logging is set to true - print to serial port , need to optimise this lot here...ugly
            String hour2 = hour();
            String minute2 = minute();
            //String second2 = second();
            String TimeS = hour2 + ":" + minute2 + ":" + second();         
            String DayS = dayStr(weekday());
            String DayN = day();
            String MonthS = monthShortStr(month());
            String YearS = year();
            String DateS = DayS +"," + "" +DayN + " " + MonthS + " " + YearS;
            String FullDate = DateS + ',' + TimeS + "," ;
            
            
            //experimental code to convert a double to a string
            //lets change the double of apparentpower to a float
            float PowerFloat = emon.apparentPower;
            char PowerChar[10];
            //lets change the float to a string 
            floatToString(PowerChar, PowerFloat, 2, 0, false);
            String PowerString = String( PowerChar );
            String CompleteMessage = FullDate + PowerString + '\n';   //use this below now------------------------------------------------------------------------------------------------------
           
            
            if (logging) {
              //Serial.print(FullDate);
              //Serial.println(emon.apparentPower); 
            
              dbp("whole message--->  "); 
              Serial.print( CompleteMessage );
            
          
          // fill the packet buffer with text to send via rf12 also  
          
          // nB this needs to be optimsed to one send...maybe send the T string? you can decode on other side.
          
//          payload.print(FullDate);
//          // send out the packet
//          rf12_sendStart(0, payload.buffer(), payload.length());
//          payload.reset();
//          delay(200);
//          
//          payload.print(emon.apparentPower);
//          // send out the packet
//          rf12_sendStart(0, payload.buffer(), payload.length());
//          payload.reset();
//          delay(200);
//          
//          byte newline = '\n';
//          payload.print(newline);
//          // send out the packet
//          rf12_sendStart(0, payload.buffer(), payload.length());
//          payload.reset();
//          delay(200);
          
          
            //shouldnt we add receive done here? it is in the myrf12send function?, now send only once
            payload.print( CompleteMessage );
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
      myrf12send("Loggin decremented");
      serInIndx = 0; 
      serInString[0] = '\0';
    }
    
    if (strcmp(serInString, "++")  == 0 )
    {
      
      updatetime = updatetime + 1000;
      myrf12send("Loggin incremented");
      serInIndx = 0; 
      serInString[0] = '\0';
      
    }
    
    if (strcmp(serInString, "logging")  == 0 )
    {
      logging = !logging;
      myrf12send("remote logging toggled ");
      serInIndx = 0; 
      serInString[0] = '\0';
  
    }
    
    if ((serInString[0] == TIME_HEADER)  && logging )    //did we get a T for the time message
    {
      // create a time variable                     
      time_t pctime = 0;
      
      for(int i=1; i < TIME_MSG_LEN; i++){   
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
      
       int wait = 200;
       delay(wait);
       Serial.flush();
       delay(wait);
       Serial.println( "?");
       delay(20);
       serInIndx = 0;   
       serInString[0] = '\0';
      
    } 
    if (strcmp(serInString, "data") == 0)
    {
       Serial.print( 13, BYTE );
       int wait = 200;
       delay(wait);
       Serial.flush();
       Serial.println( "read SEQLOG00.TXT");
       serInIndx = 0;   
       serInString[0] = '\0';
      
    } 
    
    
    if (strcmp(serInString, "reset") == 0)
    {
       Serial.print( 13, BYTE );
       int wait = 200;
       delay(wait);
       Serial.flush();
       Serial.println( "reset");
       serInIndx = 0;   
       serInString[0] = '\0';
       logging = 1;            //we can now log again
      
    } 
    
    if (strcmp(serInString, "flush") == 0)
    {
      Serial.flush();
    } 
     
     
   
    
    
    
}      
      



