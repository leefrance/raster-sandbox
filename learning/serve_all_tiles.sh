#!/bin/bash

# Simple HTTP server to serve both TMS and XYZ tiles
# This script starts a Python HTTP server to serve tile files

PORT=8090
TILE_DIR="$(pwd)"  # Serve from current directory

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    if ! command -v python &> /dev/null; then
        echo "Error: Neither python3 nor python is installed. Please install Python."
        exit 1
    else
        PYTHON_CMD="python"
    fi
else
    PYTHON_CMD="python3"
fi

# Create a simple HTML index file to navigate between viewers
cat > raster_tiles/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raster Tile Viewers</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #333;
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
        }
        .viewer-list {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            margin-top: 20px;
        }
        .viewer-card {
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
            width: 300px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .viewer-card h2 {
            margin-top: 0;
            color: #0066cc;
        }
        .viewer-card p {
            color: #666;
            margin-bottom: 15px;
        }
        .viewer-card a {
            display: inline-block;
            background-color: #0066cc;
            color: white;
            padding: 8px 15px;
            text-decoration: none;
            border-radius: 3px;
        }
        .viewer-card a:hover {
            background-color: #0055aa;
        }
    </style>
</head>
<body>
    <h1>Raster Tile Viewers</h1>
    <p>Select a viewer to explore the generated raster tiles:</p>
    
    <div class="viewer-list">
        <div class="viewer-card">
            <h2>Original TMS Viewer</h2>
            <p>View the original TMS-formatted tiles (Y-origin at bottom).</p>
            <p><strong>Format:</strong> TMS (requires tms:true in Leaflet)</p>
            <a href="glacier_viewer.html">Open Viewer</a>
        </div>
        
        <div class="viewer-card">
            <h2>Simple Test Viewer</h2>
            <p>A minimalist viewer showing just one layer for testing.</p>
            <p><strong>Format:</strong> TMS (requires tms:true in Leaflet)</p>
            <a href="simple_test.html">Open Viewer</a>
        </div>
        
        <div class="viewer-card">
            <h2>XYZ Format Viewer</h2>
            <p>View the XYZ-formatted tiles compatible with Mapbox.</p>
            <p><strong>Format:</strong> XYZ (standard web mapping format)</p>
            <a href="xyz_viewer.html">Open Viewer</a>
        </div>
        
        <div class="viewer-card">
            <h2>Tile Debugger</h2>
            <p>Debug and troubleshoot tile loading issues.</p>
            <p><strong>Features:</strong> Debug tools, specific tile testing</p>
            <a href="tile_debugger.html">Open Debugger</a>
        </div>
    </div>
    
    <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;">
        <h2>Available Tile Sets</h2>
        <ul id="tile-sets">
            <!-- Will be populated by JavaScript -->
        </ul>
    </div>
    
    <script>
        // Fetch and display available tile sets
        fetch('/')
            .then(response => response.text())
            .then(html => {
                const parser = new DOMParser();
                const doc = parser.parseFromString(html, 'text/html');
                const links = Array.from(doc.querySelectorAll('a'));
                
                const tileSetsList = document.getElementById('tile-sets');
                const tileSets = links
                    .filter(link => !link.href.endsWith('.html') && 
                                   (link.href.includes('glacier') || 
                                    link.href.includes('tiles')))
                    .map(link => link.textContent);
                
                if (tileSets.length > 0) {
                    tileSets.forEach(set => {
                        const li = document.createElement('li');
                        li.textContent = set;
                        tileSetsList.appendChild(li);
                    });
                } else {
                    tileSetsList.innerHTML = '<li>No tile sets found</li>';
                }
            })
            .catch(error => {
                document.getElementById('tile-sets').innerHTML = 
                    '<li>Error loading tile sets: ' + error.message + '</li>';
            });
    </script>
</body>
</html>
EOF

echo "Starting HTTP server on port $PORT..."
echo "Serving tiles from: $TILE_DIR"
echo "Access at: http://localhost:$PORT/raster_tiles/"
echo "Press Ctrl+C to stop the server"

# Start the HTTP server
$PYTHON_CMD -m http.server $PORT
