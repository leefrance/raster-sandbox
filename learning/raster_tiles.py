#!/usr/bin/env python
"""
Process and serve raster tiles from GeoTIFF files.
"""

import os
import sys
import argparse
import logging
import time
import importlib.util
from pathlib import Path
import http.server
import socketserver
import threading
import webbrowser
import subprocess
from typing import List

# Add the parent directory to sys.path to import modules
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

# Try to import the RasterTiler, but handle import errors gracefully
try:
    from dspvector.modules.raster_tiler import RasterTiler
    RASTER_TILER_AVAILABLE = True
except ImportError as e:
    RASTER_TILER_AVAILABLE = False
    logging.warning(f"Could not import RasterTiler: {str(e)}")
    logging.warning("Falling back to command-line GDAL tools")


class RasterTileServer(http.server.SimpleHTTPRequestHandler):
    """Simple HTTP server that adds CORS headers for tile serving."""
    
    def end_headers(self):
        """Add CORS headers before ending headers."""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS preflight."""
        self.send_response(200)
        self.end_headers()


def start_server(directory: str, port: int = 8090) -> None:
    """
    Start a simple HTTP server to serve the raster tiles.
    
    Args:
        directory: Directory containing the tiles
        port: Port to serve on
    """
    # Change to the directory containing the tiles
    os.chdir(directory)
    
    # Create the server
    handler = RasterTileServer
    httpd = socketserver.TCPServer(("", port), handler)
    
    logging.info(f"Serving raster tiles at http://localhost:{port}")
    logging.info("Press Ctrl+C to stop the server")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logging.info("Server stopped")
        httpd.shutdown()


def generate_html_viewer(sources: List[str], output_dir: str, port: int = 8090) -> str:
    """
    Generate a simple HTML viewer for the raster tiles.
    
    Args:
        sources: List of source names
        output_dir: Directory to write the HTML file
        port: Port the server is running on
        
    Returns:
        Path to the HTML file
    """
    html_path = os.path.join(output_dir, 'viewer.html')
    
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raster Tile Viewer</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.7.1/dist/leaflet.css" />
    <style>
        body, html {{ height: 100%; margin: 0; padding: 0; }}
        #map {{ height: 100%; }}
        .layer-control {{
            position: absolute;
            top: 10px;
            right: 10px;
            z-index: 1000;
            background: white;
            padding: 10px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }}
        .layer-control h3 {{
            margin-top: 0;
            margin-bottom: 10px;
        }}
        .layer-item {{
            margin-bottom: 5px;
        }}
    </style>
</head>
<body>
    <div id="map"></div>
    <div class="layer-control">
        <h3>Raster Layers</h3>
        <div id="layer-list">
            <!-- Layer controls will be added here -->
        </div>
    </div>

    <script src="https://unpkg.com/leaflet@1.7.1/dist/leaflet.js"></script>
    <script>
        // Initialize the map
        const map = L.map('map').setView([0, 0], 2);
        
        // Add OpenStreetMap as a base layer
        L.tileLayer('https://{{s}}.tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png', {{
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }}).addTo(map);
        
        // Define the raster layers
        const rasterLayers = {{'OpenStreetMap': null}};
        
        // Add raster tile layers
        """
    
    # Add a layer for each source
    for source in sources:
        html_content += f"""
        rasterLayers['{source}'] = L.tileLayer('http://localhost:{port}/{source}/{{z}}/{{x}}/{{y}}.png', {{
            minZoom: 0,
            maxZoom: 18,
            attribution: 'Generated Raster Tiles'
        }});
        """
    
    # Add layer controls
    html_content += """
        // Create layer controls
        const layerList = document.getElementById('layer-list');
        
        Object.keys(rasterLayers).forEach((layerName, index) => {
            const layerItem = document.createElement('div');
            layerItem.className = 'layer-item';
            
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.id = `layer-${index}`;
            checkbox.checked = index === 0;
            
            const label = document.createElement('label');
            label.htmlFor = `layer-${index}`;
            label.textContent = layerName;
            
            checkbox.addEventListener('change', () => {
                if (checkbox.checked) {
                    if (rasterLayers[layerName]) {
                        rasterLayers[layerName].addTo(map);
                    }
                } else {
                    if (rasterLayers[layerName]) {
                        map.removeLayer(rasterLayers[layerName]);
                    }
                }
            });
            
            layerItem.appendChild(checkbox);
            layerItem.appendChild(label);
            layerList.appendChild(layerItem);
            
            // Add the first layer to the map
            if (index === 1 && rasterLayers[layerName]) {
                rasterLayers[layerName].addTo(map);
            }
        });
        
        // Try to fit the map to the bounds of the first layer
        if (Object.keys(rasterLayers).length > 1) {
            const firstLayerName = Object.keys(rasterLayers)[1];
            const firstLayer = rasterLayers[firstLayerName];
            
            // This will center the map when the first tiles load
            if (firstLayer) {
                firstLayer.on('load', function() {
                    try {
                        // Center approximately on loaded tiles
                        map.setView([35, -100], 4);
                    } catch (e) {
                        console.error('Error setting map view:', e);
                    }
                });
            }
        }
    </script>
</body>
</html>
"""
    
    with open(html_path, 'w') as f:
        f.write(html_content)
    
    return html_path


