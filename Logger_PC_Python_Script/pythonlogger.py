hallo =  """
Arduino data logger by Tobie Nortje - tobie.nortje@navitas.co.za
www.navitas.co.za/tobie.nortje
https://github.com/Tooblippe/Energy_Logger/wiki
"""

import sys
import string
import serial
import time
import eeml

#pachube keys
API_KEY = 'xxxxxx'
API_URL = '/api/xxxxx.xml'
port = 4
baud = 9600
pachube_update = 6   #roughtly update pachube every 60s
cperkwh = 72

#date formatting
fmt1 = '%m/%d/%Y'
fmt2 = '%H:%M:%S'

#log to filename
filename = "C:\\temp\\latest.csv"



#setup serial comms
ser = serial.Serial(port, baud)

print hallo
print "Logging data to csv file in format DATE, TIME, POWER: " + filename
print "Listening to port: " + str(port) + " at " +str(baud) + "baud"
print "The following was sent by the arduino at startup"
print "-----------------------------------------------------------------"
print ser.readline()
print ser.readline()              #arduino resets when connected. get rid of initial inputs sent

## now sync the time
## get localtime and make it unix time

t = time.mktime((time.localtime()))
## add a T to it so the system undersands the command
T = "T" + str(t)
#write the command
ser.write(T);

print "INCOMING DATA STREAM FROM ARDUINO"
print "----------------------------------------------------"
print "    DATE       TIME       POWER              AVERAGE"
print "----------------------------------------------------"
while 1:
  val = ser.readline()
  if val > 0 :
    try:
      f = open( filename, "a" )                       #log it to file
      f.write( val)
      f.close()
    except:
      print "that file could not be opened - " + filename
    
    print val
# end
























   # if minute == pachube_update:                         #update pachube
   #   try:
   #     pac = eeml.Pachube(API_URL, API_KEY)
   #     pac.update([eeml.Data(0, average) ])
   #     pac.put()
   #     print "updated pachube"
   #     print "----------------------------------------------------"
    #    print "    DATE       TIME       POWER              AVERAGE"
    #    print "----------------------------------------------------"
    #    minute = 0
    #    avarage = val
    #  except:
    #    print "pachube not available - will try next time"
    #    print "----------------------------------------------------"
    #    print "    DATE       TIME       POWER              AVERAGE"
    #    print "----------------------------------------------------"
    #    minute = 0
     #   avarage = val

        
    #add the half hour incrementer here and send to different file!
