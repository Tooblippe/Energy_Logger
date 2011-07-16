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
//-------------------------------------------------------------------------------------         


#include <Wire.h>          //communicates via singel wire on A5 and A4
#include "Emon.h"      
#include <Fat16.h>
#include <Fat16util.h>     // use functions to print strings from flash memory
//#include <avr/wdt.h>
#include <LiquidCrystal.h>
#include <EEPROM.h>
#include <NewSoftSerial.h>  //Include the NewSoftSerial library to send serial commands to the cellular module.
#include <string.h>         //Used for string manipulations

SdCard card;
Fat16 file;

//#define  RX8025_address  0x32
#define DS1307_I2C_ADDRESS 0x68  // This is the I2C address
#define supply_voltage 220
#define mobilenumber "0832270729"


unsigned char RX8025_Control[2]={0x20,0x00};
unsigned char RX8025_time[7]=   {0x55,0x59,0x23,0x7,0x10,0x07,0x11}; //second, minute, hour, week, date, month, year, BCD format
unsigned char hour=0;
unsigned char minute=0;
unsigned char second=0;
unsigned char week=0;
unsigned char year=0;
unsigned char month=0;
unsigned char date=0;

LiquidCrystal lcd(9, 8, 7, 6, 5, 4);

EnergyMonitor emon;  //Create an instance

NewSoftSerial cell(2,3);  //Create a 'fake' serial port. Pin 2 is the Rx pin, pin 3 is the Tx pin.

byte      debug = 1;        //print strings if 1
byte      logging = 1;      //are we logging now 1=yes, 0=no
boolean   start = true;
long      count = 0L;
long      runningtime = 0L;
long      powersum = 0L;
int       nsamples = 1;
int       updatetime = 10000;  //update frequency
int       incrementsize = 2000;
float     convertedtemp; /* We then need to multiply our two bytes by a scaling factor, mentioned in the datasheet. */
int       tmp102_val; /* an int is capable of storing two bytes, this is where we "chuck" the two bytes together. */
char      name[] = "werk4.csv";
int       incomingbyte;
int       logdelayaddr = 0;
char      cell_incoming_char=0;      //Will hold the incoming character from the Serial Port.
int      rings=0;

//debug printing function. this thing logs to an openlog. everything sent to the serial port will be logged. this turns it off.
void dbp( char* This ){if (debug) {Serial.println(This);}}


void printTime(){
    getRtcTime(); 
    delay(20);  
    switch(week)
    {
      case 0x00: { Serial.print( "Sun,");   break; }
      case 0x01: { Serial.print( "Mon,");   break; }
      case 0x02: { Serial.print( "Tues,");  break; }
      case 0x03: { Serial.print( "Wed,");   break; }
      case 0x04: { Serial.print( "Thu,");   break; }
      case 0x05: { Serial.print( "Fri,");   break; }
      case 0x06: { Serial.print( "Sat,");   break; }
    }
    Serial.print(date, DEC );  Serial.print("/");  Serial.print(month, DEC ); Serial.print("/20"); Serial.print(year,DEC );
    Serial.print(",");
    Serial.print(hour, DEC );  Serial.print(":");  Serial.print(minute,DEC);  Serial.print(":");  Serial.print(second,DEC);
}

