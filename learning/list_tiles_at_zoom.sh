#!/bin/bash

# This script lists all available tiles at a specific zoom level for each dataset

TILE_DIR="raster_tiles"
ZOOM="$1"

if [ -z "$ZOOM" ]; then
    echo "Please specify a zoom level (9-13)"
    echo "Usage: $0 <zoom_level>"
    exit 1
fi

echo "Listing all tiles at zoom level $ZOOM:"
echo "======================================"

for dataset in $(find "$TILE_DIR" -maxdepth 1 -mindepth 1 -type d | sort); do
    dataset_name=$(basename "$dataset")
    
    # Check if this zoom level exists
    if [ ! -d "$dataset/$ZOOM" ]; then
        echo "$dataset_name: No tiles at zoom level $ZOOM"
        continue
    fi
    
    echo "$dataset_name:"
    
    # Count x and y values
    x_coords=$(find "$dataset/$ZOOM" -maxdepth 1 -mindepth 1 -type d | wc -l)
    total_tiles=$(find "$dataset/$ZOOM" -type f -name "*.png" | wc -l)
    
    echo "  $total_tiles tiles across $x_coords x-directories"
    
    # Get min/max values for x and y
    x_dirs=$(find "$dataset/$ZOOM" -maxdepth 1 -mindepth 1 -type d | sort)
    
    # Sample some tile coordinates
    echo "  Sample tiles (x/y):"
    sample_tiles=$(find "$dataset/$ZOOM" -type f -name "*.png" | head -5)
    
    for tile in $sample_tiles; do
        rel_path=${tile#"$dataset/$ZOOM/"}
        x_val=$(echo "$rel_path" | cut -d'/' -f1)
        y_val=$(echo "$rel_path" | cut -d'/' -f2 | sed 's/.png//')
        echo "    $x_val/$y_val"
    done
    
    echo ""
done

echo "TIP: To test a specific tile, try:"
echo "curl -I http://localhost:8090/<dataset>/$ZOOM/<x>/<y>.png"
