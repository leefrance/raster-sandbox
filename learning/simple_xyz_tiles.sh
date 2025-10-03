#!/bin/bash

# XYZ Direct Tile Generator - Simple Version
# This script generates XYZ format tiles (compatible with Mapbox) using gdal2tiles.py directly

# Default settings
INPUT_DIR="raster_input"
OUTPUT_DIR="raster_tiles_xyz"
MIN_ZOOM=9
MAX_ZOOM=13
RESAMPLING="lanczos"
PORT=8090

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory '$INPUT_DIR' does not exist."
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Process each .tif file separately
find "$INPUT_DIR" -name "*.tif" | while read -r tif_file; do
    base_name=$(basename "$tif_file" .tif)
    file_output_dir="$OUTPUT_DIR/$base_name"
    
    echo "Processing file: $tif_file"
    echo "Output directory: $file_output_dir"
    
    # Create output directory for this file
    mkdir -p "$file_output_dir"
    
    # Run gdal2tiles.py with mercator profile only (XYZ format)
    # Note: not all options may be supported by your version of gdal2tiles.py
    gdal2tiles.py --zoom=$MIN_ZOOM-$MAX_ZOOM --resampling=$RESAMPLING --profile=mercator \
                  --webviewer=none --processes=4 \
                  "$tif_file" "$file_output_dir"
    
    # Check exit code
    if [ $? -eq 0 ]; then
        echo "Successfully processed $base_name"
        
        # Count tiles
        TILE_COUNT=$(find "$file_output_dir" -type f -name "*.png" | wc -l)
        echo "Generated $TILE_COUNT tiles for $base_name"
    else
        echo "Error processing $base_name"
    fi
done

# Check overall results
TOTAL_TILES=$(find "$OUTPUT_DIR" -type f -name "*.png" | wc -l)
echo "Total tiles generated: $TOTAL_TILES"

if [ $TOTAL_TILES -gt 0 ]; then
    echo "Tile generation completed successfully."
    echo ""
    echo "To serve these tiles, run:"
    echo "cd $OUTPUT_DIR && python -m http.server $PORT"
    echo ""
    echo "These tiles are in XYZ format and should work with most web mapping libraries without special configuration."
else
    echo "No tiles were generated. Check the logs for errors."
fi

echo "Processing complete"
