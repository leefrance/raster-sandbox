# 🚀 Raster Tiling Cartography Sandbox

A high-performance, folder-based raster tile generation system with both **native GDAL** and **Docker** approaches. This system processes GeoTIFF files organized in folders, creates virtual raster mosaics (VRT), and generates web-compatible XYZ tile pyramids.

## ✨ Key Features

- **🗂️ Folder-Based Architecture**: Organize GeoTIFFs by type (ambient, shadows, texture, etc.)
- **🔗 VRT Processing**: Automatically combines multiple GeoTIFFs per folder using GDAL's Virtual Raster technology
- **⚡ Dual Approach**: Choose between native GDAL (fastest) or Docker (most compatible)
- **🎯 Smart Overlap Handling**: Automatically selects highest resolution data when files overlap
- **🌐 Interactive Web Viewer**: Dynamic layer discovery with opacity controls
- **📊 Performance Optimized**: Direct XYZ generation (native) or TMS→XYZ conversion (Docker)

## 📁 Project Structure

```
raster-sandbox/
├── geotiff_input/          # Input GeoTIFF files organized by type
│   # Example subfolder structure
    ├── ambient/            # Ambient lighting rasters
│   ├── shadows/            # Shadow rasters  
│   └── texture/            # Texture rasters
├── tiles/                  # Generated tile pyramids
    #Example tile pyramids
│   ├── ambient/            # XYZ tiles for ambient layer
│   ├── shadows/            # XYZ tiles for shadows layer
│   └── texture/            # XYZ tiles for texture layer
├── viewer/                 # Web viewer interface
│   └── index.html          # Interactive map viewer
├── scripts/                # Processing scripts
│   ├── enhanced_native_gdal_tiles.sh  # Native GDAL processor (recommended)
│   ├── enhanced_docker_tiles.sh       # Docker-based processor
│   └── cors_server.py                 # Development web server
```

## 🚀 Quick Start

### Prerequisites

**For Native GDAL (Recommended):**
- macOS with Homebrew
- GDAL installed via Homebrew: `brew install gdal`

**For Docker Approach:**
- Docker Desktop installed and running

### Basic Usage

1. **Organize your GeoTIFF files** into folders by type:
   ```bash
   mkdir -p geotiff_input/{ambient,shadows,texture}
   # Copy your .tif files into appropriate folders
   ```

2. **Generate tiles** using the native approach (fastest):
   ```bash
   ./scripts/enhanced_native_gdal_tiles.sh
   ```

   Or using Docker (most compatible):
   ```bash
   ./scripts/enhanced_docker_tiles.sh
   ```

3. **View results** in your browser at `http://localhost:8091/viewer/`

## 📖 Detailed Usage

### Native GDAL Approach (Recommended)

The native approach uses Homebrew GDAL directly with the `--xyz` flag for optimal performance.

**Basic command:**
```bash
./scripts/enhanced_native_gdal_tiles.sh
```

**Advanced options:**
```bash
./scripts/enhanced_native_gdal_tiles.sh \
  --tile-size 512 \
  --min-zoom 9 \
  --max-zoom 15 \
  --processes 8 \
  --port 8091
```

**Parameters:**
- `--tile-size`: Tile dimensions in pixels (default: 512)
- `--min-zoom`: Minimum zoom level (default: 9) 
- `--max-zoom`: Maximum zoom level (default: 13)
- `--processes`: Number of parallel processes (default: 4)
- `--port`: Web server port (default: 8091)

**Benefits:**
- ⚡ **Fastest performance** - Direct XYZ tile generation
- 🎯 **Native optimization** - Uses system GDAL installation
- 🔧 **Advanced GDAL features** - Full access to GDAL capabilities
- 💾 **Lower memory usage** - No containerization overhead

### Docker Approach

The Docker approach provides maximum compatibility and isolation using containerized GDAL.

**Basic command:**
```bash
./scripts/enhanced_docker_tiles.sh
```

**Advanced options:**
```bash
./scripts/enhanced_docker_tiles.sh \
  --tile-size 512 \
  --min-zoom 9 \
  --max-zoom 15 \
  --processes 4 \
  --port 8091
```

**Benefits:**
- 🐳 **Maximum compatibility** - Works on any system with Docker
- 🔒 **Isolated environment** - No local GDAL installation required
- 📦 **Consistent results** - Same GDAL version across environments
- 🛡️ **System safety** - Containerized processing

**Note:** Docker approach includes TMS→XYZ coordinate conversion, which adds processing time but ensures compatibility.

## 🔧 How It Works

### 1. Folder Discovery
The system scans `geotiff_input/` for subfolders containing GeoTIFF files:
```
geotiff_input/
├── ambient/
│   ├── region1_ambient.tif
│   └── region2_ambient.tif
└── shadows/
    └── shadows_data.tif
```

