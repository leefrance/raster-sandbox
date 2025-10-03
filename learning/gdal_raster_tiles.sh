#!/bin/bash
# Process raster tiles using GDAL command-line tools without requiring Python GDAL bindings

# Default values
INPUT_DIR="raster_input"
OUTPUT_DIR="raster_tiles"
MIN_ZOOM=0
MAX_ZOOM=14
FORMAT="png"
RESAMPLING="cubic"
PORT=8090
SERVE_ONLY=false
VERBOSE=false

# Function to display usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Process GeoTIFF files into raster tiles using GDAL command-line tools."
    echo ""
    echo "Options:"
    echo "  -i, --input-dir DIR       Directory containing input .tif files (default: raster_input)"
    echo "  -o, --output-dir DIR      Directory to output raster tiles (default: raster_tiles)"
    echo "  -min, --min-zoom ZOOM     Minimum zoom level to generate (default: 0)"
    echo "  -max, --max-zoom ZOOM     Maximum zoom level to generate (default: 14)"
    echo "  -f, --format FORMAT       Output format: png, jpg, or webp (default: png)"
    echo "  -r, --resampling METHOD   Resampling method: nearest, bilinear, cubic, etc. (default: cubic)"
    echo "  -p, --port PORT           Port to serve the tiles on (default: 8090)"
    echo "  -s, --serve-only          Skip processing and only serve existing tiles"
    echo "  -v, --verbose             Enable verbose output"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --min-zoom 8 --max-zoom 14 --format webp"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -min|--min-zoom)
            MIN_ZOOM="$2"
            shift 2
            ;;
        -max|--max-zoom)
            MAX_ZOOM="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -r|--resampling)
            RESAMPLING="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -s|--serve-only)
            SERVE_ONLY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if GDAL tools are installed
if ! command -v gdal_translate &> /dev/null || ! command -v gdal2tiles.py &> /dev/null; then
    echo "Error: GDAL tools not found."
    echo "Please install GDAL using one of the following methods:"
    echo ""
    echo "  macOS with Homebrew:  brew install gdal"
    echo "  macOS with Conda:     conda install -c conda-forge gdal"
    echo ""
    echo "For more information, see docs/GDAL_INSTALL.md"
    exit 1
fi

# Create directories if they don't exist
mkdir -p "$INPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Skip processing if --serve-only is specified
if [ "$SERVE_ONLY" = false ]; then
    # Find all .tif files in the input directory
    TIF_FILES=$(find "$INPUT_DIR" -type f -name "*.tif" -o -name "*.tiff")
    
    if [ -z "$TIF_FILES" ]; then
        echo "No .tif files found in $INPUT_DIR"
        exit 1
    fi
    
    # Process each .tif file
    for TIF_FILE in $TIF_FILES; do
        # Get source name from filename without extension
        SOURCE_NAME=$(basename "$TIF_FILE" | sed 's/\.[^.]*$//')
        echo "Processing $SOURCE_NAME..."
        
        # Create output directory
        TILE_DIR="$OUTPUT_DIR/$SOURCE_NAME"
        mkdir -p "$TILE_DIR"
        
        # Create a VRT in Web Mercator projection
        VRT_PATH="$OUTPUT_DIR/temp_web_mercator_${SOURCE_NAME}_$(date +%s).vrt"
        
        echo "Creating Web Mercator VRT..."
        if [ "$VERBOSE" = true ]; then
            gdalwarp -t_srs EPSG:3857 -r "$RESAMPLING" -of VRT "$TIF_FILE" "$VRT_PATH"
        else
            gdalwarp -t_srs EPSG:3857 -r "$RESAMPLING" -of VRT "$TIF_FILE" "$VRT_PATH" &> /dev/null
        fi
        
        # Use gdal2tiles.py to generate the tiles
        echo "Generating tiles for zoom levels $MIN_ZOOM to $MAX_ZOOM..."
        
        # Determine output format for gdal2tiles
        GDAL2TILES_FORMAT="PNG"
        if [ "$FORMAT" = "jpg" ]; then
            GDAL2TILES_FORMAT="JPEG"
        elif [ "$FORMAT" = "webp" ]; then
            GDAL2TILES_FORMAT="WEBP"
        fi
        
        if [ "$VERBOSE" = true ]; then
            gdal2tiles.py --zoom=$MIN_ZOOM-$MAX_ZOOM --resampling="$RESAMPLING" --webviewer=none \
                          --tilesize=256 --processes=$(sysctl -n hw.ncpu) --format="$GDAL2TILES_FORMAT" \
                          "$VRT_PATH" "$TILE_DIR"
        else
            gdal2tiles.py --zoom=$MIN_ZOOM-$MAX_ZOOM --resampling="$RESAMPLING" --webviewer=none \
                          --tilesize=256 --processes=$(sysctl -n hw.ncpu) --format="$GDAL2TILES_FORMAT" \
                          "$VRT_PATH" "$TILE_DIR" &> /dev/null
        fi
        
        # Clean up temporary VRT
        rm -f "$VRT_PATH"
        
        echo "Completed processing $SOURCE_NAME"
    done
