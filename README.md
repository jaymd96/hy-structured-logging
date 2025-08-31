# Hy Structured Logging

A comprehensive structured logging package for Hy (Hylang) that provides JSON-formatted logging with support for contexts, child loggers, decorators, and more.

## Features

- **JSON-formatted output**: All log entries are output as JSON for easy parsing and analysis
- **Hierarchical loggers**: Create child loggers with inherited configuration
- **Context management**: Add persistent or temporary context fields to log entries
- **Log levels**: Standard log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- **Decorators**: Automatic logging of function execution and errors
- **Exception handling**: Structured exception information with stack traces
- **Factory pattern**: Centralized logger management with global configuration
- **Performance tracking**: Built-in support for timing and performance metrics
- **Claude Code Integration**: Specialized AI subagent for logging expertise and assistance

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd hy-structured-logging

# Install Hy if not already installed
pip install hy

# Run tests
hy test_structured_logging.hy

# Run examples
hy example.hy

# Install Claude Code subagent (optional, for Claude Code users)
hy install_subagent.hy
```

## Quick Start

```hy
(import structured_logging [get-logger])

;; Get a logger
(setv logger (get-logger "myapp"))

;; Log messages with structured data
(.info logger "User action" :user_id 123 :action "login" :ip "192.168.1.1")
(.error logger "Database error" :query "SELECT * FROM users" :error_code 500)
```

## Core Components

### StructuredLogger

The main logger class that outputs JSON-formatted log entries.

```hy
(import structured_logging [StructuredLogger])

;; Create a logger with default fields
(setv logger (StructuredLogger "app" 
                                :level "INFO"
                                :default-fields {"service" "api" "version" "1.0"}))

;; Log messages
(.debug logger "Debug info" :detail "verbose")
(.info logger "Request received" :method "GET" :path "/users")
(.warning logger "High memory usage" :percent 85)
(.error logger "Connection failed" :host "db.example.com")
(.critical logger "System failure" :component "auth")
```

### Context Management

Add context fields that persist across multiple log entries:

```hy
;; Add persistent context
(.with-context logger :request_id "req-123" :user_id 456)

;; These fields will be included in all subsequent logs
(.info logger "Processing started")
(.info logger "Processing complete")

;; Clear context when done
(.clear-context logger)
```

Use temporary context with the context manager:

```hy
(import structured_logging [with-context])

;; Temporary context for a block of code
(with [(with-context logger :operation "database_sync")]
  (.info logger "Sync started")
  (.info logger "Sync completed" :records_processed 1000))
;; Context automatically reverted after the block
```

### Child Loggers

Create child loggers that inherit configuration and add their own fields:

```hy
(setv parent-logger (get-logger "app"))
(setv auth-logger (.child parent-logger "auth" :module "authentication"))
(setv db-logger (.child parent-logger "db" :module "database"))

;; Each child logger has its own name and fields
(.info auth-logger "User authenticated")  ; logger="app.auth", module="authentication"
(.info db-logger "Query executed")        ; logger="app.db", module="database"
```

### LoggerFactory

Manage multiple loggers with shared configuration:

```hy
(import structured_logging [LoggerFactory])

;; Create a factory with global fields
(setv factory (LoggerFactory :default-level "INFO"
                              :global-fields {"environment" "production"
                                              "region" "us-west"}))

;; Get loggers from the factory
(setv api-logger (.get-logger factory "api"))
(setv worker-logger (.get-logger factory "worker"))

;; Set level for all loggers
(.set-global-level factory "DEBUG")
```

### Decorators

#### Log Execution

Automatically log function entry, exit, and duration:

```hy
(import structured_logging [log-execution get-logger])

(setv logger (get-logger "app"))

(with-decorator (log-execution logger :include-args True :include-result True)
  (defn process-data [data]
    ;; Function implementation
    (len data)))

;; Calling the function will automatically log:
;; - Function entry with arguments
;; - Function exit with result and duration
(process-data [1 2 3])
```

#### Log Errors

Automatically log exceptions:

```hy
(import structured_logging [log-errors])

(with-decorator (log-errors logger)
  (defn risky-operation []
    ;; This will automatically log any exceptions
    (/ 1 0)))
```

## Claude Code AI Assistant Integration

This package includes a specialized Claude Code subagent that provides expert assistance with structured logging. When installed, the subagent automatically activates for logging-related questions and provides:

- Expert guidance on the hy-structured-logging package API
- Best practices for structured logging patterns
- Debugging assistance for logging issues
- Performance optimization recommendations
- Integration examples with various frameworks

### Installing the Subagent

If you're using Claude Code, you can install the specialized logging expert:

```bash
# Quick installation
hy install_subagent.hy

