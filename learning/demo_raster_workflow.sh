#!/bin/bash
# This script demonstrates the workflow for using the raster tile processing feature

# Create the directories if they don't exist
mkdir -p raster_input
mkdir -p raster_tiles

echo "=== Raster Tile Processing Workflow ==="
echo "1. Place your GeoTIFF files in the raster_input/ directory"
echo "2. Run the processing script with your desired parameters"
echo ""
echo "Example: Process GeoTIFF files with medium zoom levels (5-15) as PNG files"
echo "./scripts/raster_tiles.py --min-zoom 5 --max-zoom 15 --format png"
echo ""
echo "Example: Process GeoTIFF files with high zoom levels (10-18) as WebP files for smaller size"
echo "./scripts/raster_tiles.py --min-zoom 10 --max-zoom 18 --format webp"
echo ""
echo "Example: Only serve existing tiles without reprocessing"
echo "./scripts/raster_tiles.py --serve-only"
echo ""
echo "3. The script will automatically open a viewer in your browser"
echo "4. You can add the raster tiles to your map stylesheet using the URL format:"
echo "   http://localhost:8090/{source_name}/{z}/{x}/{y}.{format}"
echo ""
echo "For more detailed information, see the documentation at docs/RASTER_TILES.md"
