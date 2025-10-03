#!/bin/bash
# Run the raster tile processor in Docker

# Ensure we're in the project directory
cd "$(dirname "$0")/.."

# Parse arguments
MIN_ZOOM=0
MAX_ZOOM=14
FORMAT="png"
RESAMPLING="cubic"
PORT=8090
VERBOSE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --min-zoom|-min)
      MIN_ZOOM="$2"
      shift 2
      ;;
    --max-zoom|-max)
      MAX_ZOOM="$2"
      shift 2
      ;;
    --format|-f)
      FORMAT="$2"
      shift 2
      ;;
    --resampling|-r)
      RESAMPLING="$2"
      shift 2
      ;;
    --port|-p)
      PORT="$2"
      shift 2
      ;;
    --verbose|-v)
      VERBOSE="--verbose"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--min-zoom N] [--max-zoom N] [--format png|jpg|webp] [--resampling METHOD] [--port PORT] [--verbose]"
      exit 1
      ;;
  esac
done

# Create the directories if they don't exist
mkdir -p raster_input
mkdir -p raster_tiles

echo "Running raster tile processor in Docker container..."
echo "Make sure you have placed your .tif files in the raster_input/ directory"

# Check if docker-compose is available
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    # For Docker CLI plugin (newer Docker versions)
    DOCKER_COMPOSE="docker compose"
else
    echo "Error: Neither docker-compose nor docker compose commands are available."
    echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop/"
    echo "After installation, make sure Docker is running before trying again."
    exit 1
fi

# Copy the scripts to the dspvector directory so they're accessible in the container
cp -f scripts/raster_tiles.py dspvector/
cp -f dspvector/modules/raster_tiler.py dspvector/

# Run the command in Docker
echo "Using command: $DOCKER_COMPOSE run -v "$(pwd)/raster_input:/raster_input" -v "$(pwd)/raster_tiles:/raster_tiles" --entrypoint python dspvector /src/raster_tiles.py --input-dir /raster_input --output-dir /raster_tiles --min-zoom $MIN_ZOOM --max-zoom $MAX_ZOOM --format $FORMAT --resampling $RESAMPLING $VERBOSE"

# Create a volume mount for the raster_input and raster_tiles directories
$DOCKER_COMPOSE run -v "$(pwd)/raster_input:/raster_input" -v "$(pwd)/raster_tiles:/raster_tiles" --entrypoint python dspvector /src/raster_tiles.py --input-dir /raster_input --output-dir /raster_tiles --min-zoom $MIN_ZOOM --max-zoom $MAX_ZOOM --format $FORMAT --resampling $RESAMPLING $VERBOSE
DOCKER_EXIT_CODE=$?

echo "Docker command completed with exit code: $DOCKER_EXIT_CODE"

# Check for actual files in the output directory
echo "Checking for generated tiles..."
TILE_COUNT=$(find raster_tiles -type f -name "*.${FORMAT}" | wc -l)
echo "Found $TILE_COUNT tile files in raster_tiles/"

if [ $DOCKER_EXIT_CODE -eq 0 ] && [ $TILE_COUNT -gt 0 ]; then
    echo "Process completed successfully."
    echo "Your tiles should be available at http://localhost:$PORT"
    
    # Print the stylesheet URLs for each dataset
    echo "=== Tile Source URLs for Your Stylesheet ==="
    find raster_tiles -maxdepth 1 -type d | grep -v "^raster_tiles$" | while read -r dataset; do
        dataset_name=$(basename "$dataset")
        echo "  $dataset_name: http://localhost:$PORT/$dataset_name/{z}/{x}/{y}.$FORMAT"
    done
    echo "=== End of Tile Source URLs ==="
    
    # Start a simple HTTP server to serve the tiles
    echo "Starting server on port $PORT..."
    echo "Press Ctrl+C to stop the server"
    
    # Use Python to start a server
    (cd raster_tiles && python -m http.server $PORT)
else
    if [ $DOCKER_EXIT_CODE -ne 0 ]; then
        echo "Process encountered an error. Docker exit code: $DOCKER_EXIT_CODE"
    else
        echo "Process completed but no tiles were generated."
        echo "Check if your input .tif files are valid GeoTIFFs with proper geospatial referencing."
    fi
fi

if [ $? -eq 0 ]; then
    echo "Process completed successfully."
    echo "Your tiles should be available at http://localhost:8090"
    
    # Start a simple HTTP server to serve the tiles
    echo "Starting server on port $PORT..."
    echo "Press Ctrl+C to stop the server"
    
    # Use Python to start a server
    (cd raster_tiles && python -m http.server $PORT)
else
    echo "Process encountered an error. Check the Docker logs for more details."
fi
