#!/bin/bash

# =================================================================
# RASTER TILE GENERATOR AND SERVER - ENHANCED VERSION
# =================================================================
#
# This script provides a clean, streamlined approach to:
#   1. Generate XYZ-format tiles from GeoTIFF files
#   2. Serve the tiles via a local HTTP server
#   3. Provide a simple web viewer
#
# This version supports command-line arguments for key parameters.

# -----------------------------------------------------------------
# PARSE COMMAND LINE ARGUMENTS
# -----------------------------------------------------------------

# Default values
HTTP_PORT=8091
INPUT_DIR="./geotiff_input"
OUTPUT_DIR="./tiles"
VIEWER_DIR="./viewer"
MIN_ZOOM=9
MAX_ZOOM=13
TILE_SIZE=256
TILE_FORMAT="png"
PROCESSES=4
RESAMPLING="bilinear"

# Display help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help               Show this help message"
    echo "  -p, --port PORT          HTTP server port (default: $HTTP_PORT)"
    echo "  -i, --input DIR          Input directory for GeoTIFF files (default: $INPUT_DIR)"
    echo "  -o, --output DIR         Output directory for tiles (default: $OUTPUT_DIR)"
    echo "  -v, --viewer DIR         Directory for web viewer (default: $VIEWER_DIR)"
    echo "  -z, --min-zoom ZOOM      Minimum zoom level (default: $MIN_ZOOM)"
    echo "  -Z, --max-zoom ZOOM      Maximum zoom level (default: $MAX_ZOOM)"
    echo "  -s, --tile-size SIZE     Tile size in pixels (default: $TILE_SIZE)"
    echo "  -f, --format FORMAT      Tile format (png, jpg, webp) (default: $TILE_FORMAT)"
    echo "  -j, --processes NUM      Number of parallel processes (default: $PROCESSES)"
    echo "  -r, --resampling METHOD  Resampling method (default: $RESAMPLING)"
    echo "                           (near, bilinear, cubic, cubicspline, lanczos, average, mode)"
    echo ""
    echo "Example:"
    echo "  $0 --min-zoom 8 --max-zoom 14 --format webp --processes 8"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            ;;
        -p|--port)
            HTTP_PORT="$2"
            shift 2
            ;;
        -i|--input)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--viewer)
            VIEWER_DIR="$2"
            shift 2
            ;;
        -z|--min-zoom)
            MIN_ZOOM="$2"
            shift 2
            ;;
        -Z|--max-zoom)
            MAX_ZOOM="$2"
            shift 2
            ;;
        -s|--tile-size)
            TILE_SIZE="$2"
            shift 2
            ;;
        -f|--format)
            TILE_FORMAT="$2"
            shift 2
            ;;
        -j|--processes)
            PROCESSES="$2"
            shift 2
            ;;
        -r|--resampling)
            RESAMPLING="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Validate format
if [[ ! "$TILE_FORMAT" =~ ^(png|jpg|webp)$ ]]; then
    echo "Error: Invalid format '$TILE_FORMAT'. Supported formats are png, jpg, or webp."
    exit 1
fi

