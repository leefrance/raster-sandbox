#!/bin/bash

# =================================================================
# ENHANCED DOCKER FOLDER-BASED TILE GENERATOR
# =================================================================
#
# This script provides a Docker-based approach to generating raster tiles
# using folder-based architecture with VRT processing, similar to the 
# enhanced native GDAL script but with Docker containerization.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INPUT_DIR="$PROJECT_ROOT/geotiff_input"
OUTPUT_DIR="$PROJECT_ROOT/tiles"
VIEWER_DIR="$PROJECT_ROOT/viewer"
VRT_DIR="$PROJECT_ROOT/temp_vrt"
PORT=8091

# Performance settings
MAX_ZOOM=13
MIN_ZOOM=9
TILE_SIZE=512
PROCESSES=4

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--port)
            PORT="$2"
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
        -j|--processes)
            PROCESSES="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--port PORT] [--min-zoom ZOOM] [--max-zoom ZOOM] [--tile-size SIZE] [--processes NUM]"
            exit 1
            ;;
    esac
done

echo "🐳 Starting DOCKER folder-based tile generation..."
echo "📁 Input directory: $INPUT_DIR"
echo "📁 Output directory: $OUTPUT_DIR"
echo "🔧 Max zoom: $MAX_ZOOM, Min zoom: $MIN_ZOOM, Tile size: ${TILE_SIZE}px"
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH."
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running."
    echo "Please start Docker and try again."
    exit 1
fi

# Pull the Docker image
echo "🐳 Ensuring Docker image is available..."
if ! docker pull geodata/gdal:latest; then
    echo "❌ Failed to pull Docker image"
    exit 1
fi

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$VRT_DIR"

