#!/usr/bin/env python
import os
import sys
import argparse
import subprocess
import logging
from pathlib import Path

# Try to import GDAL, but don't fail if it's not available
try:
    from osgeo import gdal
    HAS_GDAL = True
except ImportError:
    print("WARNING: GDAL Python bindings not available. Will use command-line GDAL tools instead.")
    HAS_GDAL = False

def setup_logging(verbose=False):
    """Configure logging based on verbose flag"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[logging.StreamHandler()]
    )
    return logging.getLogger('raster_tiles')

def check_gdal_command_line():
    """Check if GDAL command-line tools are available"""
    try:
        result = subprocess.run(['gdal_translate', '--version'], 
                              stdout=subprocess.PIPE, 
                              stderr=subprocess.PIPE, 
                              text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False

def process_raster_cli(input_file, output_dir, min_zoom, max_zoom, format='png', resampling='lanczos', logger=None):
    """Process a raster file using GDAL command line tools"""
    if logger is None:
        logger = logging.getLogger('raster_tiles')
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Build the gdal2tiles.py command
    cmd = [
        'gdal2tiles.py',
        '--zoom={}-{}'.format(min_zoom, max_zoom),
        '--resampling={}'.format(resampling),
        '--webviewer=none'
    ]
    
    # Add format option if not PNG (which is the default)
    if format.lower() != 'png':
        cmd.append('--format={}'.format(format))
    
    # Add the input and output paths
    cmd.append(input_file)
    cmd.append(output_dir)
    
    # Log the command
    logger.info(f"Running: {' '.join(cmd)}")
    
    # Run the command
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        
        # Process output in real-time
        for line in process.stdout:
            logger.debug(line.strip())
        
        # Get the return code
        process.wait()
        
        if process.returncode != 0:
            stderr = process.stderr.read()
            logger.error(f"gdal2tiles.py failed with code {process.returncode}: {stderr}")
            return False
        return True
    except Exception as e:
        logger.error(f"Error running gdal2tiles.py: {str(e)}")
        return False

def process_raster_python(input_file, output_dir, min_zoom, max_zoom, format='png', resampling='lanczos', logger=None):
    """Process a raster file using GDAL Python bindings"""
    if logger is None:
        logger = logging.getLogger('raster_tiles')
    
    if not HAS_GDAL:
        logger.error("GDAL Python bindings are not available. Cannot process using Python API.")
        return False
    
    logger.info(f"Processing {input_file} using GDAL Python bindings")
    # This would use the GDAL Python API to generate tiles
    # For now, we'll just call back to the command line version since that's more reliable
    return process_raster_cli(input_file, output_dir, min_zoom, max_zoom, format, resampling, logger)

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Generate raster tiles from GeoTIFF files')
    parser.add_argument('--input-dir', required=True, help='Directory containing GeoTIFF files')
    parser.add_argument('--output-dir', required=True, help='Directory where tiles will be generated')
    parser.add_argument('--min-zoom', type=int, default=8, help='Minimum zoom level (default: 8)')
    parser.add_argument('--max-zoom', type=int, default=14, help='Maximum zoom level (default: 14)')
    parser.add_argument('--format', choices=['png', 'jpg', 'webp'], default='png', help='Tile format (default: png)')
    parser.add_argument('--resampling', default='lanczos', help='Resampling method (default: lanczos)')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    parser.add_argument('--single-file', help='Process only a specific file in the input directory')
    args = parser.parse_args()
    
    # Setup logging
    logger = setup_logging(args.verbose)
    
    # Check GDAL availability
    has_gdal_cli = check_gdal_command_line()
    if not HAS_GDAL and not has_gdal_cli:
        logger.error("Neither GDAL Python bindings nor command-line tools are available. Cannot proceed.")
        sys.exit(1)
    
    # Log the configuration
    logger.info(f"Processing GeoTIFFs from {args.input_dir}")
    logger.info(f"Output directory: {args.output_dir}")
    logger.info(f"Zoom levels: {args.min_zoom} to {args.max_zoom}")
    logger.info(f"Format: {args.format}")
    logger.info(f"Resampling: {args.resampling}")
    if args.single_file:
        logger.info(f"Processing only file: {args.single_file}")
    
    # Ensure output directory exists
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Find all .tif files in the input directory
    if args.single_file:
        tif_files = [Path(args.input_dir) / args.single_file]
        if not tif_files[0].exists():
            logger.error(f"Specified file {tif_files[0]} does not exist")
            sys.exit(1)
    else:
        tif_files = list(Path(args.input_dir).glob('*.tif'))
    
    if not tif_files:
        logger.error(f"No .tif files found in {args.input_dir}")
        sys.exit(1)
    
    logger.info(f"Found {len(tif_files)} .tif files to process")
    
    # Process each file
    success_count = 0
    for tif_file in tif_files:
        logger.info(f"Processing {tif_file}")
        
        # Choose the processing method based on availability
        if HAS_GDAL:
            success = process_raster_python(str(tif_file), args.output_dir, args.min_zoom, args.max_zoom, args.format, args.resampling, logger)
        else:
            success = process_raster_cli(str(tif_file), args.output_dir, args.min_zoom, args.max_zoom, args.format, args.resampling, logger)
        
        if success:
            success_count += 1
    
    # Log the summary
    logger.info(f"Processed {success_count} of {len(tif_files)} files successfully")
    if success_count == len(tif_files):
        logger.info("All files processed successfully")
        sys.exit(0)
    else:
        logger.warning(f"Failed to process {len(tif_files) - success_count} files")
        sys.exit(1)

if __name__ == '__main__':
    main()