void createLoggingString(){
      
    switch(week)
    {
    case 0x00:
      {
       Serial.print( "Sun,");   
       file.print( "Sun,"); 
        break;
      }
    case 0x01:
      {
        Serial.print( "Mon,");   
         file.print( "Mon,"); 
        break;
      }
    case 0x02:
      {
        Serial.print( "Tues,");   
        file.print( "Tues,"); 
        break;
      }
    case 0x03:
      {
        Serial.print( "Wed,");   
        file.print( "Wed,"); 
        break;
      }
    case 0x04:
      {
        Serial.print( "Thur,");   
         file.print( "Thur,"); 
        break;
      }
    case 0x05:
      {
        Serial.print( "Fri,");   
         file.print( "Fri,"); 
        break;
      }
    case 0x06:
      {
        Serial.print( "Sat,");   
        file.print( "Sat,"); 
        break;
      }
    }
     
     
      
  Serial.print(date, DEC );  Serial.print("/");  Serial.print(month, DEC );  Serial.print("/20");  Serial.print(year,DEC );
  Serial.print(",");
  Serial.print(hour, DEC );  Serial.print(":");  Serial.print(minute,DEC);  Serial.print(":");  Serial.print(second,DEC);
  
  Serial.print(",Temp,");  Serial.print(convertedtemp);
  
  Serial.print(",Power,");
  Serial.print(emon.apparentPower);
  
  Serial.print( ",amps,");
  Serial.print(emon.apparentPower/230);
  
  if (start){Serial.print(",startup");}
  
  if (file.writeError) {
        Serial.println(",file system error, entering sleep mode");         //you will have to reset now!
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("CARD ERR - SLEEP"); delay(1000);
        while (1){digitalWrite(8, HIGH); delay(100); digitalWrite(8, LOW);}
    } else Serial.println();
    
  file.print(date, DEC );  file.print("/");  file.print(month, DEC );  file.print("/20");  file.print(year,DEC );
  file.print(",");
  file.print(hour, DEC );  file.print(":");  file.print(minute,DEC);  file.print(":");  file.print(second,DEC);
  
  file.print(",Temp,");
  file.print(convertedtemp);
  
  file.print(",Power,");
  file.print(emon.apparentPower);
   
   if (start){
        start = false;
        file.println(",startup");} else file.println();
   }

// Setup function
void setup()
{  
  Serial.begin(115200);                                  //we need to chat as slow as possible to OPENLOG and as fast as possible witht RF12 radio to get the data ou and avoid serial data loss
  Wire.begin();
  
  lcd.begin(16, 2); lcd.setCursor(0, 0); lcd.clear();
  lcd.print("booting cellcomms");
  
  cell.begin(9600);
  Serial.println("Booting cell");
  delay(31000); // give time for GSM module to register on network etc.
  cell.println("AT+CMGF=1"); // set SMS mode to text
  delay(200);
  if (cell.available() > 0){ while (cell.available() > 0) Serial.print( cell.read(),BYTE); }
  
  delay(500);
  cell.println("AT+CNMI=3,3,0,0"); // set module to send SMS data to serial out upon receipt
  delay(200);
  if (cell.available() > 0){ while (cell.available() > 0) Serial.print( cell.read(),BYTE  ); }
  delay(200);
  cell.println("AT+CMGD=1,4"); // delete all SMS
  delay(200);
  if (cell.available() > 0){ while (cell.available() > 0) Serial.print( cell.read(),BYTE  ); }
  //Let's get started!
  Serial.println("SM5100B Communication should be ready...");
  
  lcd.begin(16, 2); lcd.setCursor(0, 0); lcd.clear(); 
 
   Serial.println("-");
    
    // initialize the SD card
    Serial.println("1. start card");
    lcd.setCursor(0, 0);
    lcd.print("1.card ");
    pinMode(4, OUTPUT); digitalWrite(4, HIGH);
    delay(15);
    if (!card.init()) {
          PgmPrintln(">>>> !error");
          lcd.print(">>ERR");
         digitalWrite(8,HIGH);//LED pin set to OUTPUT
    }
  
 
    // initialize a FAT16 volume
     lcd.setCursor(0, 1);
     delay(1000);
     lcd.print("2.filesys ");
     Serial.println("2. filesyst");
     if (!Fat16::init(&card)) {
        PgmPrintln(">>>> !error");
        lcd.print(">>ERR");
       digitalWrite(8,HIGH);//LED pin set to OUTPUT
    }
    
     PgmPrintln("Name          Modify Date/Time    Size");
  
    Fat16::ls(LS_DATE | LS_SIZE);
   
    Serial.println("3. CT");
    emon.setPins(A0,A0);                                 //Energy monitor analog pins, fake the voltage pin to same as current this is important. We are not reading the voltage.
    emon.calibration( 1, 0.171, 1);                      //Energy monitor calibration 0.171, EnergyMonitor::calibration(double _VCAL, double _ICAL, double _PHASECAL) 1, 0.171, 1 ----- 1.660556, 0.011000, 1.5  stalk0.111
    emon.calc(50,2000);                                   //get the jitters out
     
    Serial.print("5. time: "); 
    printTime(); 
    Serial.println();
  
    Serial.print("6. file: "); Serial.println( name );
    dbp("syst init");
    
    Serial.print("7. update time in seconds ");
    updatetime = EEPROM.read(logdelayaddr)*incrementsize;
    Serial.println( updatetime );
    
    Serial.println("--");Serial.println();
    
    runningtime = millis();
    //getTemp102();
   }
