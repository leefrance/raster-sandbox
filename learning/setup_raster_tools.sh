#!/bin/bash

# Make the raster_tiles.py script executable
chmod +x /Users/lee.france/GIT/datastore-vector-tiles/scripts/raster_tiles.py

# Create symbolic link in /usr/local/bin for easier access
if [ -L "/usr/local/bin/raster_tiles" ]; then
    echo "Symbolic link already exists, updating..."
    rm /usr/local/bin/raster_tiles
fi

ln -s /Users/lee.france/GIT/datastore-vector-tiles/scripts/raster_tiles.py /usr/local/bin/raster_tiles
chmod +x /usr/local/bin/raster_tiles

echo "Raster tiles script installed successfully!"
echo "Usage: raster_tiles [options]"
echo "Run 'raster_tiles --help' for more information."
