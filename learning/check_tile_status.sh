#!/bin/bash
# Script to check the status of raster tile processing

echo "=== Raster Tile Processing Status ==="

# Check if Docker is running
DOCKER_RUNNING=$(docker ps -a | grep dspvector | grep -v _db)
if [ -n "$DOCKER_RUNNING" ]; then
    echo "Docker container status:"
    echo "$DOCKER_RUNNING"
else
    echo "No active dspvector containers found."
fi

# Check if output directory exists and contains tiles
echo -e "\nChecking raster_tiles directory:"
if [ -d "raster_tiles" ]; then
    # Count directories at different zoom levels
    ZOOM_DIRS=$(find raster_tiles -maxdepth 1 -type d | grep -v "^raster_tiles$" | wc -l)
    echo "Found $ZOOM_DIRS zoom level directories"
    
    # List zoom level directories
    echo -e "\nZoom level directories:"
    find raster_tiles -maxdepth 1 -type d | grep -v "^raster_tiles$" | sort
    
    # Count actual tile files (png or jpg)
    PNG_COUNT=$(find raster_tiles -type f -name "*.png" 2>/dev/null | wc -l)
    JPG_COUNT=$(find raster_tiles -type f -name "*.jpg" 2>/dev/null | wc -l)
    JPEG_COUNT=$(find raster_tiles -type f -name "*.jpeg" 2>/dev/null | wc -l)
    WEBP_COUNT=$(find raster_tiles -type f -name "*.webp" 2>/dev/null | wc -l)
    
    TOTAL_TILES=$((PNG_COUNT + JPG_COUNT + JPEG_COUNT + WEBP_COUNT))
    echo -e "\nTile counts:"
    echo "PNG tiles: $PNG_COUNT"
    echo "JPG/JPEG tiles: $((JPG_COUNT + JPEG_COUNT))"
    echo "WEBP tiles: $WEBP_COUNT"
    echo "Total tiles: $TOTAL_TILES"
    
    # Check if metadata exists
    if [ -f "raster_tiles/metadata.json" ] || [ -f "raster_tiles/metadata.txt" ]; then
        echo -e "\nMetadata file found"
    else
        echo -e "\nNo metadata file found yet"
    fi
    
    # If tiles exist, suggest how to serve them
    if [ $TOTAL_TILES -gt 0 ]; then
        echo -e "\nTiles have been generated successfully!"
        echo "To serve these tiles, run:"
        echo "cd raster_tiles && python -m http.server 8080"
        echo "Then access them at http://localhost:8080"
    else
        echo -e "\nNo tiles have been generated yet."
        echo "The process might still be running or encountered an error."
    fi
else
    echo "raster_tiles directory not found. Processing may not have started."
fi

# Check input files
echo -e "\nInput files in raster_input:"
find raster_input -type f -name "*.tif" | sort

echo -e "\nScript completed."
