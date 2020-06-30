# mqtt-ccu
Integrate Tasmota actuators into Raspberrymatic / CCU via MQTT

USAGE

         mqtt.sh -c <CUX2801xxx:x> -t <TOPIC> [-o <value>] [-r <ccuname>] [-s <sensor>] [-n <number>] [-d]
         mqtt.sh --channel <CUX2801xxx:x> --topic <TOPIC> [--value <value>] [--realname <ccuname>] [--sensor <sensor>] [--relaynumber <number>] [--debug]

OPTIONS
 
        -c | --channel          CUxD channel name
        -t | --topic            Tasmota device topic name
        -o | --value            Power cmnd [0 - off, 1 - on, 2 - toggle]
        -r | --realname         Actual name for the variable definition.
        -s | --sensor           Query of sensor data,
                                you can pass a list of sensors separated by commas.
                                (ENERGY, DS18B20, AM2301, BMP280, BME280, TSL2561 and BH1750)
        -n | --relaynumber      For devices with mor than one relay you can give the relay number.
        -d | --debug            Debug information and names for CCU systemvariables

PREREQUISITE
 
        Raspberrymatic and mosquitto addon

EXAMPLE
 
         mqtt.sh -c CUX2801006:1 -t tasmota-device -o 1
                This command switches on the relay of the tasmota-device.

         mqtt.sh -c CUX2801006:1 -t tasmota-device -o 0
                This command switches off the relay of the tasmota-device.

         mqtt.sh -c CUX2801006:14 -t display1 -r display1 -s BME280,BH1750
                This command reads the status of the device with the topic display1 and the sensors BME280 and BH1750.
                Since the real name was changed to display1, the following variables are set in the CCU.

                display1-status, display1-ipaddr, display1-RSSI, display1-temperature, display1-pressure,
                display1-seapressure, display1-humidity, display1-illuminance
