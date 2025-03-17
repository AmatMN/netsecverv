const WebSocket = require('ws');
const https = require('https');
const express = require('express');
const fs = require('fs');
const bodyParser = require('body-parser');

// Create Express app for handling API requests
const app = express();
app.use(bodyParser.json());

// Create an HTTPS server (needed for WebSocket over `wss://`)
const serverOptions = {
    cert: fs.readFileSync('/server/server.crt'),   // Replace with your server certificate
    key: fs.readFileSync('/server/server.key'),    // Replace with your server key
    ca: fs.readFileSync('/ca_certificates/ca.crt')          // Replace with your CA certificate
};

// Use HTTPS server for WebSocket server
const server = https.createServer(serverOptions, app);

// Create a WebSocket server and listen on the same HTTPS server
const wss = new WebSocket.Server({ server });

// Handle WebSocket connections from frontend clients
wss.on('connection', (ws) => {
    console.log('Frontend client connected via WebSocket');

    // Handle messages from the frontend WebSocket
    ws.on('message', (message) => {
        console.log('Received message from frontend:', message);
    });

    // Handle close event for frontend client
    ws.on('close', () => {
        console.log('Frontend client disconnected');
    });
});

// Endpoint to handle WebSocket proxying to Mosquitto
app.post('/proxy-websocket', (req, res) => {
    const { cert, key } = req.body;

    if (!cert || !key) {
        return res.status(400).json({ error: 'Missing client certificate or key.' });
    }

    const certBuffer = Buffer.from(cert, 'base64');
    const keyBuffer = Buffer.from(key, 'base64');

    // WebSocket connection to Mosquitto broker (secure WebSocket)
    const mosquittoWs = new WebSocket('wss://mqtt5:9443', {
        cert: certBuffer,
        key: keyBuffer,
        ca: fs.readFileSync('/ca_certificates/ca.crt'),
        rejectUnauthorized: true
    });

    mosquittoWs.on('open', () => {
        console.log('Connected to Mosquitto');
        res.json({ message: 'WebSocket connection to Mosquitto established.' });
    });

    mosquittoWs.on('message', (message) => {
        console.log('Received message from Mosquitto:', message);
        // Optionally forward this message to the frontend WebSocket clients
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(message);
            }
        });
    });

    mosquittoWs.on('close', () => {
        console.log('Connection to Mosquitto closed');
    });

    mosquittoWs.on('error', (error) => {
        console.error('Error with WebSocket connection:', error);
        res.status(500).json({ error: 'Failed to establish connection to Mosquitto' });
    });
});

// Start the server, listening on port 8081 for WebSocket and HTTPS API
server.listen(8081, () => {
    console.log('Proxy server (WebSocket & HTTPS) listening on port 8081');
});