#!/usr/bin/env python3
"""
Advanced usage demo showing Python interop with Hy structured logging
"""

import hy
from hy_structured_logging import structured_logging as log
from hy_structured_logging import batteries
import time
import random
import threading
from concurrent.futures import ThreadPoolExecutor
import json

def demo_python_integration():
    """Show that the Hy logger works seamlessly from Python"""
    print("\n=== Python Integration Demo ===\n")
    
    log.init_logging(level="INFO", format="json")
    
    # Basic logging from Python
    log.info("Message from Python", {"language": "python", "version": "3.x"})
    
    # Using context manager
    with log.with_context({"component": "python_demo"}):
        log.info("Processing data", {"items": 100})
        log.warning("Memory usage high", {"memory_mb": 512})

def demo_concurrent_logging():
    """Demonstrate thread-safe logging"""
    print("\n=== Concurrent Logging Demo ===\n")
    
    def worker(worker_id):
        """Worker function for threading demo"""
        with log.with_context({"worker_id": worker_id}):
            for i in range(3):
                time.sleep(random.uniform(0.1, 0.3))
                log.info(f"Worker processing", {
                    "iteration": i,
                    "progress": (i + 1) / 3 * 100
                })
        return f"Worker {worker_id} completed"
    
    # Run multiple workers concurrently
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = [executor.submit(worker, i) for i in range(3)]
        results = [f.result() for f in futures]
        log.info("All workers completed", {"results": results})

def demo_performance_monitoring():
    """Show performance monitoring capabilities"""
    print("\n=== Performance Monitoring Demo ===\n")
    
    # Create a timer for the entire operation
    overall_timer = batteries.Timer("batch_processing")
    
    with overall_timer:
        for batch_id in range(3):
            batch_timer = batteries.Timer(f"batch_{batch_id}")
            
            with batch_timer:
                # Simulate processing
                time.sleep(random.uniform(0.2, 0.5))
                items_processed = random.randint(50, 150)
                
                log.info("Batch processed", {
                    "batch_id": batch_id,
                    "items": items_processed,
                    "duration_ms": batch_timer.elapsed() * 1000
                })
    
    log.info("Batch processing complete", {
        "total_duration_ms": overall_timer.elapsed() * 1000,
        "average_per_batch_ms": (overall_timer.elapsed() * 1000) / 3
    })

def demo_custom_fields():
    """Demonstrate custom field handling"""
    print("\n=== Custom Fields Demo ===\n")
    
    # Complex nested structures
    log.info("Complex data structure", {
        "user": {
            "id": "usr_123",
            "name": "Alice",
            "roles": ["admin", "developer"]
        },
        "request": {
            "method": "POST",
            "path": "/api/v1/users",
            "headers": {
                "content-type": "application/json",
                "authorization": "Bearer [REDACTED]"
            }
        },
        "metrics": {
            "response_time_ms": 45.7,
            "db_queries": 3,
            "cache_hits": 12,
            "cache_misses": 1
        }
    })

def demo_log_levels():
    """Show all log levels with appropriate use cases"""
    print("\n=== Log Levels Demo ===\n")
    
    log.init_logging(level="DEBUG", format="json")
    
    log.debug("Debug information", {
        "function": "demo_log_levels",
        "variables": {"x": 10, "y": 20}
    })
    
    log.info("Standard information", {
        "status": "operational",
        "uptime_hours": 72.5
    })
    
    log.warning("Warning condition", {
        "disk_usage_percent": 85,
        "threshold": 80
    })
    
    log.error("Error condition", {
        "error_type": "connection_timeout",
        "retry_count": 3,
        "max_retries": 3
    })
    
    log.critical("Critical system issue", {
        "subsystem": "database",
        "action": "emergency_shutdown",
        "reason": "data_corruption_detected"
    })

def main():
    """Run all advanced demos"""
    print("Hy Structured Logging - Advanced Python Demo")
    print("=" * 50)
    
    demo_python_integration()
    demo_concurrent_logging()
    demo_performance_monitoring()
    demo_custom_fields()
    demo_log_levels()
    
    print("\n" + "=" * 50)
    print("Advanced demo completed!")

if __name__ == "__main__":
    main()