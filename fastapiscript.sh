#!/bin/bash

# FastAPI Runner Script
# This script runs a FastAPI application and handles logging

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FASTAPI_DIR="/fastapiscript"  # Change this to your FastAPI project directory
PYTHON_VENV="$FASTAPI_DIR/venv"              # Path to your virtual environment
FASTAPI_MODULE="main:app"                    # Change to your FastAPI app module
LOG_DIR="/var/log/fastapiscript"
LOG_FILE="$LOG_DIR/fastapiscript-$(date +%Y%m%d).log"
PID_FILE="/tmp/fastapiscript.pid"
TIMEOUT=7200  # 2 hours in seconds

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_message "Terminating FASTAPISCRIPT server (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 5
            if kill -0 "$pid" 2>/dev/null; then
                log_message "Force killing FASTAPISCRIPT server (PID: $pid)"
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
    log_message "Script finished with exit code: $exit_code"
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Function to check if virtual environment exists
check_venv() {
    if [ ! -d "$PYTHON_VENV" ]; then
        log_message "ERROR: Virtual environment not found at $PYTHON_VENV"
        log_message "Please create a virtual environment: python -m venv $PYTHON_VENV"
        exit 1
    fi
}

# Function to activate virtual environment
activate_venv() {
    source "$PYTHON_VENV/bin/activate"
    log_message "Activated virtual environment: $PYTHON_VENV"
}

# Function to check dependencies
check_dependencies() {
    if ! python -c "import fastapi, uvicorn" 2>/dev/null; then
        log_message "ERROR: Required dependencies not found"
        log_message "Please install: pip install fastapi uvicorn"
        exit 1
    fi
}

# Function to start FastAPI server
start_fastapiscript() {
    log_message "Starting FastAPI application: $FASTAPI_MODULE"
    log_message "Working directory: $FASTAPI_DIR"
    
    cd "$FASTAPI_DIR"
    
    # Start uvicorn server in background
    nohup python -m uvicorn "$FASTAPI_MODULE" \
        --host 0.0.0.0 \
        --port 8000 \
        --log-level info \
        --access-log \
        >> "$LOG_FILE" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$PID_FILE"
    log_message "FastAPI server started with PID: $pid"
    
    # Wait a moment and check if process is still running
    sleep 3
    if ! kill -0 "$pid" 2>/dev/null; then
        log_message "ERROR: FastAPI server failed to start"
        exit 1
    fi
    
    log_message "FastAPI server is running successfully"
}

# Function to wait for timeout or termination
wait_for_completion() {
    local pid=$(cat "$PID_FILE")
    local elapsed=0
    
    log_message "Waiting for completion (timeout: ${TIMEOUT}s)"
    
    while [ $elapsed -lt $TIMEOUT ] && kill -0 "$pid" 2>/dev/null; do
        sleep 10
        elapsed=$((elapsed + 10))
        
        # Log progress every 30 minutes
        if [ $((elapsed % 1800)) -eq 0 ]; then
            log_message "Still running... Elapsed: ${elapsed}s / ${TIMEOUT}s"
        fi
    done
    
    if kill -0 "$pid" 2>/dev/null; then
        log_message "Timeout reached (${TIMEOUT}s), stopping FastAPI server"
    else
        log_message "FastAPI server stopped naturally"
    fi
}

# Function to run health check
health_check() {
    local max_attempts=30
    local attempt=1
    
    log_message "Performing health check..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost:8000/health >/dev/null 2>&1; then
            log_message "Health check passed"
            return 0
        fi
        
        log_message "Health check attempt $attempt failed, retrying..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_message "WARNING: Health check failed after $max_attempts attempts"
    return 1
}

# Main execution
main() {
    log_message "=== FastAPI Runner Started ==="
    log_message "Configuration:"
    log_message "  FastAPI Directory: $FASTAPI_DIR"
    log_message "  Virtual Environment: $PYTHON_VENV"
    log_message "  Module: $FASTAPI_MODULE"
    log_message "  Timeout: ${TIMEOUT}s"
    
    # Check prerequisites
    check_venv
    activate_venv
    check_dependencies
    
    # Start FastAPI server
    start_fastapiscript
    
    # Optional health check (comment out if your app doesn't have /health endpoint)
    health_check
    
    # Wait for completion or timeout
    wait_for_completion
    
    log_message "=== FastAPI Runner Completed ==="
}

# Run main function
main "$@"