//---------------------------- ------------------------------------------------
// Main loop
//----------------------------------------------------------------------------
void loop()
{
    
if (millis()-runningtime > updatetime){
  if (logging){      //are we in command mode? need to reset to get out of it, exclusice use to uart
      runningtime = millis();
      //Energy Monitor calc function
      //Rerurns value in emon.apparentPower
     
      emon.calc(50,2000);   
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("P");
      lcd.print(emon.apparentPower);
      lcd.print("W D");
      //lcd.print( updatetime / 1000 );
      
      //----average
      powersum = powersum + emon.apparentPower;
      lcd.print( powersum / nsamples++ );
        
      getRtcTime(); 
      lcd.setCursor(0,1);
      if( hour  < 10 ) lcd.print("0");
      lcd.print(hour, DEC );
      lcd.print(":");
      if( minute < 10) lcd.print("0");
      
      
      
      lcd.print(":");
      if( second <10) lcd.print("0");
      lcd.print(second,DEC);
      
      
      lcd.print(" ");
      lcd.print( powersum / nsamples * 24 *30 * 1 / 1000 );
      
      lcd.print(" ");
      lcd.print(emon.apparentPower / 230 );
      
    
       file.writeError = false;
       file.open(name, O_CREAT | O_APPEND | O_WRITE);
       createLoggingString() ;
       file.close();     
      
      
        checkserial();
        checkcell();
     }    
     
    
  } else
  {
     getRtcTime(); 
      lcd.setCursor(0,1);
      if( hour  < 10 ) lcd.print("0");
      lcd.print(hour, DEC );
      lcd.print(":");
      if( minute < 10) lcd.print("0");
      lcd.print(minute,DEC);
      lcd.print(":");
      if( second <10) lcd.print("0");
      lcd.print(second,DEC);
      
     checkserial(); 
     checkcell();
  }
  checkcell();
  checkserial();
}      
 
int availableMemory() {
  int size = 1024; // Use 2048 with ATmega328
  byte *buf;
  while ((buf = (byte *) malloc(--size)) == NULL);
  free(buf);
  return size;
} 

//===============================================
uint8_t bcd2bin (uint8_t val) { return val - 6 * (val >> 4);}

uint8_t bin2bcd (uint8_t val) { return val + 6 * (val / 10);}

//===============================================
void getRtcTime()
{
  
    Wire.beginTransmission(DS1307_I2C_ADDRESS);          //hallo
    Wire.send(0x00);                                  //go to reg 0 please
    Wire.endTransmission();                           // bye!
  
    Wire.requestFrom(DS1307_I2C_ADDRESS,7);        
    RX8025_time[0]= Wire.receive();
    RX8025_time[1]= Wire.receive();
    RX8025_time[2]= Wire.receive();
    RX8025_time[3]= Wire.receive();
    RX8025_time[4]= Wire.receive();
    RX8025_time[5]= Wire.receive();
    RX8025_time[6]= Wire.receive();
  
    year   = bcd2bin(RX8025_time[6]&0xff);
    month  = bcd2bin(RX8025_time[5]&0x1f);
    date   = bcd2bin(RX8025_time[4]&0x3f);
    week   = bcd2bin(RX8025_time[3]&0x07);
    hour   = bcd2bin(RX8025_time[2]&0x3f);
    minute = bcd2bin(RX8025_time[1]&0x7f);
    second = bcd2bin(RX8025_time[0]&0x7f);
    
    if (minute == 17){
      pinMode(3, OUTPUT );
      for (int i = 0; i<100; i++){
        digitalWrite(3, HIGH);
        delay(10);
        digitalWrite(3, LOW );
      }
      }
}

