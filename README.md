# Hy Structured Logging

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python Version](https://img.shields.io/badge/python-3.7%2B-blue)](https://www.python.org/downloads/)
[![Hy Version](https://img.shields.io/badge/hy-1.1.0%2B-green)](https://github.com/hylang/hy)

A comprehensive structured logging package for [Hy](https://github.com/hylang/hy) that provides JSON-formatted logging with support for contexts, child loggers, decorators, and more. Perfect for building observable, debuggable applications in Lisp on the Python platform.

## Features

- **Structured Output** - JSON and text format output support for easy parsing and analysis
- **Context Management** - Context-aware logging with nested contexts that propagate to child loggers
- **Hierarchical Loggers** - Create child loggers with inherited configuration and context
- **Function Decorators** - Automatic logging for function entry/exit and performance tracking
- **Request Tracking** - Built-in request ID generation and tracking across log entries
- **Flexible Configuration** - Configurable log levels, formats, and filtering
- **Thread-Safe** - Safe for use in concurrent and multi-threaded applications
- **AI Integration** - Claude subagent for intelligent log analysis and debugging assistance
- **Framework Integration** - Ready-to-use integrations for CherryPy and SQLObject
- **Performance Utilities** - Built-in Timer, retry mechanisms, and memoization helpers

## Installation

### From PyPI (when published)
```bash
pip install hy-structured-logging
```

### From Source
```bash
# Clone the repository
git clone https://github.com/jaymd96/hy-structured-logging.git
cd hy-structured-logging

# Install in development mode
pip install -e .

# Or build and install
python -m build
pip install dist/*.whl
```

## Quick Start

### Basic Usage (Hy)

```hy
(import hy-structured-logging.structured-logging :as log)

;; Initialize logging
(log.init-logging :level "INFO" :format "json")

;; Log messages with structured data
(log.info "User logged in" {"user_id" "123" "ip" "192.168.1.1"})
(log.warning "High memory usage" {"percent" 85 "threshold" 80})
(log.error "Database connection failed" {"retry_count" 3 "error" "timeout"})
```

### Python Integration

The package works seamlessly from Python:

```python
import hy
from hy_structured_logging import structured_logging as log

# Initialize and use just like from Hy
log.init_logging(level="INFO", format="json")

log.info("Processing started", {"items": 100, "batch_id": "abc123"})

with log.with_context({"request_id": "req-001"}):
    log.info("Handling request", {"endpoint": "/api/users"})
```

### Context Management

```hy
;; Add persistent context that applies to all subsequent logs
(log.with-context {"service" "api" "version" "1.0.0"}
  (log.info "Service started" {})
  
  ;; Nested contexts
  (log.with-context {"request_id" "req-123"}
    (log.info "Processing request" {"method" "GET"})
    (log.info "Request completed" {"status" 200})))
```

### Using the Batteries Module

```hy
(import hy-structured-logging.batteries :as batteries)

;; Timer for performance tracking
(let [timer (batteries.Timer "data-processing")]
  (with [t timer]
    ;; Your code here
    (process-data))
  (log.info "Processing complete" {"duration_ms" (* (.elapsed timer) 1000)}))

;; Retry mechanism
(batteries.with-retry 
  (fn [] (fetch-data-from-api))
  :max-attempts 3
  :delay 1.0)

;; Memoization
(setv cached-fn (batteries.memoize expensive-calculation))
```

## Advanced Features

### Child Loggers

Create specialized loggers for different components:

```hy
(setv db-logger (log.get-child-logger "database"))
(setv api-logger (log.get-child-logger "api"))

(.info db-logger "Query executed" {"query" "SELECT * FROM users" "rows" 42})
(.info api-logger "Request received" {"endpoint" "/users" "method" "GET"})
```

### Function Decorators

Automatically log function calls:

```hy
(import hy-structured-logging.structured-logging [log-execution])

(defn [log-execution] process-payment [amount user-id]
  ;; Function automatically logs entry and exit
  (charge-card amount user-id))
```

### AI-Powered Analysis

Use the Claude subagent for intelligent log analysis:

```hy
(import hy-structured-logging.claude-subagent :as subagent)

;; Analyze logs for patterns
(subagent.analyze-logs "/var/log/app.log" 
  :pattern "error"
  :time-range "1h")

;; Get debugging suggestions
(subagent.suggest-fix "Database connection timeout errors")
```

## Demo Scripts

Explore the `demo/` directory for comprehensive examples:

- `demo/basic_usage.hy` - Core features demonstration in Hy
- `demo/advanced_usage.py` - Advanced Python integration examples

Run demos:
```bash
hy demo/basic_usage.hy
python demo/advanced_usage.py
```

## Development

### Task Runner

The project includes a [PyDoit](https://pydoit.org/) task runner written in Hy:

```bash
# List all available tasks
hy dodo.hy list

# Run tests
hy dodo.hy test

# Build distribution packages
hy dodo.hy build

# Run demos
hy dodo.hy demo

# Upload to PyPI (when ready)
hy dodo.hy upload
```

### Running Tests

```bash
# Run all tests
hy test_structured_logging.hy
hy test_claude_subagent.hy

# Or use the task runner
hy dodo.hy test
```

## Project Structure

```
hy-structured-logging/
├── hy_structured_logging/       # Main package
│   ├── __init__.hy
│   ├── structured_logging.hy    # Core logging functionality
│   ├── structured_logging_config.hy  # Configuration management
│   ├── batteries.hy            # Utility functions and helpers
│   ├── claude_subagent.hy      # AI integration
│   └── integrations/           # Framework integrations
│       ├── cherrypy.hy
│       └── sqlobject.hy
├── demo/                       # Demo scripts
│   ├── basic_usage.hy
│   └── advanced_usage.py
├── test_*.hy                   # Test files
├── dodo.hy                     # Task runner
└── pyproject.toml             # Package configuration
```

## Configuration

### Log Levels
- `DEBUG` - Detailed diagnostic information
- `INFO` - General informational messages
- `WARNING` - Warning messages for potential issues
- `ERROR` - Error messages for failures
- `CRITICAL` - Critical issues requiring immediate attention

### Output Formats
- `json` - Structured JSON output (recommended for production)
- `text` - Human-readable text format (useful for development)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Hy](https://github.com/hylang/hy) - A Lisp dialect embedded in Python
- Inspired by structured logging best practices from the Python ecosystem
- AI integration powered by Claude

## Support

For issues, questions, or suggestions, please [open an issue](https://github.com/jaymd96/hy-structured-logging/issues) on GitHub.

## Author

**Jay MD** - [jaymd96](https://github.com/jaymd96)

---

Made with ❤️ and Lisp