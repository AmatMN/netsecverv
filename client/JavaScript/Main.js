const address = "chat.amatshome.com";
const endCode = "AadniEAcinoanicaepoeacniawadnADWCacio";
const startCode = "efinwecoaienconwceoenicowcioneconcowe";
let caPath = "https://"+address+"/ca_certificates/ca.crt";
let client;


document.getElementById("signupForm").addEventListener("submit", function(event) {
    event.preventDefault();
    let name = document.getElementById("name").value;
    if (!validInput(name)) return;
    showSignUp();
    signUp(name);
});

function init(){
    if (!signIn()){
        showSignUp();
    }
}

function getId(certPem){
    let cert = forge.pki.certificateFromPem(certPem);
    return cert.subject.getField('CN').value;
}

function showSignUp(){
    let signFormDisplay = document.getElementById("signup");
    if (signFormDisplay.style.display === "none"){
        signFormDisplay.style.display = "block";
    } else {
        signFormDisplay.style.display = "none";
    }
}

function showMessager(){
    let messageDisplay = document.getElementById("chatContainer");
    if (messageDisplay.style.display === "none"){
        messageDisplay.style.display = "block";
    } else {
        messageDisplay.style.display = "none";
    }

}

function signIn(){
    cert = localStorage.getItem(`cert`);
    if (cert === null) return false;
    clientId = getId(cert);
    key = localStorage.getItem(`key`);
    getId(cert);
    if (clientId !== null && key !== null){
        connectToBroker(clientId, key, cert);
        showMessager();
        return true;
    }
    return false;
}

async function generateKeyPair() {
    let keyPair = await window.crypto.subtle.generateKey(
        {
            name: "RSASSA-PKCS1-v1_5",
            modulusLength: 2048,
            publicExponent: new Uint8Array([1, 0, 1]),
            hash: { name: "SHA-256" },
        },
        true,
        ["sign", "verify"]
    );

    const privateKey = await window.crypto.subtle.exportKey("pkcs8", keyPair.privateKey);
    const publicKey = await window.crypto.subtle.exportKey("spki", keyPair.publicKey);

    return {
        privateKey: btoa(String.fromCharCode(...new Uint8Array(privateKey))),
        publicKey: btoa(String.fromCharCode(...new Uint8Array(publicKey))),
    };
}

function validInput(input){
    input = input.trim();
    let cleansed = input.replace(/[^a-zA-Z0-9_-]/g, "");
    if(cleansed !== input){
        alert("Invalid characters!!!\nOnly letters, numbers, hyphens and underscore are allowed!");
        return false;
    }

    if (input.length > 25) {
        alert("Too long!!! \nUsername cannot be more than 25 characters!");
        return false;
    }

    if (input.length === 0) {
        alert("Too short!!! \nUsername cannot be empty!");
        return false;
    }
    return true;
}

function signUp(name) {
    let enteredId = name;
    generateKeyPair().then(keys => {

        // Decode Base64 properly
        const binaryDer = forge.util.decode64(keys.privateKey);
        const binaryDerPub = forge.util.decode64(keys.publicKey);

        // Convert binary string to Forge ASN.1 object
        const asn1 = forge.asn1.fromDer(binaryDer);
        const asn1Pub = forge.asn1.fromDer(binaryDerPub);

        // Convert ASN.1 object to Forge private/public key
        const privateKey = forge.pki.privateKeyFromAsn1(asn1);
        const publicKey = forge.pki.publicKeyFromAsn1(asn1Pub);

        // Convert Private Key to PEM format
        const privateKeyPKCS8 = forge.pki.privateKeyToAsn1(privateKey);
        const privateKeyPem = forge.pki.privateKeyInfoToPem(privateKeyPKCS8);

        // Create and sign the CSR
        const csr = forge.pki.createCertificationRequest();
        csr.setSubject([
            { name: 'commonName', value: enteredId },
            { name: 'organizationName', value: 'HR' },
            { name: 'organizationalUnitName', value: 'TINNES02' },
            { name: 'localityName', value: 'Rotterdam' },
            { name: 'stateOrProvinceName', value: 'Zuid-Holland' },
            { name: 'countryName', value: 'NL' },
            { name: 'emailAddress', value: '0978246@hr.nl'}
        ]);
        csr.publicKey = publicKey;
        csr.sign(privateKey);

        // Convert CSR to PEM format
        const csrPem = forge.pki.certificationRequestToPem(csr);

        // Send CSR to PHP backend
        fetch("https://" + address + "/Php/signCerts.php", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ csr: csrPem })
        })
        .then(response => response.json())
        .then(data => {
            // Save received certificate in localStorage
            localStorage.setItem(`cert`, data.certificate);
            localStorage.setItem(`key`, privateKeyPem);
            console.log("Generated keys!");
            signIn();
        })
        .catch(error => console.error("Error:", error));
    });
}

