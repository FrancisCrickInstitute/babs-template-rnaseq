<?php

$manifestFile = __DIR__ . "/manifest_<<GIT_REF>>.txt";

// Used for converting URLs to local files
$baseDir = $_SERVER['DOCUMENT_ROOT'];

// Used as the root inside the tar archive
$archiveRoot = __DIR__;


// ------------------------------------------------------------
// 1. Read manifest
// ------------------------------------------------------------

$lines = file($manifestFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

if (!$lines) {
    http_response_code(500);
    exit("Failed to read manifest");
}


// ------------------------------------------------------------
// 2. Parse header
// ------------------------------------------------------------

$header = str_getcsv(array_shift($lines), "\t");
$colIndex = array_flip($header);

if (!isset($colIndex['file'])) {
    http_response_code(500);
    exit("Manifest missing 'file' column");
}


// ------------------------------------------------------------
// 3. Build filters from query parameters
// ------------------------------------------------------------

$filters = [];

foreach ($_GET as $key => $value) {
    if (isset($colIndex[$key])) {
        $filters[$key] = $value;
    }
}


// ------------------------------------------------------------
// 4. Filter manifest
// ------------------------------------------------------------

$matchedFiles = [];

foreach ($lines as $line) {

    $row = str_getcsv($line, "\t");

    $match = true;

    foreach ($filters as $key => $value) {

        if (!isset($row[$colIndex[$key]]) ||
            $row[$colIndex[$key]] != $value) {

            $match = false;
            break;
        }
    }

    if ($match) {

        $url = $row[$colIndex['file']];

        $fullPath = urlToLocalPath(
            $url,
            $baseDir,
            $_SERVER['HTTP_HOST']
        );

        if ($fullPath && file_exists($fullPath)) {
            $matchedFiles[] = $fullPath;
        }
    }
}


// ------------------------------------------------------------
// 5. Check results
// ------------------------------------------------------------

if (empty($matchedFiles)) {
    http_response_code(404);
    exit("No files matched your query");
}


// ------------------------------------------------------------
// 6. Convert paths for tar archive
// ------------------------------------------------------------

$relativeFiles = [];

foreach ($matchedFiles as $file) {

    $real = realpath($file);

    if ($real &&
        str_starts_with($real, $archiveRoot . DIRECTORY_SEPARATOR)) {

        $relativeFiles[] = substr(
            $real,
            strlen($archiveRoot) + 1
        );
    }
}


if (empty($relativeFiles)) {
    http_response_code(500);
    exit("No files could be converted to archive paths");
}


// ------------------------------------------------------------
// 7. Stream tar.gz archive
// ------------------------------------------------------------

header('Content-Type: application/gzip');
header('Content-Disposition: attachment; filename="filtered_data.tar.gz"');


$files = array_map('escapeshellarg', $relativeFiles);


// Run tar from archive root so paths are relative
$cmd = 'cd ' . escapeshellarg($archiveRoot) .
       ' && tar -czf - ' .
       implode(' ', $files);


$process = proc_open(
    $cmd,
    [
        1 => ['pipe', 'w'], // stdout
        2 => ['pipe', 'w']  // stderr
    ],
    $pipes
);


if (is_resource($process)) {

    while (!feof($pipes[1])) {

        echo fread($pipes[1], 8192);
        flush();
    }

    fclose($pipes[1]);


    $error = stream_get_contents($pipes[2]);
    fclose($pipes[2]);


    $returnCode = proc_close($process);


    if ($returnCode !== 0) {

        http_response_code(500);
        echo "Archive creation failed: " . $error;
    }

} else {

    http_response_code(500);
    echo "Could not start tar process";
}



// ------------------------------------------------------------
// Function: URL -> local filesystem path
// ------------------------------------------------------------

function urlToLocalPath($url, $baseDir, $allowedHost = null) {

    $parts = parse_url($url);


    // Ensure URL belongs to this site
    if ($allowedHost &&
        isset($parts['host']) &&
        $parts['host'] !== $allowedHost) {

        return false;
    }


    if (!isset($parts['path'])) {
        return false;
    }


    // Decode URL escaping
    $path = urldecode($parts['path']);


    // Convert URL path to filesystem path
    $fullPath = realpath($baseDir . $path);


    // Prevent escaping outside document root
    if ($fullPath === false ||
        !str_starts_with($fullPath, $baseDir)) {

        return false;
    }


    return $fullPath;
}

?>
