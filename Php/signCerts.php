<?php
header("Content-Type: application/json");

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    // Read JSON input
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data["commonName"])) {
        echo json_encode(["error" => "No commonName provided"]);
        exit;
    }

    $commonName = $data["commonName"];

    // Paths to CA certificate and key (must be local paths)
    $caCertPath = "/var/www/html/ca_certificates/ca.crt";
    $caKeyPath = "/var/www/html/ca_certificates/ca.key";
    $caKeyPassword = "yivYv98s"; // very bad, change later

    // Load the CA certificate and key
    $caCert = file_get_contents($caCertPath);
    $caKey = file_get_contents($caKeyPath);

    // Parse CA private key with password
    $caPrivateKey = openssl_pkey_get_private($caKey, $caKeyPassword);
    if (!$caPrivateKey) {
        echo json_encode(["error" => "Failed to load CA private key."]);
        exit;
    }

    // Generate a new private key for the client
    $privateKeyResource = openssl_pkey_new([
        "private_key_bits" => 2048,
        "private_key_type" => OPENSSL_KEYTYPE_RSA,
    ]);

    // Export the private key to PEM format
    openssl_pkey_export($privateKeyResource, $privateKeyPem, null, ['encrypt_key' => false]);

    // Create the CSR
    $dn = [
        "commonName" => $commonName,
        "organizationName" => "HR",
        "organizationalUnitName" => "TINNES02",
        "localityName" => "Rotterdam",
        "stateOrProvinceName" => "Zuid-Holland",
        "countryName" => "NL",
        "emailAddress" => "0978246@hr.nl"
    ];

    $csrResource = openssl_csr_new($dn, $privateKeyResource);

    // Sign the CSR with the CA certificate and private key
    $serialNumber = random_int(100000, 999999); // Generate a random serial number
    $validDays = 365; // 1-year validity
    $clientCert = openssl_csr_sign($csrResource, $caCert, $caPrivateKey, $validDays, ['digest_alg' => 'sha256'], $serialNumber);
    if (!$clientCert) {
        echo json_encode(["error" => "Failed to sign certificate"]);
        exit;
    }

    // Export the signed certificate as PEM
    openssl_x509_export($clientCert, $signedCert);

    // Send back the certificate and private key
    echo json_encode(["certificate" => $signedCert, "privateKey" => $privateKeyPem]);
}
?>