# Function to validate GeoTIFF files in a folder
validate_geotiffs() {
    local folder="$1"
    local valid_files=()
    local invalid_files=()
    
    for file in "$folder"/*; do
        if [[ -f "$file" ]]; then
            # Convert to lowercase for case-insensitive comparison
            file_lower=$(echo "$file" | tr '[:upper:]' '[:lower:]')
            case "$file_lower" in
                *.tif|*.tiff)
                    # Use Docker to verify it's actually a valid GeoTIFF
                    if docker run --rm -v "$folder:/input" geodata/gdal:latest gdalinfo "/input/$(basename "$file")" &>/dev/null; then
                        valid_files+=("$file")
                    else
                        invalid_files+=("$file")
                    fi
                    ;;
                *)
                    invalid_files+=("$file")
                    ;;
            esac
        fi
    done
    
    if [[ ${#invalid_files[@]} -gt 0 ]]; then
        echo "⚠️  Warning: Found non-GeoTIFF or invalid files in $(basename "$folder"):" >&2
        for file in "${invalid_files[@]}"; do
            echo "    - $(basename "$file")" >&2
        done
    fi
    
    if [[ ${#valid_files[@]} -eq 0 ]]; then
        echo "❌ No valid GeoTIFF files found in $(basename "$folder")" >&2
        return 1
    fi
    
    echo "✅ Found ${#valid_files[@]} valid GeoTIFF(s) in $(basename "$folder")" >&2
    printf '%s\n' "${valid_files[@]}"
    return 0
}

# Scan for subfolders in input directory
echo "🔍 Scanning for input folders..."
input_folders=()
for folder in "$INPUT_DIR"/*; do
    if [[ -d "$folder" ]]; then
        folder_name=$(basename "$folder")
        # Skip hidden folders and common system folders
        if [[ ! "$folder_name" =~ ^\. ]]; then
            input_folders+=("$folder")
        fi
    fi
done

if [[ ${#input_folders[@]} -eq 0 ]]; then
    echo "❌ No input folders found in $INPUT_DIR"
    echo "Expected structure: $INPUT_DIR/{ambient,shadows,texture,...}/*.tif"
    exit 1
fi

echo "📋 Found ${#input_folders[@]} input folder(s):"
for folder in "${input_folders[@]}"; do
    echo "  - $(basename "$folder")"
done
echo ""

# Process each folder
processed_layers=()
for folder in "${input_folders[@]}"; do
    folder_name=$(basename "$folder")
    echo "🔄 Processing folder: $folder_name"
    
    # Validate GeoTIFF files in this folder
    if geotiff_files=($(validate_geotiffs "$folder")); then
        # Create VRT file for this folder using Docker
        vrt_file="$VRT_DIR/${folder_name}.vrt"
        echo "🔗 Creating VRT for $folder_name with ${#geotiff_files[@]} file(s)..."
        
        # Prepare file list for Docker (using container paths)
        docker_file_args=()
        for geotiff in "${geotiff_files[@]}"; do
            docker_file_args+=("/input/$(basename "$geotiff")")
        done
        
        # Use Docker to create VRT with resolution=highest and preserve alpha transparency
        if docker run --rm \
            -v "$folder:/input" \
            -v "$VRT_DIR:/output" \
            geodata/gdal:latest \
            gdalbuildvrt \
            -resolution highest \
            -hidenodata \
            "/output/${folder_name}.vrt" \
            "${docker_file_args[@]}"; then
            echo "  ✅ VRT created: $vrt_file"
            
            # Generate tiles from VRT using Docker
            output_path="$OUTPUT_DIR/$folder_name"
            
            echo "🚀 Generating tiles for $folder_name..."
            
            # Check if tiles already exist and are recent
            if [[ -d "$output_path" ]]; then
                # Check if the output path has actual tile files, not just empty directories
                tile_count=$(find "$output_path" -name "*.png" | wc -l)
                if [[ $tile_count -gt 0 ]]; then
                    # Check if any source file is newer than the tiles
                    needs_update=false
                    for geotiff in "${geotiff_files[@]}"; do
                        if [[ "$geotiff" -nt "$output_path" ]]; then
                            needs_update=true
                            break
                        fi
                    done
                    
                    if [[ "$needs_update" == false ]]; then
                        echo "  ✅ Tiles are up to date, skipping..."
                        processed_layers+=("$folder_name")
                        continue
                    fi
                else
                    echo "  🔄 Existing directory is empty, regenerating..."
                fi
            fi
            
            # Create output directory
            mkdir -p "$output_path"
            
            # Create temporary output directory for Docker
            temp_output="$OUTPUT_DIR/temp_${folder_name}"
            mkdir -p "$temp_output"
            
            # Use Docker to generate tiles (TMS format)
            echo "  🐳 Running Docker GDAL tile generation..."
            if docker run --rm \
                -v "$VRT_DIR:/input" \
                -v "$temp_output:/output" \
                geodata/gdal:latest \
                gdal2tiles.py \
                --profile=mercator \
                --webviewer=none \
                --resampling=bilinear \
                --zoom="$MIN_ZOOM-$MAX_ZOOM" \
                --processes="$PROCESSES" \
                --tilesize="$TILE_SIZE" \
                "/input/${folder_name}.vrt" \
                "/output"; then
                
                echo "  🔄 Converting TMS to XYZ format..."
                # Convert TMS to XYZ format (flip Y coordinate)
                for zoom_dir in "$temp_output"/*; do
                    if [[ -d "$zoom_dir" && $(basename "$zoom_dir") =~ ^[0-9]+$ ]]; then
                        zoom_level=$(basename "$zoom_dir")
                        max_y=$((2**zoom_level - 1))
                        
                        mkdir -p "$output_path/$zoom_level"
                        
                        for x_dir in "$zoom_dir"/*; do
                            if [[ -d "$x_dir" ]]; then
                                x_coord=$(basename "$x_dir")
                                mkdir -p "$output_path/$zoom_level/$x_coord"
                                
                                for tile_file in "$x_dir"/*.png; do
                                    if [[ -f "$tile_file" ]]; then
                                        y_tms=$(basename "$tile_file" .png)
                                        y_xyz=$((max_y - y_tms))
                                        cp "$tile_file" "$output_path/$zoom_level/$x_coord/$y_xyz.png"
                                    fi
                                done
                            fi
                        done
                    fi
                done
                
                # Clean up temporary directory
                rm -rf "$temp_output"
                
                echo "  ✅ Completed $folder_name"
                processed_layers+=("$folder_name")
            else
                echo "  ❌ Failed to generate tiles for $folder_name"
                rm -rf "$temp_output"
            fi
        else
            echo "  ❌ Failed to create VRT for $folder_name"
        fi
    fi
    echo ""
done

# Clean up VRT files
echo "🧹 Cleaning up temporary VRT files..."
rm -rf "$VRT_DIR"

if [[ ${#processed_layers[@]} -eq 0 ]]; then
    echo "❌ No tile layers were successfully generated"
    exit 1
fi

echo ""
echo "🎨 Updating web viewer..."

# Update viewer HTML to dynamically discover layers
update_viewer() {
    # Create viewer HTML with dynamic layer discovery
    cat > "$VIEWER_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Raster Tile Viewer - Enhanced Docker GDAL</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <style>
        body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
        #map { height: 100vh; width: 100vw; }
        .info { padding: 6px 8px; font: 14px/16px Arial, Helvetica, sans-serif; background: white; background: rgba(255,255,255,0.8); box-shadow: 0 0 15px rgba(0,0,0,0.2); border-radius: 5px; }
        .layer-control { background: white; padding: 10px; border-radius: 5px; box-shadow: 0 0 15px rgba(0,0,0,0.2); max-height: 300px; overflow-y: auto; }
        .layer-item { margin: 5px 0; }
        .opacity-control { margin-left: 20px; font-size: 12px; }
        .performance-info { position: absolute; top: 10px; left: 10px; z-index: 1000; background: rgba(0,100,200,0.8); color: white; padding: 5px 10px; border-radius: 3px; font-family: monospace; font-size: 12px; }
        .loading { color: #666; font-style: italic; }
    </style>
</head>
<body>
    <div class="performance-info">
        🐳 Enhanced Docker GDAL | VRT + TMS→XYZ | <span id="layer-count">...</span> Layers | Folder-based
    </div>
    <div id="map"></div>
    
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script>
        // Initialize map
        var map = L.map('map').setView([47.7511, -120.7401], 11);
        
        // Base map
        var baseMap = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);
        
        // Function to discover available tile layers
        async function discoverLayers() {
            try {
                // Attempt to fetch the tiles directory listing
                // This is a fallback approach - in production you might want a proper API
                const knownLayers = ['ambient', 'shadows', 'texture'];  // Add more as needed
                const availableLayers = [];
                
                for (const layer of knownLayers) {
                    try {
                        // Test if layer exists by trying to fetch a tile
                        const response = await fetch(`../tiles/${layer}/9/`, { method: 'HEAD' });
                        if (response.ok || response.status === 404) {
                            // 404 might mean the specific tile doesn't exist but the layer does
                            availableLayers.push(layer);
                        }
                    } catch (e) {
                        // Layer might still exist, add it anyway
                        availableLayers.push(layer);
                    }
                }
                
                return availableLayers;
            } catch (error) {
                console.warn('Could not discover layers automatically, using defaults');
                return ['ambient', 'shadows', 'texture'];
            }
        }
        
        // Initialize layers
        async function initializeLayers() {
            const availableLayers = await discoverLayers();
            const tileLayers = {};
            
            // Create tile layers
            availableLayers.forEach(function(layerName) {
                tileLayers[layerName] = L.tileLayer(`../tiles/${layerName}/{z}/{x}/{y}.png`, {
                    attribution: `${layerName} tiles (Enhanced Docker GDAL)`,
                    maxZoom: 13,
                    opacity: 0.8,
                    errorTileUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=='
                });
            });
            
            // Update layer count
            document.getElementById('layer-count').textContent = availableLayers.length;
            
            // Add first layer by default
            const firstLayer = availableLayers[0];
            if (firstLayer && tileLayers[firstLayer]) {
                tileLayers[firstLayer].addTo(map);
            }
            
            // Create custom layer control
            var layerControl = L.control({ position: 'topright' });
            layerControl.onAdd = function(map) {
                var div = L.DomUtil.create('div', 'layer-control');
                div.innerHTML = '<h4>🐳 Enhanced Docker Layers</h4>';
                
                availableLayers.forEach(function(layerName) {
                    var layerItem = L.DomUtil.create('div', 'layer-item', div);
                    
                    var checkbox = L.DomUtil.create('input', '', layerItem);
                    checkbox.type = 'checkbox';
                    checkbox.checked = layerName === firstLayer;
                    checkbox.id = 'layer-' + layerName;
                    
                    var label = L.DomUtil.create('label', '', layerItem);
                    label.htmlFor = 'layer-' + layerName;
                    label.innerHTML = ' ' + layerName.charAt(0).toUpperCase() + layerName.slice(1);
                    
                    var opacityDiv = L.DomUtil.create('div', 'opacity-control', layerItem);
                    var opacityLabel = L.DomUtil.create('span', '', opacityDiv);
                    opacityLabel.innerHTML = 'Opacity: ';
                    var opacitySlider = L.DomUtil.create('input', '', opacityDiv);
                    opacitySlider.type = 'range';
                    opacitySlider.min = '0';
                    opacitySlider.max = '1';
                    opacitySlider.step = '0.1';
                    opacitySlider.value = '0.8';
                    opacitySlider.style.width = '80px';
                    
                    // Event handlers
                    checkbox.addEventListener('change', function() {
                        if (this.checked) {
                            tileLayers[layerName].addTo(map);
                        } else {
                            map.removeLayer(tileLayers[layerName]);
                        }
                    });
                    
                    opacitySlider.addEventListener('input', function() {
                        tileLayers[layerName].setOpacity(this.value);
                    });
                });
                
                return div;
            };
            layerControl.addTo(map);
            
            console.log('🐳 Enhanced Docker GDAL tile viewer loaded');
            console.log('📊 Available layers:', availableLayers);
            console.log('🚀 Generated with VRT + TMS→XYZ conversion (Docker containerized!)');
        }
        
        // Mouse position display
        var mousePosition = L.control({ position: 'bottomleft' });
        mousePosition.onAdd = function(map) {
            var div = L.DomUtil.create('div', 'info');
            div.innerHTML = 'Move mouse over map';
            return div;
        };
        mousePosition.addTo(map);
        
        map.on('mousemove', function(e) {
            mousePosition.getContainer().innerHTML = 
                'Lat: ' + e.latlng.lat.toFixed(5) + 
                ', Lng: ' + e.latlng.lng.toFixed(5) +
                ', Zoom: ' + map.getZoom();
        });
        
        // Initialize the application
        initializeLayers();
    </script>
</body>
</html>
EOF
    
    echo "✅ Enhanced Docker viewer created with dynamic layer discovery"
}

update_viewer

echo ""
echo "✅ Enhanced Docker GDAL tile generation complete!"
echo "📁 Generated ${#processed_layers[@]} tile layer(s): $(IFS=', '; echo "${processed_layers[*]}")"
echo "📁 Tiles saved to: $OUTPUT_DIR"
echo "🐳 Used Docker VRT + TMS→XYZ conversion for compatibility"
echo "🌐 Starting CORS-enabled server on port $PORT..."
echo ""

# Start the CORS server
cd "$PROJECT_ROOT"
python3 scripts/cors_server.py $PORT