function pemToArrayBuffer(pem) {
    const b64 = pem.replace(/(-----(BEGIN|END) (PRIVATE KEY|CERTIFICATE)-----|\n)/g, '');
    const binary = atob(b64);
    const len = binary.length;
    const buffer = new ArrayBuffer(len);
    const view = new Uint8Array(buffer);
    for (let i = 0; i < len; i++) {
        view[i] = binary.charCodeAt(i);
    }
    return buffer;
}

function connectToBroker(clientId, key, cert){
    const host = "wss://" + address + ":1884/ws";

    const keyBuffer = pemToArrayBuffer(key);
    const certBuffer = pemToArrayBuffer(cert);

    const options = {
        keepalive: 60,
        clientId: clientId,
        protocolId: "MQTT",
        protocolVersion: 5,
        clean: true,
        reconnectPeriod: 5000,
        connectTimeout: 30000,
        will: {
            topic: "msg",
            payload:  endCode+":"+clientId+" has disconnected!",
            qos: 0,
            retain: false
        },
        key: keyBuffer,
        cert: certBuffer,
        rejectUnauthorized: true,
        ca: caPath,
        username: null,
        password: null
    }
    client = mqtt.connect(host, options);
    client.on("error", (err) => {
        console.log("Connection error: ", err ? err.message || err : "Unknown error");
    });
    client.on("reconnect", () => {
        console.log("Reconnecting...");
    });
    client.on("connect", () => {
        client.subscribe("msg");
        let welcomeMessage = startCode + ":" + clientId + " has connected"
        publishMsg(welcomeMessage, true);
    });
    client.on("message", messageReceived);
}

function messageReceived(topic, message) {
    let m = message.toString();
    let mArr = m.split(':');
    let sender = mArr.shift();
    let msg = mArr.join(':');

    if (sender === endCode || sender === startCode){
        sender = null;
    }
    println(sender, msg, sender === clientId);
}

function println(sender, message, selfSend) {
    let container = document.createElement("DIV");
    container.classList.add("msg");

    if (selfSend) {
        container.classList.add("user");
    } else {
        container.classList.add("other");
    }

    if (sender !== null){
        let namePlate = document.createElement("B");
        namePlate.textContent = sender + ":";
        container.appendChild(namePlate);
    }

    let messagePlate = document.createElement("P");
    messagePlate.innerHTML = message;
    container.appendChild(messagePlate);

    let chatWindow = document.getElementById("messagesHere");
    chatWindow.appendChild(container);

    chatWindow.scrollTop = chatWindow.scrollHeight;
}

function publishMsg(m, storexMsg) {
    let message = m
    if (!storexMsg){
        message = clientId + ":" + m;
    }
    client.publish("msg", message);
}

function adjustTextareaRows() {
    let inputField = document.getElementById("messageInput");
    let messages = document.getElementById("messagesHere");

    // Get the current content and its scroll height
    let currentContentHeight = inputField.scrollHeight;
    let rowHeight = inputField.clientHeight / inputField.rows;

    // Calculate the number of rows needed for the content
    let newRows = Math.min(Math.ceil(currentContentHeight / rowHeight), 5);

    // Update the rows attribute of the textarea
    inputField.rows = newRows;

    // Scroll to the bottom to show the latest line
    inputField.scrollTop = inputField.scrollHeight;
    messages.scrollTop = messages.scrollHeight;
}

// Send mechanism functionality
document.addEventListener("DOMContentLoaded", function () {
    let inputField = document.getElementById("messageInput");
    let sendButton = document.getElementById("sendButton");
    let messages = document.getElementById("messagesHere");

    inputField.addEventListener("input", adjustTextareaRows);

    sendButton.addEventListener("click", function () {
        if(inputField.value.replace(/\n/g, "") === ""){
            inputField.value = "";
            inputField.rows = 1;
            messages.scrollTop = messages.scrollHeight;
        }
        let message = inputField.value.replace(/\n/g, '<br/>');
        if (message) {
            publishMsg(message, false);
            inputField.value = "";
            inputField.rows = 1;
            messages.scrollTop = messages.scrollHeight;
        }
    });

    // Send message on Enter key press
    inputField.addEventListener("keypress", function (event) {
        if (event.key === "Enter" && !event.shiftKey) {
            event.preventDefault();
            sendButton.click();
        }
    });
});
