//Set to 0 to disable serial printing
#define printToSerial 0

#if printToSerial == 1
#define serialPrint(x) Serial.print(x)
#define serialPrintln(x) Serial.println(x)
#define initSerial Serial.println(9600);while(!Serial){;}
#else
#define serialPrint(x)
#define serialPrintln(x)
#define initSerial
#endif

//Define libraries here
#include <SPI.h>
#include <SD.h>
#include <Ethernet.h>
#include <EasyWebServer.h>

//Compiler variables here
#define upsSensor 2
#define redLED 7
#define yellowLED 6
#define greenLED 5

//Set the MAC and IP address of webserver
byte mac[] = {0xA8, 0x61, 0x0A, 0x00, 0x00, 0xA0};
IPAddress ip(10, 2, 2, 120);

// Initialize the Ethernet server library
// with the IP address and port you want to use
// (port 80 is default for HTTP):
EthernetServer server(80);

//Object that will later contain *.htm files on SD card
File webPage;

//Variables for Arduino NU UPS Monitor
bool upsOnline = true; //True when ups sensor shows online
bool newlyOffline = false; //Use to detect if ups has newly switched to offline. Used for adding to event count.
unsigned long lastOnline = 0; //Time the ups was last online
unsigned long maxOfflineTime = 480000; //Max time in milliseconds ups can report offline before changing status to shutdown
unsigned int events = 0; //Holds how many times ups has gone offline
unsigned long timeOffline; //Holds time in millis since last online

//Interupt to detect a pwr snsr change
void ISR_upsStatusChange(){
  //update upsOnline to current state
  upsOnline = digitalRead(upsSensor);

  //if the ups is not online then set offline start to
  // current millis time and set status leds
  if (!upsOnline) {
    lastOnline = millis();    
    digitalWrite(yellowLED, HIGH);
    digitalWrite(greenLED, LOW);
    digitalWrite(redLED, LOW);
    newlyOffline = true;
    
    //events += 1;
    //Wait 100 milliseconds to prevent multiple events from low voltage.
    //delay(100);
  }

  //if ups is online set status leds
  else {
    digitalWrite(yellowLED, LOW);
    digitalWrite(greenLED, HIGH);
    digitalWrite(redLED, LOW);
  }
}

//Will return a string stating the current ups status
String getUpsStatus(){
  
  //If UPS has been offline longer than maxOfflineTime
  if (!upsOnline && (millis() - lastOnline) > maxOfflineTime){
    digitalWrite(yellowLED, LOW);
    digitalWrite(greenLED, LOW);
    digitalWrite(redLED, HIGH);
    return "shutdown";
  }

  //If UPS is offline
  else if (!upsOnline) {
    return "offline";
  }

  //If UPS is online
  else if (upsOnline) {
    return "online";
  }

  //Otherwise return error
  else {
    return "ERROR!";
  }
}

//Will return a string of the last time the ups was online
String getTimeSinceOnline(){

  //return time 00:00 if already online
  if (upsOnline) return "00:00";
  else if (!upsOnline){
    timeOffline = millis() - lastOnline;

    //Convert into minutes and seconds
    unsigned int minutesOffline = timeOffline / 60000;
    unsigned int secondsOffline = (timeOffline % 60000) / 1000;

    if (minutesOffline < 10 && secondsOffline < 10) return '0' + String(minutesOffline) + ':' + '0' + String(secondsOffline);
    else if (minutesOffline < 10) return '0' + String(minutesOffline) + ':' + String(secondsOffline);
    else if (secondsOffline < 10) return String(minutesOffline) + ':' + '0' + String(secondsOffline);
    else return String(minutesOffline) + ':' + String(secondsOffline);
  }
  else return "error";
}

//Will return string of time in seconds ups has been offline
String getTimeOffline(){

  //get millis since last online
  timeOffline = millis() - lastOnline;

  //Return string of time since online as string
  if (upsOnline) return "0";
  else return String(timeOffline / 1000);
}

//Will return how many times the ups has gone offline
String getEventCount(){
  return String(events);
}

//Will verify if file exists on sd card, 
// if it cannot be found it will blink the yellow led
void fileExists(String file){
  if(!SD.exists(file)){
    serialPrint(F("ERROR - Cant find "));
    serialPrint(file);
    serialPrintln(F(" file"));
    while(true){
      //Blink red led forever
      digitalWrite(yellowLED, LOW);
      delay(500);
      digitalWrite(yellowLED, HIGH);
      delay(500);
      }
  }
}

