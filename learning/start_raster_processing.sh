#!/bin/bash
# Simple starter script for raster tile processing

# Go to the project root directory
cd "$(dirname "$0")/.."

# Make sure the input and output directories exist
mkdir -p raster_input
mkdir -p raster_tiles

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Run the processing script
./scripts/process_raster_tiles.sh "$@"