def process_with_gdal_cli(input_dir: str, output_dir: str, min_zoom: int, max_zoom: int, 
                  output_format: str, resampling_method: str) -> List[str]:
    """
    Process GeoTIFF files using command-line GDAL tools.
    
    This is a fallback for when the RasterTiler is not available.
    """
    # Check if gdal2tiles.py is available
    try:
        subprocess.run(["gdal2tiles.py", "--version"], capture_output=True, check=True)
    except (subprocess.SubprocessError, FileNotFoundError):
        logging.error("gdal2tiles.py not found. Please install GDAL command-line tools.")
        logging.error("You can install GDAL tools with 'conda install -c conda-forge gdal'")
        return []
    
    # Find all .tif files in the input directory
    tif_files = [os.path.join(input_dir, f) for f in os.listdir(input_dir) 
                 if f.lower().endswith(('.tif', '.tiff'))]
    
    if not tif_files:
        logging.warning(f"No .tif files found in {input_dir}")
        return []
    
    # Map resampling methods for GDAL command line
    resampling_map = {
        "nearest": "near",
        "bilinear": "bilinear",
        "cubic": "cubic",
        "cubicspline": "cubicspline",
        "lanczos": "lanczos",
        "average": "average",
        "mode": "mode"
    }
    resampling = resampling_map.get(resampling_method, "cubic")
    
    # Map output formats
    format_map = {
        "png": "PNG",
        "jpg": "JPEG",
        "webp": "WEBP"
    }
    gdal_format = format_map.get(output_format.lower(), "PNG")
    
    processed_sources = []
    
    for tif_file in tif_files:
        try:
            # Get source name from filename without extension
            source_name = os.path.splitext(os.path.basename(tif_file))[0]
            logging.info(f"Processing {source_name}...")
            
            # Create output directory
            tile_dir = os.path.join(output_dir, source_name)
            os.makedirs(tile_dir, exist_ok=True)
            
            # Create a VRT in Web Mercator projection
            vrt_path = os.path.join(output_dir, f"temp_web_mercator_{source_name}_{int(time.time())}.vrt")
            
            logging.info("Creating Web Mercator VRT...")
            subprocess.run([
                "gdalwarp", 
                "-t_srs", "EPSG:3857",
                "-r", resampling,
                "-of", "VRT",
                tif_file, 
                vrt_path
            ], check=True)
            
            # Use gdal2tiles.py to generate the tiles
            logging.info(f"Generating tiles for zoom levels {min_zoom} to {max_zoom}...")
            
            subprocess.run([
                "gdal2tiles.py",
                "--zoom", f"{min_zoom}-{max_zoom}",
                "--resampling", resampling,
                "--webviewer", "none",
                "--tilesize", "256",
                "--processes", str(os.cpu_count() or 1),
                "--format", gdal_format,
                vrt_path,
                tile_dir
            ], check=True)
            
            # Clean up temporary VRT
            try:
                os.remove(vrt_path)
            except OSError:
                logging.warning(f"Could not remove temporary file {vrt_path}")
            
            processed_sources.append(source_name)
            logging.info(f"Completed processing {source_name}")
            
        except Exception as e:
            logging.error(f"Error processing {tif_file}: {str(e)}")
    
    return processed_sources


