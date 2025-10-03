#!/bin/bash

# =================================================================
# CLEANUP SCRIPT - Remove unnecessary files from previous attempts
# =================================================================

echo "=== CLEANING UP PREVIOUS FILES ==="
echo "This will remove files and directories from previous attempts"
echo "while preserving our new streamlined approach."
echo ""
echo "The following will be KEPT:"
echo "- geotiff_input/ (for input files)"
echo "- tiles/ (for generated tiles)"
echo "- viewer/ (for the web viewer)"
echo "- scripts/raster_tiles.sh (our new script)"
echo "- RASTER_TILES.md (documentation)"
echo ""
echo "The following will be REMOVED:"
echo "- raster_tiles/ (old test directory)"
echo "- raster_tiles_xyz/ (old test directory)"
echo "- raster_input/ (old input directory)"
echo "- tile_server/ (old server directory)"
echo "- direct_test.html (old test file)"
echo "- tile_debug.html (old test file)"
echo ""

# Ask for confirmation
read -p "Continue with cleanup? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Check if we need to move any GeoTIFF files from old directories to new ones
if [ -d "raster_input" ]; then
    echo "Checking for GeoTIFF files in raster_input directory..."
    tif_files=$(find raster_input -name "*.tif" 2>/dev/null)
    if [ -n "$tif_files" ]; then
        echo "Found the following GeoTIFF files:"
        for file in $tif_files; do
            echo "- $file"
        done
        echo ""
        read -p "Do you want to move these files to geotiff_input/ directory? (y/n): " move_tifs
        if [[ $move_tifs == "y" || $move_tifs == "Y" ]]; then
            mkdir -p geotiff_input
            cp raster_input/*.tif geotiff_input/ 2>/dev/null
            echo "GeoTIFF files moved to geotiff_input/ directory."
        else
            echo "GeoTIFF files will be removed with the raster_input directory."
        fi
    else
        echo "No GeoTIFF files found in raster_input directory."
    fi
fi

# Remove old directories
echo "Removing old directories..."
rm -rf raster_tiles
rm -rf raster_tiles_xyz
rm -rf raster_input
rm -rf tile_server

# Remove old test files
echo "Removing old test files..."
rm -f direct_test.html
rm -f tile_debug.html

# Check for any other test files that might be in the root directory
echo "Checking for other test files..."
if ls *.html 2>/dev/null; then
    echo ""
    read -p "Do you want to remove these HTML files as well? (y/n): " remove_html
    if [[ $remove_html == "y" || $remove_html == "Y" ]]; then
        rm -f *.html
        echo "HTML files removed."
    else
        echo "HTML files kept."
    fi
fi

echo ""
echo "Cleanup complete!"
echo ""
echo "To use the new approach:"
echo "1. Place your GeoTIFF files in the 'geotiff_input' directory"
echo "2. Run './scripts/raster_tiles.sh'"
echo "3. Access the viewer at http://localhost:8090/viewer/"
echo ""
echo "See RASTER_TILES.md for more details."
