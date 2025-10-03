#!/bin/bash
# Script to serve raster tiles on a specified port

PORT=8080
OUTPUT_DIR="raster_tiles"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--port PORT] [--dir DIRECTORY]"
            exit 1
            ;;
    esac
done

# Function to check if a port is in use
is_port_in_use() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :$port >/dev/null 2>&1
        return $?
    elif command -v nc >/dev/null 2>&1; then
        nc -z localhost $port >/dev/null 2>&1
        return $?
    else
        # Fallback to a less reliable method
        (echo > /dev/tcp/localhost/$port) >/dev/null 2>&1
        return $?
    fi
}

# Find an available port starting from the specified one
find_available_port() {
    local port=$1
    local max_attempts=10
    local attempts=0
    
    while is_port_in_use $port && [ $attempts -lt $max_attempts ]; do
        echo "Port $port is already in use, trying the next one..."
        port=$((port + 1))
        attempts=$((attempts + 1))
    done
    
    if [ $attempts -eq $max_attempts ]; then
        echo "Could not find an available port after $max_attempts attempts."
        exit 1
    fi
    
    echo $port
}

# Check if the output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Directory '$OUTPUT_DIR' does not exist."
    exit 1
fi

# Find an available port
AVAILABLE_PORT=$(find_available_port $PORT)

# If the port changed, inform the user
if [ "$AVAILABLE_PORT" != "$PORT" ]; then
    echo "Port $PORT is in use. Using port $AVAILABLE_PORT instead."
    PORT=$AVAILABLE_PORT
fi

echo "Starting server on port $PORT..."
echo "Tiles will be available at http://localhost:$PORT"

# Print the stylesheet URLs for each dataset
echo -e "\n=== Tile Source URLs for Your Stylesheet ==="
find "$OUTPUT_DIR" -maxdepth 1 -type d | grep -v "^$OUTPUT_DIR$" | while read -r dataset; do
    dataset_name=$(basename "$dataset")
    echo "  $dataset_name: http://localhost:$PORT/$dataset_name/{z}/{x}/{y}.png"
done
echo -e "=== End of Tile Source URLs ===\n"

echo "Press Ctrl+C to stop the server"

# Start the HTTP server
cd "$OUTPUT_DIR" && python -m http.server $PORT
