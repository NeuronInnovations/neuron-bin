1. Download the script `neuron-sdk-runner.sh` and `.env` to a local folder.

- `curl -o neuron-sdk-runner.sh https://raw.githubusercontent.com/NeuronInnovations/neuron-bin/main/neuron-sdk-runner.sh`

- `curl -o .env https://raw.githubusercontent.com/NeuronInnovations/neuron-bin/main/.env`


2. do `chmod +x neuron-sdk-runner.sh` 
3. Fill up the blanks in the `.env` file. You'll get them by creating a test account in explorer.neuron.com


In either mac or linux run

./neuron-sdk-runner.sh linux amd64 -port=13043  -force-location='{"lat":33.0, "lon":0.0, "alt":0.0}' -radius=100 --buyer-udp-address=33.33.33.33:1234



if you accidentally defined the wrong OS and archtecture delete the line "local-version" from the .env file to redownload with the correct parameters. 