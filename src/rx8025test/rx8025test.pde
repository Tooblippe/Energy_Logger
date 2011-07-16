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
         

#include <avr/sleep.h>
#include "tmp102.h"      //tmp sensor om stalker
#include <Wire.h>        //communicates via singel wire on A5 and A4 - need to move the CT
#include "Emon.h"    //Load the library
#include <Fat16.h>
#include <Fat16util.h> // use functions to print strings from flash memory
#include <avr/wdt.h>
#include <LiquidCrystal.h>


#ifndef cbi
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#endif
#ifndef sbi
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
#endif
volatile boolean f_wdt=1;

SdCard card;
Fat16 file;

#define  RX8025_address  0x32
unsigned char RX8025_Control[2]=
{
  0x20,0x00
};
unsigned char RX8025_time[7]=      //use this one to hard code for now
{
  0x00,0x59,0x09,0x7,0x10,0x07,0x11 //second, minute, hour, week, date, month, year, BCD format
};
unsigned char hour=0;
unsigned char minute=0;
unsigned char second=0;
unsigned char week=0;
unsigned char year=0;
unsigned char month=0;
unsigned char date=0;


LiquidCrystal lcd(9, 8, 7, 6, 5, 4);

EnergyMonitor emon;  //Create an instance

byte debug = 1;        //print strings if 1
byte logging = 1;      //are we logging now 1=yes, 0=no
boolean start = true;
long count = 0L;
int updatetime = 10000;  //update frequency
float convertedtemp; /* We then need to multiply our two bytes by a scaling factor, mentioned in the datasheet. */
int tmp102_val; /* an int is capable of storing two bytes, this is where we "chuck" the two bytes together. */
char name[] = "data5.csv";


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
    Serial.print(date, DEC );
    Serial.print("/");
    Serial.print(month, DEC );
    Serial.print("/20");
    Serial.print(year,DEC );
    Serial.print(",");
    Serial.print(hour, DEC );
    Serial.print(":");
    Serial.print(minute,DEC);
    Serial.print(":");
    Serial.print(second,DEC);
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
     
     
      
  Serial.print(date, DEC );
  Serial.print("/");
  Serial.print(month, DEC );
  Serial.print("/20");
  Serial.print(year,DEC );
  Serial.print(",");
  Serial.print(hour, DEC );
  Serial.print(":");
  Serial.print(minute,DEC);
  Serial.print(":");
  Serial.print(second,DEC);
  Serial.print(",Temp,");
  Serial.print(convertedtemp);
  Serial.print(",Power,");
  //Serial.println(emon.realPower);
  
  
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
    
  file.print(date, DEC );
  file.print("/");
  file.print(month, DEC );
  file.print("/20");
  file.print(year,DEC );
  file.print(",");
  file.print(hour, DEC );
  file.print(":");
  file.print(minute,DEC);
  file.print(":");
  file.print(second,DEC);
  file.print(",Temp,");
  file.print(convertedtemp);
  file.print(",Power,");
  //file.println(emon.realPower);
  file.print(emon.apparentPower);
   
   if (start){
        start = false;
        file.println(",startup");} else file.println();
   }

// Setup function
void setup()
{  
    Serial.begin(115200);                                  //we need to chat as slow as possible to OPENLOG and as fast as possible witht RF12 radio to get the data ou and avoid serial data loss
  
   lcd.begin(16, 2);
   lcd.setCursor(0, 0);
   lcd.clear();
 
   Serial.println("-");
   RX8025_init();
    
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
   
  
    delay(200);
    Serial.println("3. CT");
    emon.setPins(A0,A0);                                 //Energy monitor analog pins, fake the voltage pin to same as current this is important. We are not reading the voltage.
    emon.calibration( 1, 0.111, 1);                      //Energy monitor calibration 0.171, EnergyMonitor::calibration(double _VCAL, double _ICAL, double _PHASECAL) 1, 0.171, 1 ----- 1.660556, 0.011000, 1.5
    emon.calc(50,2000);                                   //get the jitters out
    
    Serial.println("4. temp sensor");
    //tmp102_init();  not needed the rx8025 inits the bus
  
  
  
    setRtcTime();                     //RX8025 second, minute, hour, week, date, month, year, BCD format
    delay(200);
    Serial.print("5. time: "); 
    printTime(); 
    Serial.println();
  
    Serial.print("6. file: "); Serial.println( name );
    dbp("syst init");
    Serial.println("--");Serial.println();
  
    getTemp102();
    //pinMode(8,OUTPUT);//LED pin set to OUTPUT
    //pinMode(5,INPUT);//Bee power control pin
    //pinMode(6, OUTPUT);digitalWrite(6, HIGH);
    
    // CPU Sleep Modes 
    // SM2 SM1 SM0 Sleep Mode
    // 0    0  0 Idle
    // 0    0  1 ADC Noise Reduction
    // 0    1  0 Power-down
    // 0    1  1 Power-save
    // 1    0  0 Reserved
    // 1    0  1 Reserved
    // 1    1  0 Standby(1)
  
    //cbi( SMCR,SE );      // sleep enable, power down mode
    //cbi( SMCR,SM0 );     // power down mode
    //sbi( SMCR,SM1 );     // power down mode
    //cbi( SMCR,SM2 );     // power down mode

    //setup_watchdog(9);
 
}
//---------------------------- ------------------------------------------------
// Main loop
//----------------------------------------------------------------------------
void loop()
{
  
//  if (f_wdt==1) {  // wait for timed out watchdog / flag is set when a watchdog timeout occurs
//    f_wdt=0;       // reset flag
  
    //digitalWrite( 8, HIGH );
    //delay(100); digitalWrite(8, LOW);
    if (logging){      //are we in command mode? need to reset to get out of it, exclusice use to uart
     
      //Energy Monitor calc function
      //Rerurns value in emon.apparentPower
      //need to start doing some averaging here
      emon.calc(50,2000);   //<-------------------------------------------------------------------------------REMEMBER TO FIX THIS~!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      //Serial.println( "energy measured");
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("P");
      lcd.print(emon.apparentPower);
      lcd.print("W T");
      
      getTemp102();
      //Serial.println("temp measured");
      lcd.print(convertedtemp);
      lcd.print("C");
      
     // RX8025_init(); delay(20);
      //RX8025_reset();
      getRtcTime(); 
      //Serial.println("time read");
      lcd.setCursor(0,1);
      lcd.print(hour, DEC );
      lcd.print(":");
      lcd.print(minute,DEC);
      lcd.print(":");
      lcd.print(second,DEC);
      
      //count++;
      lcd.print(" ");lcd.print(count++);
      //Serial.print("MEM > "); Serial.print( availableMemory() ); 
      //Serial.print(",count > ");     
      Serial.print(count); 
      Serial.print(" > ");
      
       file.writeError = false;
       file.open(name, O_CREAT | O_APPEND | O_WRITE);
       createLoggingString() ;
       file.close();
      
      //delay(50);
      // Serial.println( availableMemory() );
      //delay(8000);
     }   
        
     //system_sleep(); 
     //system_sleep();
       
//    }
   
}      
 
