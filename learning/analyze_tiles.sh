#!/bin/bash
# Script to analyze raster tile generation

OUTPUT_DIR="raster_tiles"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dir DIRECTORY]"
            exit 1
            ;;
    esac
done

# Check if the output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Directory '$OUTPUT_DIR' does not exist."
    exit 1
fi

echo "====== Raster Tile Analysis ======"

# Get list of subdirectories (one per input file)
DATASETS=$(find "$OUTPUT_DIR" -maxdepth 1 -type d | grep -v "^$OUTPUT_DIR$" | sort)

if [ -z "$DATASETS" ]; then
    echo "No processed datasets found in $OUTPUT_DIR"
    exit 1
fi

echo "Found $(echo "$DATASETS" | wc -l | tr -d ' ') datasets"
echo ""

# For each dataset, analyze tiles
for DATASET in $DATASETS; do
    DATASET_NAME=$(basename "$DATASET")
    echo "Dataset: $DATASET_NAME"
    
    # Get list of zoom levels
    ZOOM_LEVELS=$(find "$DATASET" -maxdepth 1 -type d | grep -v "^$DATASET$" | sort)
    
    if [ -z "$ZOOM_LEVELS" ]; then
        echo "  No zoom levels found"
        continue
    fi
    
    echo "  Zoom Levels: $(echo "$ZOOM_LEVELS" | xargs -n 1 basename | tr '\n' ', ' | sed 's/,$//')"
    
    # Calculate total tiles and size
    TOTAL_TILES=0
    TOTAL_SIZE=0
    
    echo "  Tiles by zoom level:"
    for ZOOM in $ZOOM_LEVELS; do
        ZOOM_NAME=$(basename "$ZOOM")
        TILE_COUNT=$(find "$ZOOM" -type f | wc -l | tr -d ' ')
        ZOOM_SIZE=$(du -sh "$ZOOM" | cut -f1)
        
        echo "    Zoom $ZOOM_NAME: $TILE_COUNT tiles ($ZOOM_SIZE)"
        
        # Add to totals
        TOTAL_TILES=$((TOTAL_TILES + TILE_COUNT))
        ZOOM_SIZE_BYTES=$(du -s "$ZOOM" | cut -f1)
        TOTAL_SIZE=$((TOTAL_SIZE + ZOOM_SIZE_BYTES))
    done
    
    # Convert total size to human-readable format
    if command -v numfmt >/dev/null 2>&1; then
        TOTAL_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)
    else
        # Simple human-readable conversion if numfmt is not available
        if [ $TOTAL_SIZE -gt 1073741824 ]; then # 1 GB
            TOTAL_SIZE_HUMAN="$(echo "scale=2; $TOTAL_SIZE / 1073741824" | bc)GB"
        elif [ $TOTAL_SIZE -gt 1048576 ]; then # 1 MB
            TOTAL_SIZE_HUMAN="$(echo "scale=2; $TOTAL_SIZE / 1048576" | bc)MB"
        elif [ $TOTAL_SIZE -gt 1024 ]; then # 1 KB
            TOTAL_SIZE_HUMAN="$(echo "scale=2; $TOTAL_SIZE / 1024" | bc)KB"
        else
            TOTAL_SIZE_HUMAN="${TOTAL_SIZE}B"
        fi
    fi
    
    echo "  Total: $TOTAL_TILES tiles ($TOTAL_SIZE_HUMAN)"
    echo ""
done

# Calculate grand totals
GRAND_TOTAL_TILES=$(find "$OUTPUT_DIR" -type f -not -path "*/\.*" | wc -l | tr -d ' ')
GRAND_TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)

echo "====== Summary ======"
echo "Total Datasets: $(echo "$DATASETS" | wc -l | tr -d ' ')"
echo "Total Tiles: $GRAND_TOTAL_TILES"
echo "Total Size: $GRAND_TOTAL_SIZE"

# Print stylesheet URLs
echo -e "\n=== Tile Source URLs for Your Stylesheet ==="
echo "Port: 8090 (default, adjust as needed)"
for DATASET in $DATASETS; do
    DATASET_NAME=$(basename "$DATASET")
    echo "  $DATASET_NAME: http://localhost:8090/$DATASET_NAME/{z}/{x}/{y}.png"
done
echo "=== End of Tile Source URLs ==="

echo -e "\nTo serve these tiles, run:"
echo "  ./scripts/serve_tiles.sh"
echo "or"
echo "  cd $OUTPUT_DIR && python -m http.server 8080"
