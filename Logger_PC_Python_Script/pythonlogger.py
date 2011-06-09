hallo =  """
            Arduino data logger by Tobie Nortje - tobie.nortje@navitas.co.za
            www.navitas.co.za/tobie.nortje
            https://github.com/Tooblippe/Energy_Logger/wiki
"""

import serial
import time


#pachube keys
API_KEY = 'xxxxxx'
API_URL = '/api/xxxxx.xml'
pachube_update = 6   #roughtly update pachube every 60s

#serial port setup
port = 4
baud = 9600

#constants
cperkwh = 72

#date formatting
fmt1 = '%m/%d/%Y'
fmt2 = '%H:%M:%S'

#log to filename
filename = "C:\\temp\\geyser.csv"

#setup serial comms
ser = serial.Serial(port, baud)

print hallo

print ser.readline()              #arduino resets when connected. get rid of initial inputs sent

## now sync the time
## get localtime and make it unix time
t = time.mktime((time.localtime()))
## adds two hours for local time - South-Afrca
t = t +(2*60*60)  
## add a T to it so the system undersands the command
T = "T" + str(t)
#write the command. THis is a T with 10 digits. The 10 digits is UNIX time, in second since the epoch..some
ser.write(T);

#serial comms with arduino start here
print "INCOMING DATA STREAM FROM ARDUINO"
while 1:
  val = ser.readline()
  if val > 0 :
    try:
      f = open( filename, "a" )                       #Open file
      f.write( val)  
      f.close()
    except:
      print "that file could not be opened - " + filename #smething went wrong
    
    print val #send it to the screen aswell


# end

