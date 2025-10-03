# Raster Tile Processing and Serving

This extension to the datastore-vector-tiles repository allows you to process GeoTIFF raster files into web-compatible raster tiles and serve them locally for integration with your map stylesheets.

## Features

- Process GeoTIFF files into raster tiles compatible with web mapping libraries
- Configure minimum and maximum zoom levels for tile generation
- Choose output format (PNG, JPEG, or WebP)
- Select resampling method for best quality
- Serve tiles locally via a simple HTTP server
- Includes a basic viewer for testing the tiles
- Dual implementation: Works with both Python GDAL and command-line GDAL tools

## Directory Structure

- `raster_input/`: Place your .tif files in this directory for processing
- `raster_tiles/`: Output directory where processed tiles will be stored, organized by source name
- `scripts/raster_tiles.py`: Main script for processing and serving raster tiles

## Usage

### Setup

1. First, make the scripts executable:

```bash
chmod +x scripts/setup_raster_tools.sh
./scripts/setup_raster_tools.sh
```

2. Install GDAL (if not using Docker):

See [GDAL Installation Guide](GDAL_INSTALL.md) for detailed instructions on installing GDAL on your system.

### Processing and Serving Tiles

You have three options for processing and serving your raster tiles:

#### Option 1: Pure Python Script (requires Python GDAL bindings)

```bash
./scripts/raster_tiles.py
```

This will process all .tif files in the `raster_input/` directory and start serving the tiles at http://localhost:8091.

If you have issues with Python GDAL bindings, you can use the command-line fallback:

```bash
./scripts/raster_tiles.py --force-cli
```

#### Option 2: Shell Script with GDAL Command-line Tools (recommended for macOS)

If you're having trouble with the Python GDAL bindings, you can use our shell script that only relies on the GDAL command-line tools:

```bash
./scripts/gdal_raster_tiles.sh --min-zoom 9 --max-zoom 14 --format png
```

This script only requires that the GDAL command-line tools be installed (e.g., via `brew install gdal` on macOS).

#### Option 3: Docker Container (no local installation needed)

If you don't want to install anything locally:

```bash
./scripts/docker_raster_tiles.sh --min-zoom 8 --max-zoom 14
```

This script will automatically detect whether to use `docker-compose` or `docker compose` based on your Docker installation.

If you encounter issues with Docker, please refer to the [Docker Setup Guide](DOCKER_SETUP.md) for detailed instructions on installing and configuring Docker on your system.

## Integration with Map Stylesheets

After processing and serving your raster tiles, you can reference them in your map stylesheets using the following URL format:

```
http://localhost:8091/{source_name}/{z}/{x}/{y}.{format}
```

Where:
- `{source_name}` is the name of the .tif file without extension
- `{z}`, `{x}`, `{y}` are the standard tile coordinates
- `{format}` is the output format you selected (png, jpg, or webp)

### Stylesheet URL Examples

For your generated raster tile sets, use these URLs in your stylesheet:

```javascript
// Glacier Ambient Layer
"http://localhost:8091/glacier_10m_ambient/{z}/{x}/{y}.png"

// Glacier Shadows Layer
"http://localhost:8091/glacier_10m_shadows/{z}/{x}/{y}.png"

// Glacier Texture Layer
"http://localhost:8091/glacier_10m_texture/{z}/{x}/{y}.png"
```

> **Note**: The scripts will display these URLs automatically at the end of processing and when starting the server.

### Mapbox GL JS Example

```javascript
map.addSource('glacier-ambient', {
  'type': 'raster',
  'tiles': [
    'http://localhost:8091/glacier_10m_ambient/{z}/{x}/{y}.png'
  ],
  'tileSize': 256,
  'maxzoom': 14
});

map.addLayer({
  'id': 'glacier-ambient-layer',
  'type': 'raster',
  'source': 'glacier-ambient',
  'paint': {
    'raster-opacity': 0.8
  }
});
```

### Maplibre Example

```javascript
map.addSource('glacier-texture', {
  'type': 'raster',
  'tiles': [
    'http://localhost:8091/glacier_10m_texture/{z}/{x}/{y}.png'
  ],
  'tileSize': 256,
  'maxzoom': 14
});

map.addLayer({
  'id': 'glacier-texture-layer',
  'type': 'raster',
  'source': 'glacier-texture',
  'paint': {
    'raster-opacity': 0.7
  }
});
```

## Advanced Configuration

### Tile Size

By default, the tile size is 256x256 pixels, which is the standard for web mapping. However, many modern applications use larger tiles for better performance and quality, especially on high-DPI displays.

To modify the tile size, you need to use the `--tile-size` option in GDAL. Our scripts will be updated to support this option directly, but for now, you can customize it in the Docker command:

```bash
docker run --rm -v "$(pwd)/raster_input:/data/input" -v "$(pwd)/raster_tiles:/data/output" osgeo/gdal gdal2tiles.py --zoom=8-14 --tile-size=512 --resampling=lanczos /data/input/my_file.tif /data/output/my_file
```

Common tile sizes:
- 256x256: Standard size, compatible with all mapping libraries
- 512x512: Better for high-DPI displays, reduces the number of HTTP requests
- 514x514: Slightly larger than 512, provides a 1-pixel buffer for seamless rendering

When using larger tile sizes, be sure to update your mapping library configuration:

```javascript
map.addSource('my-raster-source', {
  'type': 'raster',
  'tiles': [
    'http://localhost:8090/my_terrain/{z}/{x}/{y}.png'
  ],
  'tileSize': 512,  // Match this to your tile size
  'maxzoom': 16
});
```

### Serving Tiles

After processing your tiles, you can serve them using our dedicated script:

```bash
./scripts/serve_tiles.sh [--port PORT] [--dir DIRECTORY]
```

This script will:
- Check if the specified port is available
- Automatically find an available port if the specified one is in use
- Start a simple HTTP server to serve your tiles

Example:
```bash
./scripts/serve_tiles.sh --port 9000
```

#### Using the Built-in Viewer

We've included a simple web-based viewer to help you visualize your tiles. After starting the server, open:

```
http://localhost:8090/viewer.html
```

The viewer provides:
- Layer visibility toggles for each of your raster datasets
- Opacity controls for each layer
- An OpenStreetMap base layer for reference
- Automatic detection of all available tile sets

### Analyzing Tile Generation

To get statistics about your generated tiles:

```bash
./scripts/analyze_tiles.sh [--dir DIRECTORY]
```

This will show:
- Total number of datasets
- Number of tiles per zoom level
- Size of each zoom level
- Total number of tiles and size

## Integration with Map Stylesheets

- **GDAL Import Error**: If you get import errors for GDAL, see the [GDAL Installation Guide](GDAL_INSTALL.md) for detailed installation instructions.
- **No Module Named '_gdal'**: This is a common error when the GDAL Python bindings aren't correctly installed. Use the `--force-cli` flag to use command-line tools instead.
- **Permissions Error**: Make sure the scripts have executable permissions.
- **No Tiles Generated**: Check that your GeoTIFF files are in the correct directory and have proper geospatial referencing.
- **Address Already in Use Error**: If you see an error like "OSError: [Errno 48] Address already in use" when starting the server, the port (default 8091) is already being used by another application. You can:
  - Choose a different port: `cd raster_tiles && python -m http.server 9000`
  - Find and stop the process using the current port:
    ```bash
    # Find the process using port 8091
    lsof -i :8091
    
    # Kill the process by PID
    kill <PID>
    ```

## Requirements

- GDAL 3.x (Python bindings or command-line tools)
- Python 3.7+
- Additional Python packages: tqdm (optional)