void setup() {
  // put your setup code here, to run once:
  initSerial

  //Set pin mode for status leds
  //Green and yellow status leds are set by interupts
  //Red status led will only be on if getUpsStatus is called
  pinMode(redLED, OUTPUT);
  pinMode(yellowLED, OUTPUT);
  pinMode(greenLED, OUTPUT);

  //Turn off all status leds
  digitalWrite(redLED, LOW);
  digitalWrite(yellowLED, LOW);
  digitalWrite(greenLED, LOW);

  //Turn on red led to show web server is starting
  digitalWrite(redLED, HIGH);

  //set default ip address
  Ethernet.begin(mac, ip);
  server.begin();
  serialPrint(F("server is at "));
  serialPrintln(Ethernet.localIP());

  //Turn on yellow led to show that SD card is initializing
  digitalWrite(yellowLED, HIGH);
  
  //initialize sd card
  /*serialPrintln(F("Initializing SD card..."));
  if(!SD.begin(4)) {
    serialPrintln(F("ERROR - SD card initialization failed!"));
    while(true){
      //Blink red led forever
      digitalWrite(redLED, LOW);
      delay(500);
      digitalWrite(redLED, HIGH);
      delay(500);
    }
  }
  serialPrintln(F("SUCCESS - SD card initialized."));
  */
  //Put fileExists checks here

  
  //Turn on green led to show that UPS Sensor is starting
  digitalWrite(greenLED, HIGH);

  //Set pin mode and interrupt for the ups sensor
  pinMode(upsSensor, INPUT);
  attachInterrupt(digitalPinToInterrupt(upsSensor), ISR_upsStatusChange, CHANGE);

  //Wait one second
  delay(1000);

  //Turn off all status leds
  digitalWrite(redLED, LOW);
  digitalWrite(yellowLED, LOW);
  digitalWrite(greenLED, LOW);

  //Set the initial status led
  ISR_upsStatusChange();
}

void loop() {
  // put your main code here, to run repeatedly:
  // Listen for incoming clients
  EthernetClient client = server.available();
  if (client) {
    serialPrintln("New client!");
    EasyWebServer w(client);                    // Read and parse the HTTP Request
    w.serveUrl("/",rootPage);                   // Main page
    w.serveUrl("/upsStatus", upsStatusPage);
    w.serveUrl("/eventCount", eventCountPage);
    w.serveUrl("/timeSinceOnline", timeSinceOnlinePage);
    w.serveUrl("/timeOffline", timeOfflinePage);
    w.serveUrl("/resetEventCount", resetEventCountPage);
  }

  //Detect if we need to add to event count
  if (newlyOffline) {
    events += 1;
    //Wait 5 seconds before reseting the newlyOffline flag
    delay(5000);
    newlyOffline = false;
  }
}

void rootPage(EasyWebServer &w){
  w.client.println(F("<!DOCTYPE html>"));
  w.client.println(F("<html lang=\"en\">"));
  w.client.println(F("<head>"));
  w.client.println(F("<meta charset=\"utf-8\" />"));
  w.client.println(F("<title>Arduino NU Server</title>"));
  w.client.println(F("</head>"));
  w.client.println(F("<div class=\"content\">"));
  w.client.println(F("<body style=\"background-color: black;\">"));
  w.client.println(F("<h1>Arduino NU Server</h1>"));
  w.client.println(F("<p>UPS Status: "));
  w.client.println(getUpsStatus());
  w.client.println(F("</p>"));
  w.client.println(F("<p>Time Since Last Online:"));
  w.client.println(getTimeSinceOnline());
  w.client.println(F("</p>"));
  w.client.println(F("<p>Event Count: "));
  w.client.println(getEventCount());
  w.client.println(F("</p>"));
  w.client.println(F("</body>"));
  w.client.println(F("</div>"));
  w.client.println(F("<style>"));
  w.client.println(F(".content {"));
  w.client.println(F("margin-left: auto;"));
  w.client.println(F("margin-right: auto;"));
  w.client.println(F("text-align: center;"));
  w.client.println(F("color: green;}"));
  w.client.println(F("h1{ font-size: 50px;}"));
  w.client.println(F("p { font-size: 20px;}"));
  w.client.println(F("</style>"));
  w.client.println(F("</html>"));
}

void upsStatusPage (EasyWebServer &w){
  w.client.print(getUpsStatus());
}

void eventCountPage (EasyWebServer &w){
  w.client.print(getEventCount());
}

void timeSinceOnlinePage (EasyWebServer &w){
  w.client.print(getTimeSinceOnline());
}

void timeOfflinePage (EasyWebServer &w){
  w.client.print(getTimeOffline());
}

void resetEventCountPage (EasyWebServer &w){
  events = 0;
  w.client.print("event count has been reset");
}
