#!/bin/bash
# Script to process raster tiles with robust logging

# Set default parameters
INPUT_DIR="raster_input"
OUTPUT_DIR="raster_tiles"
MIN_ZOOM=8
MAX_ZOOM=14
FORMAT="png"
RESAMPLING="lanczos"
PORT=8080
VERBOSE=""
LOG_FILE="raster_processing.log"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --min-zoom)
            MIN_ZOOM="$2"
            shift 2
            ;;
        --max-zoom)
            MAX_ZOOM="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --resampling)
            RESAMPLING="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE="--verbose"
            shift
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start logging
log "Starting raster tile processing"
log "Parameters:"
log "  Input Directory: $INPUT_DIR"
log "  Output Directory: $OUTPUT_DIR"
log "  Min Zoom: $MIN_ZOOM"
log "  Max Zoom: $MAX_ZOOM"
log "  Format: $FORMAT"
log "  Resampling: $RESAMPLING"
log "  Port: $PORT"
log "  Verbose: $([ -n "$VERBOSE" ] && echo "Yes" || echo "No")"

# Ensure input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    log "Error: Input directory '$INPUT_DIR' does not exist."
    exit 1
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    log "Creating output directory '$OUTPUT_DIR'"
    mkdir -p "$OUTPUT_DIR"
fi

# Count input files
TIF_COUNT=$(find "$INPUT_DIR" -name "*.tif" | wc -l)
log "Found $TIF_COUNT .tif files in $INPUT_DIR"

# Exit if no input files found
if [ "$TIF_COUNT" -eq 0 ]; then
    log "Error: No .tif files found in '$INPUT_DIR'."
    exit 1
fi

# List input files
log "Input files:"
find "$INPUT_DIR" -name "*.tif" | while read -r file; do
    log "  - $(basename "$file")"
done

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    log "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Determine docker-compose command
if command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif command -v "docker" &>/dev/null && docker compose version &>/dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log "Error: Neither docker-compose nor docker compose is available."
    exit 1
fi

log "Using Docker command: $DOCKER_COMPOSE"

# Process each .tif file separately
find "$INPUT_DIR" -name "*.tif" | while read -r tif_file; do
    base_name=$(basename "$tif_file" .tif)
    file_output_dir="$OUTPUT_DIR/$base_name"
    
    log "Processing file: $tif_file"
    log "Output directory: $file_output_dir"
    
    # Create output directory for this file
    mkdir -p "$file_output_dir"
    
    # Run Docker command for this file
    log "Running Docker command for $base_name..."
    
    DOCKER_CMD="$DOCKER_COMPOSE run -v \"$(pwd)/$INPUT_DIR:/raster_input\" -v \"$(pwd)/$file_output_dir:/raster_output\" --entrypoint python dspvector /src/raster_tiles.py --input-dir /raster_input --output-dir /raster_output --min-zoom $MIN_ZOOM --max-zoom $MAX_ZOOM --format $FORMAT --resampling $RESAMPLING $VERBOSE --single-file \"$(basename "$tif_file")\""
    
    log "Docker command: $DOCKER_CMD"
    
    # Execute the command and capture the exit code
    eval $DOCKER_CMD
    EXIT_CODE=$?
    
    log "Docker command for $base_name completed with exit code: $EXIT_CODE"
    
    # Check for output files
    TILE_COUNT=$(find "$file_output_dir" -type f -name "*.$FORMAT" 2>/dev/null | wc -l)
    log "Generated $TILE_COUNT tiles for $base_name"
    
    if [ $EXIT_CODE -ne 0 ]; then
        log "Warning: Processing for $base_name encountered an error."
    elif [ $TILE_COUNT -eq 0 ]; then
        log "Warning: No tiles were generated for $base_name."
    else
        log "Successfully processed $base_name"
    fi
done

# Check overall results
TOTAL_TILES=$(find "$OUTPUT_DIR" -type f -name "*.$FORMAT" 2>/dev/null | wc -l)
log "Total tiles generated: $TOTAL_TILES"

if [ $TOTAL_TILES -gt 0 ]; then
    log "Tile generation completed successfully."
    log "To serve these tiles, run:"
    log "cd $OUTPUT_DIR && python -m http.server $PORT"
    log "Then access them at http://localhost:$PORT"
    
    # Print the stylesheet URLs for each dataset
    log "=== Tile Source URLs for Your Stylesheet ==="
    find "$OUTPUT_DIR" -maxdepth 1 -type d | grep -v "^$OUTPUT_DIR$" | while read -r dataset; do
        dataset_name=$(basename "$dataset")
        log "  $dataset_name: http://localhost:$PORT/$dataset_name/{z}/{x}/{y}.$FORMAT"
    done
    log "=== End of Tile Source URLs ==="
    
    # Ask if the user wants to start the server
    log "Starting server on port $PORT..."
    log "Press Ctrl+C to stop the server"
    (cd "$OUTPUT_DIR" && python -m http.server $PORT)
else
    log "No tiles were generated. Check the logs for errors."
fi

log "Processing complete"