### 2. VRT Creation
For each folder, creates a Virtual Raster (VRT) that combines all GeoTIFFs:
- Uses `gdalbuildvrt` with `-resolution highest` for optimal quality
- Handles overlapping areas automatically
- Validates GeoTIFF files and logs warnings for invalid files

### 3. Tile Generation
Generates XYZ tile pyramids from each VRT:
- **Native**: Direct XYZ generation using `--xyz` flag
- **Docker**: TMS generation + coordinate conversion to XYZ

### 4. Web Viewer
Updates the interactive viewer with:
- Dynamic layer discovery
- Individual layer controls (visibility + opacity)
- Performance indicators
- Mouse position tracking

## 🎨 Web Viewer Features

The interactive web viewer provides:

- **🗺️ Base Map**: OpenStreetMap tiles for geographic context
- **🎛️ Layer Controls**: Toggle visibility and adjust opacity for each raster layer
- **📍 Mouse Tracking**: Real-time coordinate and zoom level display
- **⚡ Performance Info**: Shows generation approach and layer count
- **📱 Responsive Design**: Works on desktop and mobile devices

Access at: `http://localhost:8091/viewer/`

## 🔍 Advanced Topics

### Adding New Raster Types

To add a new type of raster data:

1. **Create a new folder** in `geotiff_input/`:
   ```bash
   mkdir geotiff_input/elevation
   ```

2. **Add GeoTIFF files** to the folder:
   ```bash
   cp my_elevation_data.tif geotiff_input/elevation/
   ```

3. **Run the processing script** - it will automatically discover the new folder:
   ```bash
   ./scripts/enhanced_native_gdal_tiles.sh
   ```

4. **Update viewer** (optional) - modify the `knownLayers` array in `viewer/index.html` for better layer discovery:
   ```javascript
   const knownLayers = ['ambient', 'shadows', 'texture', 'elevation'];
   ```

### Handling Large Datasets

For processing large geographic areas or high-resolution data:

**Optimize tile generation:**
```bash
./scripts/enhanced_native_gdal_tiles.sh \
  --processes 8 \
  --tile-size 256 \
  --max-zoom 12
```

**Consider memory usage:**
- Use more processes (`--processes`) for CPU-intensive tasks
- Use smaller tiles (`--tile-size 256`) for memory-constrained systems
- Limit zoom levels (`--max-zoom`) to control output size

### Performance Comparison

| Approach | Speed | Setup | Compatibility | Use Case |
|----------|-------|--------|---------------|----------|
| **Native GDAL** | ⚡⚡⚡ Fastest | Homebrew GDAL required | macOS/Linux | Development, Production |
| **Docker** | ⚡⚡ Fast | Docker required | Universal | CI/CD, Windows, Isolation |

## 🛠️ Development

### CORS Server

The included CORS server (`scripts/cors_server.py`) provides:
- Cross-origin resource sharing for tile requests
- Static file serving for the web viewer
- Development-friendly error handling

### File Validation

Both scripts include robust file validation:
- Checks for valid GeoTIFF format using `gdalinfo`
- Logs warnings for unsupported file types
- Skips processing if no valid files found

### Caching Strategy

Smart caching prevents unnecessary reprocessing:
- Compares file modification times
- Checks for actual tile files (not just directories)
- Only regenerates when source files are newer

## 📝 Troubleshooting

### Common Issues

**"No valid GeoTIFF files found"**
- Ensure `.tif` or `.tiff` files are in the folder
- Check file permissions and validity with `gdalinfo filename.tif`

**"Docker daemon not running"**
- Start Docker Desktop
- Verify with `docker info`

**"Homebrew GDAL not found"**
- Install with `brew install gdal`
- Check PATH includes `/opt/homebrew/opt/gdal/bin`

**Tiles not loading in viewer**
- Verify CORS server is running on correct port
- Check browser developer console for network errors
- Ensure tile files exist in expected directory structure

### Performance Issues

**Slow tile generation:**
- Use native GDAL approach instead of Docker
- Increase `--processes` parameter
- Reduce `--max-zoom` level
- Use smaller `--tile-size` if memory-constrained

**Large file sizes:**
- Consider using JPEG format for natural imagery
- Optimize source GeoTIFF files with compression
- Reduce color depth if appropriate

## 🎯 Next Steps

This system provides a solid foundation for raster tile processing. Consider these enhancements:

- **🌍 Production Deployment**: Use nginx for tile serving in production
- **☁️ Cloud Integration**: Adapt for AWS S3, Google Cloud Storage
- **🔄 Automated Processing**: Set up file watching for automatic regeneration
- **📊 Analytics**: Add tile usage tracking and performance monitoring
- **🎨 Styling**: Implement server-side tile styling and filtering

## 📚 References

- [GDAL Documentation](https://gdal.org/)
- [XYZ Tile Specification](https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames)
- [Leaflet.js Documentation](https://leafletjs.com/)
- [Virtual Raster (VRT) Format](https://gdal.org/drivers/raster/vrt.html)

---

Built with ⚡ performance and 🎯 simplicity in mind.
