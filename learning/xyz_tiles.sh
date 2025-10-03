#!/bin/bash

# This script processes raster .tif files and creates tiles in XYZ format
# (compatible with most web maps including Leaflet, Google Maps, etc.)

# Default settings
INPUT_DIR="source_data"
OUTPUT_DIR="raster_tiles"
MIN_ZOOM=9
MAX_ZOOM=13
RESAMPLING="lanczos"
FORMAT="png"
PORT=8090
VERBOSE=""

# Color codes for log messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages with timestamp
log() {
    local message="$1"
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $message"
}

# Display help message
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -i, --input DIR       Input directory containing .tif files (default: $INPUT_DIR)"
    echo "  -o, --output DIR      Output directory for tiles (default: $OUTPUT_DIR)"
    echo "  -m, --min-zoom LEVEL  Minimum zoom level (default: $MIN_ZOOM)"
    echo "  -M, --max-zoom LEVEL  Maximum zoom level (default: $MAX_ZOOM)"
    echo "  -r, --resampling ALG  Resampling algorithm (default: $RESAMPLING)"
    echo "                        Options: near, bilinear, cubic, cubicspline, lanczos, average, mode"
    echo "  -f, --format FORMAT   Output format (default: $FORMAT)"
    echo "                        Options: png, jpg, webp"
    echo "  -p, --port PORT       Port for tile server (default: $PORT)"
    echo "  -v, --verbose         Enable verbose output"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -i my_data -o my_tiles -m 8 -M 14 -r lanczos -f png"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -m|--min-zoom)
            MIN_ZOOM="$2"
            shift 2
            ;;
        -M|--max-zoom)
            MAX_ZOOM="$2"
            shift 2
            ;;
        -r|--resampling)
            RESAMPLING="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="--verbose"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    log "${RED}Error: Input directory '$INPUT_DIR' does not exist.${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# List input files
log "Input files:"
find "$INPUT_DIR" -name "*.tif" | while read -r file; do
    log "  - $(basename "$file")"
done

# Check if GDAL is installed
if ! command -v gdal2tiles.py &>/dev/null; then
    log "${RED}Error: gdal2tiles.py is not installed. Please install GDAL.${NC}"
    exit 1
fi

# Process each .tif file separately
find "$INPUT_DIR" -name "*.tif" | while read -r tif_file; do
    base_name=$(basename "$tif_file" .tif)
    file_output_dir="$OUTPUT_DIR/$base_name"
    
    log "Processing file: $tif_file"
    log "Output directory: $file_output_dir"
    
    # Create output directory for this file
    mkdir -p "$file_output_dir"
    
    # Build the gdal2tiles.py command using mercator profile (XYZ format)
    GDAL_CMD="gdal2tiles.py --zoom=$MIN_ZOOM-$MAX_ZOOM --resampling=$RESAMPLING --webviewer=none --profile=mercator"
    
    # Add format option if not PNG (which is the default)
    if [ "$FORMAT" != "png" ]; then
        GDAL_CMD="$GDAL_CMD --format=$FORMAT"
    fi
    
    # Add verbose flag if specified
    if [ -n "$VERBOSE" ]; then
        GDAL_CMD="$GDAL_CMD --verbose"
    fi
    
    # Add the input and output paths
    GDAL_CMD="$GDAL_CMD $tif_file $file_output_dir"
    
    log "Running GDAL command: $GDAL_CMD"
    
    # Execute the command and capture the exit code
    eval $GDAL_CMD
    EXIT_CODE=$?
    
    log "GDAL command for $base_name completed with exit code: $EXIT_CODE"
    
    # Check for output files
    TILE_COUNT=$(find "$file_output_dir" -type f -name "*.$FORMAT" 2>/dev/null | wc -l)
    log "Generated $TILE_COUNT tiles for $base_name"
    
    if [ $EXIT_CODE -ne 0 ]; then
        log "${YELLOW}Warning: Processing for $base_name encountered an error.${NC}"
    elif [ $TILE_COUNT -eq 0 ]; then
        log "${YELLOW}Warning: No tiles were generated for $base_name.${NC}"
    else
        log "${GREEN}Successfully processed $base_name${NC}"
    fi
done

# Check overall results
TOTAL_TILES=$(find "$OUTPUT_DIR" -type f -name "*.$FORMAT" 2>/dev/null | wc -l)
log "Total tiles generated: $TOTAL_TILES"

if [ $TOTAL_TILES -gt 0 ]; then
    log "${GREEN}Tile generation completed successfully.${NC}"
    log "To serve these tiles, run:"
    log "cd $OUTPUT_DIR && python -m http.server $PORT"
    log "Then access them at http://localhost:$PORT"
    
    # Print the stylesheet URLs for each dataset
    log "${BLUE}=== Tile Source URLs for Your Stylesheet ===${NC}"
    find "$OUTPUT_DIR" -maxdepth 1 -type d | grep -v "^$OUTPUT_DIR$" | while read -r dataset; do
        dataset_name=$(basename "$dataset")
        log "  $dataset_name: http://localhost:$PORT/$dataset_name/{z}/{x}/{y}.$FORMAT"
    done
    log "${BLUE}=== End of Tile Source URLs ===${NC}"
    log "${GREEN}These tiles are in XYZ format and should work with most web mapping libraries without special configuration.${NC}"
    
    # Ask if the user wants to start the server
    log "Starting server on port $PORT..."
    log "Press Ctrl+C to stop the server"
    (cd "$OUTPUT_DIR" && python -m http.server $PORT)
else
    log "${RED}No tiles were generated. Check the logs for errors.${NC}"
fi

log "Processing complete"
