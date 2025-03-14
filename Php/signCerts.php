<?php
header("Content-Type: application/json");
if($_SERVER["REQUEST_METHOD"] === "POST"){
    // Read JSON input
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data["csr"])) {
        echo json_encode(["error" => "No CSR provided"]);
        exit;
    }

    // Get the CSR from the request
    $csrPem = $data["csr"];

    // Paths to CA certificate and key (must be local paths)
    $caCertPath = "/var/www/html/ca_certificates/ca.crt"; 
    $caKeyPath = "/var/www/html/all_certs/ca.key";
    $caKeyPassword = "yivYv98s"; // very bad, change later

    // Load the CSR
    $csr = openssl_csr_get_public_key($csrPem);
    if (!$csr) {
        echo json_encode(["error" => "Invalid CSR"]);
        exit;
    }

    // Load CA certificate and key
    $caCert = file_get_contents($caCertPath);
    $caKey = file_get_contents($caKeyPath);

    // Parse CA private key with password
    $caPrivateKey = openssl_pkey_get_private($caKey, $caKeyPassword);
    if (!$caPrivateKey) {
        echo json_encode(["error" => "Failed to load CA private key. Check password."]);
        exit;
    }

    // Define certificate serial number and validity
    $serialNumber = random_int(100000, 999999); // Generate a random serial number
    $validDays = 365; // 1-year validity

    // Sign the CSR to generate a client certificate
    $clientCert = openssl_csr_sign($csrPem, $caCert, $caPrivateKey, $validDays, ['digest_alg' => 'sha256'], $serialNumber);
    if (!$clientCert) {
        echo json_encode(["error" => "Failed to sign certificate"]);
        exit;
    }

    // Export the signed certificate as PEM
    openssl_x509_export($clientCert, $signedCert);

    // Send the signed certificate back as JSON
    echo json_encode(["certificate" => $signedCert]);
}
?>