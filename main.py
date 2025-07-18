# Sample FastAPI Application (main.py)
# This is a basic FastAPI app that demonstrates what your application might look like

import asyncio
import logging
import sys
from datetime import datetime

import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("/var/log/fastapi-runner/app.log"),
        logging.StreamHandler(sys.stdout),
    ],
)

logger = logging.getLogger(__name__)

# Create FastAPI instance
app = FastAPI(
    title="Scheduled FASTAPISCRIPT Runner",
    description="FASTAPISCRIPT designed to run every 2 hours",
    version="1.0.0",
)


# Pydantic models
class TaskResult(BaseModel):
    task_id: str
    status: str
    message: str
    timestamp: datetime
    duration_seconds: float


class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    uptime_seconds: float


# Global variables
start_time = datetime.now()
task_results = []


@app.on_event("startup")
async def startup_event():
    """Run when the application starts"""
    logger.info("FASTAPISCRIPT application starting up")
    logger.info(f"Application started at: {start_time}")


@app.on_event("shutdown")
async def shutdown_event():
    """Run when the application shuts down"""
    logger.info("FASTAPISCRIPT application shutting down")
    uptime = (datetime.now() - start_time).total_seconds()
    logger.info(f"Total uptime: {uptime:.2f} seconds")


@app.get("/", response_model=dict)
async def root():
    """Root endpoint"""
    return {
        "message": "FASTAPISCRIPT Scheduled Runner",
        "status": "running",
        "start_time": start_time,
        "uptime_seconds": (datetime.now() - start_time).total_seconds(),
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    uptime = (datetime.now() - start_time).total_seconds()
    return HealthResponse(
        status="healthy", timestamp=datetime.now(), uptime_seconds=uptime
    )


@app.post("/run-task", response_model=TaskResult)
async def run_main_task():
    """Main task endpoint - this is where your automation logic goes"""
    task_id = f"task_{len(task_results) + 1}"
    task_start = datetime.now()

    logger.info(f"Starting task: {task_id}")

    try:
        # Your automation logic goes here
        # This is just a sample - replace with your actual work

        await simulate_work()

        # Calculate duration
        duration = (datetime.now() - task_start).total_seconds()

        result = TaskResult(
            task_id=task_id,
            status="completed",
            message="Task completed successfully",
            timestamp=datetime.now(),
            duration_seconds=duration,
        )

        task_results.append(result)
        logger.info(f"Task {task_id} completed successfully in {duration:.2f} seconds")

        return result

    except Exception as e:
        duration = (datetime.now() - task_start).total_seconds()
        error_result = TaskResult(
            task_id=task_id,
            status="failed",
            message=f"Task failed: {str(e)}",
            timestamp=datetime.now(),
            duration_seconds=duration,
        )

        task_results.append(error_result)
        logger.error(f"Task {task_id} failed: {str(e)}")

        raise HTTPException(status_code=500, detail=f"Task failed: {str(e)}")


@app.get("/tasks", response_model=list[TaskResult])
async def get_task_history():
    """Get task execution history"""
    return task_results


@app.get("/tasks/{task_id}", response_model=TaskResult)
async def get_task_result(task_id: str):
    """Get specific task result"""
    for result in task_results:
        if result.task_id == task_id:
            return result

    raise HTTPException(status_code=404, detail="Task not found")


async def simulate_work():
    """
    Simulate some work being done
    Replace this with your actual automation logic
    """
    logger.info("Performing automation work...")

    # Simulate different types of work
    tasks = [
        ("Database cleanup", 2),
        ("Data processing", 5),
        ("Report generation", 3),
        ("Email notifications", 1),
        ("File maintenance", 2),
    ]

    for task_name, duration in tasks:
        logger.info(f"Executing: {task_name}")
        await asyncio.sleep(duration)  # Simulate work
        logger.info(f"Completed: {task_name}")

    logger.info("All automation work completed")


# Auto-run task when started (for scheduled execution)
@app.on_event("startup")
async def auto_run_task():
    """Automatically run the main task when the app starts"""
    # Wait a moment for the app to fully initialize
    await asyncio.sleep(2)

    try:
        logger.info("Auto-executing main task")
        # Call the task function directly
        await run_main_task()

        # Optionally shutdown after task completion
        # This is useful for scheduled runs
        logger.info("Main task completed, scheduling shutdown...")
        await asyncio.sleep(5)  # Give time for logs to flush

        # Graceful shutdown
        import os
        import signal

        os.kill(os.getpid(), signal.SIGTERM)

    except Exception as e:
        logger.error(f"Auto-task execution failed: {str(e)}")
        # Exit with error code
        sys.exit(1)


if __name__ == "__main__":
    # This allows running the script directly for testing
    uvicorn.run(
        "main:app", host="0.0.0.0", port=8000, log_level="info", access_log=True
    )
