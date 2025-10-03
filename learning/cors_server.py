#!/usr/bin/env python3
"""
CORS-enabled HTTP Server for Raster Tiles

This script starts a simple HTTP server that adds CORS headers to responses,
allowing tiles to be accessed from different origins (domains/ports).

Usage:
  python3 cors_server.py [port]

Default port is 8091 if not specified.
"""

import http.server
import socketserver
import sys
import os
from pathlib import Path

# Default port
PORT = 8091 if len(sys.argv) < 2 else int(sys.argv[1])

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Handler that adds CORS headers to responses"""
    
    def end_headers(self):
        # Add CORS headers before ending the headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        # Call the original end_headers method
        super().end_headers()
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests (preflight requests for CORS)"""
        self.send_response(200)
        self.end_headers()
    
    def log_message(self, format, *args):
        """Add color to the log messages based on the status code"""
        if args[1] == '200':
            # Green for success
            status_color = '\033[92m'
        elif args[1].startswith('4'):
            # Yellow for client errors
            status_color = '\033[93m'
        elif args[1].startswith('5'):
            # Red for server errors
            status_color = '\033[91m'
        else:
            # No color for other status codes
            status_color = '\033[0m'
        
        # Reset color
        reset_color = '\033[0m'
        
        # Format the message with color
        colored_args = list(args)
        colored_args[1] = f"{status_color}{args[1]}{reset_color}"
        
        # Call the original log_message method with colored args
        super().log_message(format, *colored_args)

def main():
    # Change to the project root directory
    project_root = Path(__file__).parent.parent
    os.chdir(project_root)
    
    # Create the server
    handler = CORSHTTPRequestHandler
    httpd = socketserver.TCPServer(("", PORT), handler)
    
    print(f"\033[94m═══════════════════════════════════════════════════\033[0m")
    print(f"\033[94m             CORS-ENABLED TILE SERVER              \033[0m")
    print(f"\033[94m═══════════════════════════════════════════════════\033[0m")
    print(f"Server running at: \033[96mhttp://localhost:{PORT}/\033[0m")
    print(f"Web viewer:        \033[96mhttp://localhost:{PORT}/viewer/\033[0m")
    print(f"Serving from:      \033[93m{project_root}\033[0m")
    print(f"CORS:              \033[92mEnabled (Access-Control-Allow-Origin: *)\033[0m")
    print(f"\nTile URL template: \033[96mhttp://localhost:{PORT}/tiles/{{layer}}/{{z}}/{{x}}/{{y}}.png\033[0m")
    print(f"\nPress Ctrl+C to stop the server")
    print(f"\033[94m───────────────────────────────────────────────────\033[0m")
    
    try:
        # Start the server
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\033[93mServer stopped by user.\033[0m")
        httpd.server_close()

if __name__ == "__main__":
    main()