def main():
    """Main function to process and serve raster tiles."""
    parser = argparse.ArgumentParser(description='Process and serve raster tiles from GeoTIFF files.')
    parser.add_argument('--input-dir', '-i', type=str, default='raster_input', 
                        help='Directory containing input .tif files')
    parser.add_argument('--output-dir', '-o', type=str, default='raster_tiles',
                        help='Directory to output raster tiles')
    parser.add_argument('--min-zoom', '-min', type=int, default=0,
                        help='Minimum zoom level to generate')
    parser.add_argument('--max-zoom', '-max', type=int, default=14,
                        help='Maximum zoom level to generate')
    parser.add_argument('--format', '-f', type=str, choices=['png', 'jpg', 'webp'], default='png',
                        help='Output format for the tiles')
    parser.add_argument('--resampling', '-r', type=str, 
                        choices=['nearest', 'bilinear', 'cubic', 'cubicspline', 'lanczos', 'average', 'mode'],
                        default='cubic', help='Resampling method to use')
    parser.add_argument('--port', '-p', type=int, default=8090,
                        help='Port to serve the tiles on')
    parser.add_argument('--serve-only', '-s', action='store_true',
                        help='Skip processing and only serve existing tiles')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Enable verbose logging')
    parser.add_argument('--force-cli', action='store_true',
                        help='Force using GDAL command-line tools even if Python GDAL is available')
    
    args = parser.parse_args()
    
    # Configure logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(level=log_level, format='%(asctime)s - %(levelname)s - %(message)s')
    
    # Create input and output directories if they don't exist
    os.makedirs(args.input_dir, exist_ok=True)
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Process the files if not in serve-only mode
    processed_sources = []
    if not args.serve_only:
        if RASTER_TILER_AVAILABLE and not args.force_cli:
            logging.info("Using Python GDAL through RasterTiler")
            try:
                tiler = RasterTiler(
                    input_dir=args.input_dir,
                    output_dir=args.output_dir,
                    min_zoom=args.min_zoom,
                    max_zoom=args.max_zoom,
                    output_format=args.format,
                    resampling_method=args.resampling
                )
                processed_sources = tiler.process_all_tifs()
            except Exception as e:
                logging.error(f"Error using RasterTiler: {str(e)}")
                logging.info("Falling back to command-line GDAL tools")
                processed_sources = process_with_gdal_cli(
                    args.input_dir, args.output_dir, args.min_zoom, 
                    args.max_zoom, args.format, args.resampling
                )
        else:
            logging.info("Using command-line GDAL tools")
            processed_sources = process_with_gdal_cli(
                args.input_dir, args.output_dir, args.min_zoom, 
                args.max_zoom, args.format, args.resampling
            )
        
        if processed_sources:
            logging.info(f"Successfully processed {len(processed_sources)} source(s): {', '.join(processed_sources)}")
            logging.info(f"Tiles are available in {os.path.abspath(args.output_dir)}")
        else:
            logging.warning("No sources were processed")
    
    # Get all sources if in serve-only mode
    if args.serve_only:
        processed_sources = [d for d in os.listdir(args.output_dir) 
                           if os.path.isdir(os.path.join(args.output_dir, d))]
        
        if not processed_sources:
            logging.error(f"No tile sources found in {args.output_dir}")
            return 1
        
        logging.info(f"Found {len(processed_sources)} source(s) to serve: {', '.join(processed_sources)}")
    
    # Generate HTML viewer
    html_path = generate_html_viewer(processed_sources, args.output_dir, args.port)
    logging.info(f"Generated HTML viewer at {html_path}")
    
    # Open the HTML viewer in a browser
    viewer_url = f"file://{os.path.abspath(html_path)}"
    threading.Timer(1.0, lambda: webbrowser.open(viewer_url)).start()
    
    # Start the server
    start_server(args.output_dir, args.port)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
