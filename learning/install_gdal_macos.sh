#!/bin/bash
# Quick script to install GDAL on macOS for use with the raster tile processing tools

echo "This script will install GDAL on your macOS system using Homebrew."
echo "This is required for the raster tile processing tools."
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    if ! command -v brew &> /dev/null; then
        echo "Failed to install Homebrew. Please install it manually from https://brew.sh/"
        exit 1
    fi
fi

echo "Installing GDAL using Homebrew..."
brew install gdal

# Check if installation was successful
if command -v gdal-config &> /dev/null && command -v gdal2tiles.py &> /dev/null; then
    echo "GDAL was installed successfully!"
    echo "You can now use the gdal_raster_tiles.sh script to process your GeoTIFF files:"
    echo ""
    echo "  ./scripts/gdal_raster_tiles.sh --min-zoom 9 --max-zoom 14 --format png"
    echo ""
    echo "Make sure to place your .tif files in the raster_input/ directory first."
else
    echo "GDAL installation appears to have issues."
    echo "You may need to install it manually using Conda:"
    echo ""
    echo "  conda install -c conda-forge gdal"
    echo ""
    echo "Or refer to the GDAL_INSTALL.md document for more details."
fi