int availableMemory() {
  int size = 1024; // Use 2048 with ATmega328
  byte *buf;
  while ((buf = (byte *) malloc(--size)) == NULL);
  free(buf);
  return size;
} 
//sleepstuff
//****************************************************************  
// set system into the sleep state 
// system wakes up when wtchdog is timed out
void system_sleep() {

  cbi(ADCSRA,ADEN);                    // switch Analog to Digitalconverter OFF

  set_sleep_mode(SLEEP_MODE_PWR_DOWN); // sleep mode is set here
  sleep_enable();

  sleep_mode();                        // System sleeps here

    sleep_disable();                     // System continues execution here when watchdog timed out 
    sbi(ADCSRA,ADEN);                    // switch Analog to Digitalconverter ON

}

//****************************************************************
// 0=16ms, 1=32ms,2=64ms,3=128ms,4=250ms,5=500ms
// 6=1 sec,7=2 sec, 8=4 sec, 9= 8sec
void setup_watchdog(int ii) {

  byte bb;
  int ww;
  if (ii > 9 ) ii=9;
  bb=ii & 7;
  if (ii > 7) bb|= (1<<5);
  bb|= (1<<WDCE);
  ww=bb;
  //Serial.println(ww);


  MCUSR &= ~(1<<WDRF);
  // start timed sequence
  WDTCSR |= (1<<WDCE) | (1<<WDE);
  // set new watchdog timeout value
  WDTCSR = bb;
  WDTCSR |= _BV(WDIE);


}
//****************************************************************  
// Watchdog Interrupt Service / is executed when  watchdog timed out
ISR(WDT_vect) {
  f_wdt=1;  // set global flag
}

//---------------
//===============================================
void setRtcTime()
{
  //Serial.println("In srtc");
  Wire.beginTransmission(RX8025_address);
  Wire.send(0x00);
  for(unsigned char i=0; i<7; i++)
  {
    Wire.send(RX8025_time[i]);
  }
  Wire.endTransmission();
}

//===============================================
uint8_t bcd2bin (uint8_t val) 
{ 
  return val - 6 * (val >> 4); 
}

uint8_t bin2bcd (uint8_t val) 
{ 
  return val + 6 * (val / 10); 
}

//===============================================
void getRtcTime()
{
  unsigned int i=0;
 
  //Wire.beginTransmission(RX8025_address);          //hallo
  //Wire.send(0x00);                                //go to reg 0 please
  //Wire.endTransmission();                         // bye!
  
  Wire.beginTransmission(RX8025_address);          //hallo
  Wire.send(0x00);                                //go to reg 0 please
  Wire.endTransmission();                         // bye!
  
  Wire.requestFrom(RX8025_address,8);        

//  RX8025_time[i]= Wire.receive();//not use why?
//  while(Wire.available())
//  { 
//    RX8025_time[i]= Wire.receive();
//    i++;
//  }
  
    RX8025_time[0]= Wire.receive();//not use
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
  
  if (date > 24){
     Serial.println( "Error occured...tried again");
     Wire.beginTransmission(RX8025_address);//clear power on reset flag, set to 24hr format
     Wire.send(0x0e);
      for(unsigned char i=0; i<2; i++)
      {
        Wire.send(RX8025_Control[i]);
      }
    Wire.endTransmission();
    
    Wire.requestFrom(RX8025_address,8);  
    RX8025_time[0]= Wire.receive();//not use
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
    
  }
}

//===============================================
void RX8025_init()
{
  Wire.begin();
  Wire.beginTransmission(RX8025_address);//clear power on reset flag, set to 24hr format
  Wire.send(0x0e);
  for(unsigned char i=0; i<2; i++)
  {
    Wire.send(RX8025_Control[i]);
  }
  Wire.endTransmission();
}


