# netsecverv

[Link](https://github.com/AmatMN/netsecverv.git)
the github for this project.

[Link](https://chat.amatshome.com)
the project also runs here.

## SETUP

### Prerequisites
---docker-compose installed on the server that's going to run this messaging app.

### Guide
1. Unzip the files and folders (`git clone https://github.com/AmatMN/netsecverv.git` on linux cli) were you want to run the server.
2. Go into the folder keyGen. (`cd ./keyGen` on linux cli).
3. Open the file v3.ext (`sudo nano v3.ext`).
4. Under `[alt_names]` change DNS.1 and DNS.2 to the domain name and *.domain name that point to the server.
    * You can either change the IP.1 and IP.2 to the remote and internal ip addresses of the server or remove them.
    * After you're done hit ctrl^S to save and crtl^X to close the file.
5. Repeat step 3 and 4 for nginx.v3.ext.
6. Run keyGen.sh (`sudo nano ./keyGen.sh` on linux cli).
    * Make sure to run it with sudo as it won't be able to move the files to the correct position afterwards.
    * This will create new keys and certificates for both the MQTT broker and the HTTPS connection.
7. Run the docker-compose file (`docker-compose up`).
8. Take the ca.crt file and add it to the local Store of safe certificates on every device that wants to be a client.
    * Windows: open the crt file and click install certificate...
    * Android: Settings -> security -> install from storage. 
9. go to the domain name pointing to the server this is running on, Enter a username and enjoy.
    * make sure it's the same domain name or a subdomain of the domain name as before, otherwise the SSL certificate will be invalid.


