## 1:Download the runner script
 
 Download the script `neuron-sdk-runner.sh` and `.env` to a local folder.

- `curl -o neuron-sdk-runner.sh https://raw.githubusercontent.com/NeuronInnovations/neuron-bin/main/neuron-sdk-runner.sh`

Run `chmod +x neuron-sdk-runner.sh`

## 2 Prepare the .env environment
If you have a `.env` file from neuron then place it next to the runner. If not, fill in the blanks in the `.env` file template you can get from here 
- `curl -o .env https://raw.githubusercontent.com/NeuronInnovations/neuron-bin/main/.env.template`

Rename `.env.template` to `.env`.  You will need to contact neuron.world to get the right keys. The environment contains variables vital for the execution.
## 3 Run the consumer node

Currently, only macOS and Linux are supported (amd64 and arm), and the environment has been tested to work well with devices as powerful as Orange-PIs.

To run the environment, execute the runner script. The script will check and download the latest version and load the environment using variables in `.env`, as well as parameters you pass to it. The current compilation runs an ADS-B consumer:

```bash
./neuron-sdk-runner.sh linux amd64 --port=1352  --force-location='{"lat":54.9735,"lon":-2.4398,"alt":0.000000}' --radius=600  --buyer-udp-address=localhost:1234 --clear-cache=true --deduplicate=true
```

+ Where `linux` and `amd64` (no dash at the beginning!) indicate which executable to download that is suitable for your platform. Possible combinations are:
    + linux amd64
    + linux arm64
    + linux arm
    + darwin arm64

    If you accidentally define the wrong OS and architecture, delete the line "local-version" from the `.env` file to redownload with the correct parameters.

+ `--port=1352` is the port you listen to for incoming data/connections. You will need to port forward or open these ports manually. If your router has uPNP, you can use the flag `--enable-upnp=true` to automatically add the rule.
+ `--force-location={...}` and `--radius=600`. The first overrides the location variable in `.env`. Together with `radius`, which is a km value, it causes the node to connect to all data providers that are within the location center-point and the radius. In the example, the location is somewhere incentral UK, and the radius comprises most of the country.
+ `--buyer-udp-address=host:port` indicates the host and port the received data should be *forwarded* to. The format of the data that the node receives and forwards is JSON-formatted aircraft positional data as well as sensor status messages. Aircraft position packets are of the following form:
    ```javascript
    {
        "messageType": "aircraftPosition",
        "sensorID": 1737077050,               // ID of the sensor that produced the packet
        "targetID": 8154258,                  // targetID is the ICAO, normally in hex, in integer form
        "callsign": "JST772",
        "latitude": -37.11387634277344,
        "longitude": 143.21461779005986,
        "bAltitude": 8107.68,                 // Pressure altitude as reported from aircraft (fixed to 29.92 inHg - 1013.25 hPa)
        "heading": -63.43494882292201,        // this is the track angle, not true heading. 
        "groundSpeed": 245.6,                 // Ground speed of the aircraft in m/s.
        "verticalSpeed": 5.6,                 // Ground speed of the aircraft in m/s.
        "category": "Light ...",              // Aircraft category. A string representation of the type of ac
        "seconds": 1726088232,                // Epoch seconds of the packet at receiver
        "nanoseconds": 774481398,             // Nanoseconds of the packet at receiver
        "timestamp": 1726088232,              // Time this packet was received by this machine
        "sensorLat": -38.164081,              // Latitude of the sensor
        "sensorLon": 144.382718,              // Longitude of the sensor
        "sensorGAlt": 0                       // GPS altitude of the sensor
    }
    ```


Every 30 seconds, a packet with sensor statuses is transmitted. This is represented as a map of sensorIDs to aircraft positions. The latter has the exact same structure as above and represents the last packet produced by the sensor in the map. Since that packet contains sensor locations, we can deduce the latest location of the sensor. Moreover, from the timestamps, we can make an educated guess on whether the sensor has a problem or if there are just no aircraft in the sky.

>**⚠️ Important:** The following will not be emitted in UDP in future versions.  

    ```javascript
        {
            "messageType":"sensorStatus",
            "sensorMap":{                       // map that holds sensorID => last-message-packet-of-sensor
                "1737077050":{                  // sensorID
                    "messageType":"aircraftPosition",
                    "sensorID":1737077050,
                    "targetID":8144083,
                    "callsign":"NVP",
                    "latitude":-37.94032287597656,
                    "longitude":144.75387248587103,
                    "bAltitude":38.1,
                    "heading":-176.53177074108285,
                    "seconds":1726093334,
                    "nanoseconds":926357329,
                    "timestamp":1726093334,
                    "sensorLat":-38.164081,      // latest sensor location
                    "sensorLon":144.382718,
                    "sensorGAlt":0
                },
                "519863663":{
                    "messageType":"aircraftPosition",
                    "sensorID":519863663,
                    "targetID":8149836,
                    ...
                    ...
                    "sensorLat":-38.26009,
                    "sensorLon":145.053334,
                    "sensorGAlt":0
                },
                ...
            }
        }
    ```

To consume these messages, simply listen for UDP traffic on the host:port. In Linux, you can debug with:
    `socat -v UDP-RECV:1234 STDOUT` or `nc -lu 1234` if you are sending to the localhost. Notice the latter needs restarting after the end of transmission. Notice this is a peer-to-peer high-throughput data stream with no bottlenecks in the middle. You receive the messages as soon as a sensor has one. A popular way of buffering the stream is to generate a map: `targetID => aircraftPosition` and update the map when a location change occurs or when the timestamp is too old.
+ `--deduplicate=true` The node is focused on giving you the most recent data and won't make too many filtering decisions for you. However, subscribing to many sensors can produce high data throughput. When two or more sensors see the same aircraft, it is likely you'll get duplicates. Duplicates with different timestamps are extremely useful for multilateration; however, if you don't need duplicates, you can turn them off with this flag. This is implemented using a simple map, as described above, where a message is put on the wire only if a change in lat/lon/alt has been observed. This is only for convenience, but it's advisable to subscribe to the necessary sensors only and build your own logic.
+ `"--list-of-sellers-source=env"` If you know exactly which sensor you want to receive data from, then you can specify this using this switch and add to the bottom of the `.env` file a list of sellers, e.g.:
    ```yaml
    private_key=83c386a507e...
    smart_contract_address=0x87e2fc64dc1...
    list_of_sellers=02cd628de81d2677832fffd24067a91fdb430698c259b8d6862db55d221f86fa31,03108b811be6caac978003c19ea4a33db5fe6f3711379b8ea288800e039fddd3ac,03fa7b72860864bc0f4f5d8a03419d1339edc5f31a92ef09fdee9de15150a84a5b
    ```

    Note that you need to leave the `--radius=...` flag out. The data provider (seller) is identified by their public keys. You can find these in explorer.neuron.world by clicking on a data provider, then looking at its account in the chain explorer and copying the public (admin) key of the data provider's node.
+  `"--clear-cache=false"` The application stores connectivity information in order to speed up subsequent launches; for instance, IP addresses and ports are cached as well as internal shared accounts between buyer and seller. However, if you relaunch the program with a different port then you must clear the cache by setting the flag to true. At the moment, the default is to always clear the cache on system boot. 