# Or manually via the module
hy -c "(import claude_subagent [install-subagent]) (install-subagent)"

# Check installation status
hy -c "(import claude_subagent [check-subagent-status]) (print (check-subagent-status))"
```

Once installed, the subagent will:
- Automatically activate when you ask about logging in Hy
- Provide contextual help based on your code
- Suggest improvements to your logging implementation
- Help debug logging-related issues

You can explicitly invoke it with: "Ask the structured-logging-expert about..."

### Subagent Module API

The `claude_subagent` module provides programmatic control:

```hy
(import claude_subagent [install-subagent uninstall-subagent check-subagent-status])

;; Install the subagent
(install-subagent)  ; Install in current project
(install-subagent "/path/to/project")  ; Install in specific project
(install-subagent "." True)  ; Force reinstall

;; Check status
(setv status (check-subagent-status))
(print (get status "installed"))  ; True/False
(print (get status "path"))  ; Path to subagent file

;; Uninstall
(uninstall-subagent)
```

## Advanced Usage

### Exception Logging

Exceptions are automatically formatted with full details:

```hy
(try
  (some-operation)
  (except [e Exception]
    (.error logger "Operation failed" :exception e :retry_count 3)))
;; Logs will include error_type, error_message, and stacktrace
```

### Performance Monitoring

Track operation performance:

```hy
(import time)

(defn monitor-operation [logger name func]
  (setv start (time.time))
  (try
    (setv result (func))
    (setv duration-ms (* (- (time.time) start) 1000))
    (.info logger f"Operation: {name}"
           :operation name
           :duration_ms duration-ms
           :status "success")
    result
    (except [e Exception]
      (setv duration-ms (* (- (time.time) start) 1000))
      (.error logger f"Operation failed: {name}"
              :operation name
              :duration_ms duration-ms
              :status "error"
              :exception e)
      (raise))))
```

### Custom Output Streams

Direct logs to different outputs:

```hy
(import sys)
(import io [StringIO])

;; Log to stderr
(setv error-logger (StructuredLogger "errors" :output sys.stderr))

;; Log to a string buffer
(setv buffer (StringIO))
(setv test-logger (StructuredLogger "test" :output buffer))

;; Get logged content
(setv log-content (.getvalue buffer))
```

## Log Entry Format

Each log entry is a JSON object with the following structure:

```json
{
  "timestamp": "2024-01-01T12:00:00.000000",
  "level": "INFO",
  "logger": "app.module",
  "message": "User action completed",
  "user_id": 123,
  "action": "login",
  "duration_ms": 45.2,
  "custom_field": "value"
}
```

For exceptions:

```json
{
  "timestamp": "2024-01-01T12:00:00.000000",
  "level": "ERROR",
  "logger": "app",
  "message": "Operation failed",
  "error_type": "ValueError",
  "error_message": "Invalid input",
  "stacktrace": ["Traceback...", "..."],
  "context_field": "value"
}
```

## Best Practices

1. **Use structured fields**: Instead of embedding data in messages, use fields:
   ```hy
   ;; Good
   (.info logger "User login" :user_id 123 :ip "192.168.1.1")
   
   ;; Avoid
   (.info logger "User 123 logged in from 192.168.1.1")
   ```

2. **Create domain-specific loggers**: Use child loggers for different components:
   ```hy
   (setv auth-logger (.child app-logger "auth"))
   (setv db-logger (.child app-logger "db"))
   (setv api-logger (.child app-logger "api"))
   ```

3. **Add request context**: For web applications, add request context:
   ```hy
   (with [(with-context logger :request_id request-id :user_id user-id)]
     ;; All logs in this block will have request context
     (handle-request))
   ```

4. **Use appropriate log levels**:
   - DEBUG: Detailed diagnostic information
   - INFO: General informational messages
   - WARNING: Warning messages for potentially harmful situations
   - ERROR: Error events that might still allow the application to continue
   - CRITICAL: Serious errors that might cause the application to abort

5. **Include relevant metadata**: Add fields that will help with debugging and analysis:
   ```hy
   (.error logger "API call failed"
           :endpoint "/api/users"
           :method "POST"
           :status_code 500
           :retry_count 3
           :latency_ms 1200)
   ```

## Testing

Run the test suite:

```bash
hy test_structured_logging.hy
```

The test suite covers:
- Basic logging functionality
- Log level filtering
- Context management
- Child loggers
- Exception logging
- Decorators
- Factory pattern
- Utility functions

## Examples

See `example.hy` for comprehensive examples covering:
- Basic logging
- Context management
- Child loggers
- Error handling
- Function execution logging
- Factory usage
- Performance monitoring
- Structured data logging

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