# Validate zoom levels
if [[ ! "$MIN_ZOOM" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ZOOM" =~ ^[0-9]+$ ]]; then
    echo "Error: Zoom levels must be integers."
    exit 1
fi

if [[ $MIN_ZOOM -gt $MAX_ZOOM ]]; then
    echo "Error: Minimum zoom level ($MIN_ZOOM) cannot be greater than maximum zoom level ($MAX_ZOOM)."
    exit 1
fi

# Ensure directories exist
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$VIEWER_DIR"

# -----------------------------------------------------------------
# FUNCTIONS
# -----------------------------------------------------------------

# Generate XYZ tiles from all GeoTIFF files in the input directory
generate_tiles() {
    echo "=== GENERATING TILES ==="
    
    # Find all GeoTIFF files in the input directory
    geotiff_files=$(find "$INPUT_DIR" -type f \( -name "*.tif" -o -name "*.tiff" \))
    
    if [ -z "$geotiff_files" ]; then
        echo "No GeoTIFF files found in $INPUT_DIR."
        echo "Please place your .tif files in this directory and run again."
        return 1
    fi
    
    # Process each GeoTIFF file
    for tif_file in $geotiff_files; do
        base_name=$(basename "$tif_file" .tif)
        base_name=${base_name%.tiff}  # Also handle .tiff extension
        output_path="$OUTPUT_DIR/$base_name"
        
        echo "Processing: $tif_file"
        echo "Output to:  $output_path"
        
        # Create output directory
        mkdir -p "$output_path"
        
        # Generate XYZ-format tiles using GDAL
        # --xyz flag ensures proper XYZ format (Y origin at top)
        # --webviewer none prevents creation of unnecessary viewer files
        # -z sets the zoom level range
        gdal2tiles.py \
            --profile=mercator \
            --xyz \
            --webviewer=none \
            --resampling=$RESAMPLING \
            --zoom=$MIN_ZOOM-$MAX_ZOOM \
            --processes=$PROCESSES \
            --tilesize=$TILE_SIZE \
            "$tif_file" \
            "$output_path"
        
        # If format is not png, convert tiles
        if [ "$TILE_FORMAT" != "png" ]; then
            echo "Converting tiles to $TILE_FORMAT format..."
            
            # Find all PNG tiles and convert them
            find "$output_path" -name "*.png" | while read png_file; do
                new_file="${png_file%.png}.$TILE_FORMAT"
                
                # Use ImageMagick to convert
                convert "$png_file" "$new_file"
                
                # Remove the original PNG file
                rm "$png_file"
            done
        fi
        
        echo "Completed: $base_name"
        echo "----------------------------------------"
    done
    
    echo "Tile generation complete!"
    echo ""
}

# Create a simple web viewer
create_viewer() {
    echo "=== CREATING WEB VIEWER ==="
    
    # Get list of tile directories
    tile_dirs=$(find "$OUTPUT_DIR" -maxdepth 1 -mindepth 1 -type d | sort)
    
    # Extract just the directory names for use in JavaScript
    tile_dir_names=""
    for dir in $tile_dirs; do
        name=$(basename "$dir")
        if [ -z "$tile_dir_names" ]; then
            tile_dir_names="'$name'"
        else
            tile_dir_names="$tile_dir_names, '$name'"
        fi
    done
    
    # Create main index file
    cat > "$VIEWER_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raster Tile Viewer</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.7.1/dist/leaflet.css" />
    <style>
        html, body {
            height: 100%;
            margin: 0;
            padding: 0;
            font-family: Arial, sans-serif;
        }
        #map {
            height: 100%;
            width: 100%;
        }
        .control-panel {
            position: absolute;
            top: 10px;
            right: 10px;
            z-index: 1000;
            background: white;
            padding: 15px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.2);
            min-width: 250px;
            max-width: 300px;
        }
        .layer-control {
            margin-bottom: 15px;
        }
        .layer-control h3 {
            margin-top: 0;
            margin-bottom: 10px;
        }
        .layer-item {
            margin-bottom: 8px;
            display: flex;
            align-items: center;
        }
        .layer-name {
            margin-left: 8px;
            flex-grow: 1;
        }
        .opacity-slider {
            width: 100%;
            margin-top: 5px;
        }
        .debug-panel {
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid #eee;
        }
        .tile-coords {
            font-family: monospace;
            font-size: 12px;
            margin-top: 5px;
        }
        .config-info {
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid #eee;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    
    <div class="control-panel">
        <div class="layer-control">
            <h3>Raster Layers</h3>
            <div id="layer-list">
                <!-- Layers will be added here by JavaScript -->
            </div>
        </div>
        
        <div class="debug-panel">
            <h3>Debug Info</h3>
            <div>Zoom: <span id="zoom-level">-</span></div>
            <div>Center: <span id="map-center">-</span></div>
            <div class="tile-coords" id="tile-coords"></div>
        </div>
        
        <div class="config-info">
            <h3>Configuration</h3>
            <div>Min Zoom: $MIN_ZOOM</div>
            <div>Max Zoom: $MAX_ZOOM</div>
            <div>Tile Size: ${TILE_SIZE}px</div>
            <div>Format: $TILE_FORMAT</div>
        </div>
    </div>

    <script src="https://unpkg.com/leaflet@1.7.1/dist/leaflet.js"></script>
    <script>
        // Configuration
        const config = {
            port: $HTTP_PORT,
            initialView: [45.94, -110.76], // Default view (customize as needed)
            initialZoom: $MIN_ZOOM,
            maxZoom: $MAX_ZOOM,
            minZoom: $MIN_ZOOM,
            output_dir: '$OUTPUT_DIR',
            tileFormat: '$TILE_FORMAT',
            tileDirs: [$tile_dir_names]
        };

        // Initialize the map
        const map = L.map('map', {
            center: config.initialView,
            zoom: config.initialZoom,
            maxZoom: config.maxZoom,
            minZoom: config.minZoom
        });
        
        // Add OSM base layer
        const osmLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
            maxZoom: config.maxZoom
        }).addTo(map);
        
        // Initialize layers object to store references
        const layers = {
            osm: osmLayer
        };
        
        // Add each raster layer
        config.tileDirs.forEach(dir => {
            // Create a formatted name from the directory name
            const name = dir.replace(/_/g, ' ')
                .split(' ')
                .map(word => word.charAt(0).toUpperCase() + word.slice(1))
                .join(' ');
            
            // Create the tile layer
            const layer = L.tileLayer(\`http://localhost:\${config.port}/\${config.output_dir}/\${dir}/{z}/{x}/{y}.\${config.tileFormat}\`, {
                attribution: 'Local Raster Tiles',
                maxZoom: config.maxZoom,
                minZoom: config.minZoom,
                opacity: 0.7,
                zIndex: 100 // Ensure raster layers are above the base layer
            });
            
            // Store reference to the layer
            layers[dir] = layer;
            
            // Create layer control item
            const layerItem = document.createElement('div');
            layerItem.className = 'layer-item';
            
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.id = \`layer-\${dir}\`;
            checkbox.checked = false; // Start with layers off
            
            const label = document.createElement('label');
            label.htmlFor = \`layer-\${dir}\`;
            label.className = 'layer-name';
            label.textContent = name;
            
            const opacitySlider = document.createElement('input');
            opacitySlider.type = 'range';
            opacitySlider.min = '0';
            opacitySlider.max = '1';
            opacitySlider.step = '0.1';
            opacitySlider.value = '0.7';
            opacitySlider.className = 'opacity-slider';
            
            // Event listeners
            checkbox.addEventListener('change', function() {
                if (this.checked) {
                    layer.addTo(map);
                } else {
                    map.removeLayer(layer);
                }
            });
            
            opacitySlider.addEventListener('input', function() {
                layer.setOpacity(this.value);
            });
            
            // Assemble and add to the layer list
            layerItem.appendChild(checkbox);
            layerItem.appendChild(label);
            layerItem.appendChild(document.createElement('br'));
            layerItem.appendChild(opacitySlider);
            
            document.getElementById('layer-list').appendChild(layerItem);
        });
        
        // Update debug information
        function updateDebugInfo() {
            const center = map.getCenter();
            const zoom = map.getZoom();
            
            document.getElementById('zoom-level').textContent = zoom;
            document.getElementById('map-center').textContent = 
                \`[\${center.lat.toFixed(5)}, \${center.lng.toFixed(5)}]\`;
            
            // Calculate tile coordinates for the center
            const tileCoords = [];
            for (const dir of config.tileDirs) {
                const pixelPoint = map.project(center, zoom);
                const tilePoint = pixelPoint.divideBy(256).floor();
                tileCoords.push(\`\${dir}: \${zoom}/\${tilePoint.x}/\${tilePoint.y}.\${config.tileFormat}\`);
            }
            
            document.getElementById('tile-coords').innerHTML = tileCoords.join('<br>');
        }
        
        // Update on map movement
        map.on('moveend zoomend', updateDebugInfo);
        updateDebugInfo();
    </script>
</body>
</html>
EOF

    # Fix the output_dir reference in the JavaScript
    sed -i '' "s/config.output_dir/\"$OUTPUT_DIR\"/g" "$VIEWER_DIR/index.html"
    
    echo "Web viewer created at $VIEWER_DIR/index.html"
    echo ""
}

# Start a simple HTTP server to serve the tiles
start_server() {
    echo "=== STARTING HTTP SERVER ==="
    echo "Server running at: http://localhost:$HTTP_PORT/viewer/"
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    # Determine Python version and command
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    else
        PYTHON_CMD="python"
    fi
    
    # Start the server from the root directory
    $PYTHON_CMD -m http.server $HTTP_PORT
}

# -----------------------------------------------------------------
# MAIN SCRIPT
# -----------------------------------------------------------------

echo "==========================================================="
echo "                   RASTER TILE TOOLKIT                     "
echo "==========================================================="
echo ""
echo "This tool will:"
echo "1. Generate XYZ-format tiles from GeoTIFF files"
echo "2. Create a web viewer for the tiles"
echo "3. Start a local HTTP server to serve everything"
echo ""
echo "Configuration:"
echo "- Input GeoTIFF files:  $INPUT_DIR"
echo "- Output tiles:         $OUTPUT_DIR"
echo "- Web viewer:           $VIEWER_DIR"
echo "- HTTP server port:     $HTTP_PORT"
echo "- Zoom levels:          $MIN_ZOOM to $MAX_ZOOM"
echo "- Tile size:            ${TILE_SIZE}px"
echo "- Tile format:          $TILE_FORMAT"
echo "- Parallel processes:   $PROCESSES"
echo "- Resampling method:    $RESAMPLING"
echo ""

# Check for GDAL
if ! command -v gdal2tiles.py &> /dev/null; then
    echo "ERROR: gdal2tiles.py not found."
    echo "Please install GDAL utilities first."
    echo "Typically: pip install gdal"
    exit 1
fi

# Check for ImageMagick if needed for format conversion
if [ "$TILE_FORMAT" != "png" ] && ! command -v convert &> /dev/null; then
    echo "ERROR: ImageMagick (convert command) not found."
    echo "This is required for converting tiles to $TILE_FORMAT format."
    echo "Please install ImageMagick first."
    exit 1
fi

# Run the main functions
generate_tiles
create_viewer
start_server