void setDateDs1307()                
{
   
   second = (byte) ((Serial.read() - 48) * 10 + (Serial.read() - 48)); // Use of (byte) type casting and ascii math to achieve result.  
   minute = (byte) ((Serial.read() - 48) *10 +  (Serial.read() - 48));
   hour  = (byte) ((Serial.read() - 48) *10 +  (Serial.read() - 48));
   week = (byte) (Serial.read() - 48);
   date = (byte) ((Serial.read() - 48) *10 +  (Serial.read() - 48));
   month = (byte) ((Serial.read() - 48) *10 +  (Serial.read() - 48));
   year= (byte) ((Serial.read() - 48) *10 +  (Serial.read() - 48));
   Wire.beginTransmission(DS1307_I2C_ADDRESS);
   Wire.send(0x00);
   Wire.send(decToBcd(second));    // 0 to bit 7 starts the clock
   Wire.send(decToBcd(minute));
   Wire.send(decToBcd(hour));      // If you want 12 hour am/pm you need to set
                                   // bit 6 (also need to change readDateDs1307)
   Wire.send(decToBcd(week));
   Wire.send(decToBcd(date));
   Wire.send(decToBcd(month));
   Wire.send(decToBcd(year));
   Wire.endTransmission();
   Serial.println( "Time set" );
}

// Convert normal decimal numbers to binary coded decimal
byte decToBcd(byte val)
{
  return ( (val/10*16) + (val%10) );
}
 
// Convert binary coded decimal to normal decimal numbers
byte bcdToDec(byte val)
{
  return ( (val/16*10) + (val%16) );
}

void printfile(){
   // open a file
  if (file.open(name, O_READ)) {
    Serial.println( name);
  } else{
    Serial.println("file open error ");
  }
  Serial.println();
  
  // copy file to serial port
  int16_t n;
  uint8_t buf[7];// nothing special about 7, just a lucky number.
  while ((n = file.read(buf, sizeof(buf))) > 0) {
    for (uint8_t i = 0; i < n; i++) Serial.print(buf[i]);
  }
  file.writeError = false;
  file.close();
  /* easier way
  int16_t c;
  while ((c = file.read()) > 0) Serial.print((char)c);
  */
  PgmPrintln("\nDone");
}

void setlogdelay()
{
  updatetime = (Serial.read() - 48);
  EEPROM.write(logdelayaddr, updatetime);
  updatetime = updatetime*incrementsize;
  Serial.print( "Loggin time set to " );
  Serial.println( updatetime );
}

void eepromdump(){
  for ( int i = 0; i<512; i++ ){
    Serial.print(i);
    Serial.print("--");
    Serial.print( EEPROM.read( i ),DEC); 
    Serial.print("--");}
    Serial.println();
}

void checkcell(){
  if (cell.available() >0)
  {
    cell_incoming_char=cell.read();    //Get the character from the cellular serial port.
    Serial.print(cell_incoming_char);  //Print the incoming character to the terminal.
    
    if (cell_incoming_char == '#'){
      //delay(50);
        Serial.println("I got an SMS bite china!");
        
        cell.println("AT+CMGD=1,4"); // delete all SMS
        delay(200);
        Serial.println("deleted it");
        //delay(100);
      }
     
     if (cell_incoming_char == 'R')
     if (cell.read() == 'I')
     if (cell.read() == 'N')
     if (cell.read() == 'G'){
        Serial.print("I am ringing my dude--");
        rings++;
        Serial.println( rings );  
        if (rings == 3 ){
          startSMS(); 
          cell.print( "Power Now---> " );
          cell.print(emon.apparentPower);
          endSMS();
        
        rings = 0;
        Serial.println( "reset" );
        }
    }
    //delay(20);
 }
}

void checkserial(){
   if ( Serial.available() > 0 ){ 
       incomingbyte = Serial.read();
       Serial.println( incomingbyte );
       if (incomingbyte == 84) {   //T second minute hour day date month year  
         setDateDs1307();
       }
       
       if (incomingbyte == 85) printfile();  //u
       
       if (incomingbyte == 86) setlogdelay();  //v
       
       if (incomingbyte == 87) eepromdump();  //W
   }
}

void startSMS()
// function to send a text message
{

cell.println("AT+CMGF=1"); // set SMS mode to text
cell.print("AT+CMGS=");
cell.print(34,BYTE); // ASCII equivalent of "
cell.print(mobilenumber);
cell.println(34,BYTE);  // ASCII equivalent of "
delay(500); // give the module some thinking time
}
void endSMS()
{
cell.println(26,BYTE);  // ASCII equivalent of Ctrl-Z
delay(15000); // the SMS module needs time to return to OK status

}