fi

# Generate a simple HTML viewer
echo "Generating HTML viewer..."

# Get all directories in the output directory (these are our sources)
SOURCES=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)

if [ -z "$SOURCES" ]; then
    echo "No tile sources found in $OUTPUT_DIR"
    exit 1
fi

HTML_PATH="$OUTPUT_DIR/viewer.html"

# Create the HTML content
cat > "$HTML_PATH" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raster Tile Viewer</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.7.1/dist/leaflet.css" />
    <style>
        body, html { height: 100%; margin: 0; padding: 0; }
        #map { height: 100%; }
        .layer-control {
            position: absolute;
            top: 10px;
            right: 10px;
            z-index: 1000;
            background: white;
            padding: 10px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        .layer-control h3 {
            margin-top: 0;
            margin-bottom: 10px;
        }
        .layer-item {
            margin-bottom: 5px;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    <div class="layer-control">
        <h3>Raster Layers</h3>
        <div id="layer-list">
            <!-- Layer controls will be added here -->
        </div>
    </div>

    <script src="https://unpkg.com/leaflet@1.7.1/dist/leaflet.js"></script>
    <script>
        // Initialize the map
        const map = L.map('map').setView([0, 0], 2);
        
        // Add OpenStreetMap as a base layer
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(map);
        
        // Define the raster layers
        const rasterLayers = {'OpenStreetMap': null};
        
        // Add raster tile layers
EOF

# Add a layer for each source
for SOURCE in $SOURCES; do
    cat >> "$HTML_PATH" << EOF
        rasterLayers['$SOURCE'] = L.tileLayer('http://localhost:$PORT/$SOURCE/{z}/{x}/{y}.$FORMAT', {
            minZoom: $MIN_ZOOM,
            maxZoom: $MAX_ZOOM,
            attribution: 'Generated Raster Tiles'
        });
EOF
done

# Add the rest of the HTML
cat >> "$HTML_PATH" << EOF
        // Create layer controls
        const layerList = document.getElementById('layer-list');
        
        Object.keys(rasterLayers).forEach((layerName, index) => {
            const layerItem = document.createElement('div');
            layerItem.className = 'layer-item';
            
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.id = \`layer-\${index}\`;
            checkbox.checked = index === 0;
            
            const label = document.createElement('label');
            label.htmlFor = \`layer-\${index}\`;
            label.textContent = layerName;
            
            checkbox.addEventListener('change', () => {
                if (checkbox.checked) {
                    if (rasterLayers[layerName]) {
                        rasterLayers[layerName].addTo(map);
                    }
                } else {
                    if (rasterLayers[layerName]) {
                        map.removeLayer(rasterLayers[layerName]);
                    }
                }
            });
            
            layerItem.appendChild(checkbox);
            layerItem.appendChild(label);
            layerList.appendChild(layerItem);
            
            // Add the first layer to the map
            if (index === 1 && rasterLayers[layerName]) {
                rasterLayers[layerName].addTo(map);
            }
        });
        
        // Try to fit the map to the bounds of the first layer
        if (Object.keys(rasterLayers).length > 1) {
            const firstLayerName = Object.keys(rasterLayers)[1];
            const firstLayer = rasterLayers[firstLayerName];
            
            // This will center the map when the first tiles load
            if (firstLayer) {
                firstLayer.on('load', function() {
                    try {
                        // Center approximately on loaded tiles
                        map.setView([35, -100], 4);
                    } catch (e) {
                        console.error('Error setting map view:', e);
                    }
                });
            }
        }
    </script>
</body>
</html>
EOF

echo "Generated HTML viewer at $HTML_PATH"

# Open the HTML viewer in a browser
open "file://$(realpath "$HTML_PATH")"

# Start a simple HTTP server to serve the tiles
echo "Starting server on port $PORT..."
echo "Press Ctrl+C to stop the server"

# Use Python's built-in HTTP server with CORS support
python3 -c "
import http.server
import socketserver
from functools import partial

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

PORT = $PORT
Handler = CORSHTTPRequestHandler
os.chdir('$OUTPUT_DIR')
with socketserver.TCPServer(('', PORT), Handler) as httpd:
    print('Serving at port', PORT)
    httpd.serve_forever()
" || echo "Server stopped"
