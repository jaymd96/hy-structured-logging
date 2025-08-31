# Hy Structured Logging Demos

This directory contains demonstration scripts showing how to use the hy-structured-logging package.

## Files

- `basic_usage.hy` - Basic Hy examples showing core logging features
- `advanced_usage.py` - Advanced Python examples showing interop and concurrent logging

## Running the Demos

### Basic Hy Demo
```bash
hy demo/basic_usage.hy
```

### Advanced Python Demo
```bash
python3 demo/advanced_usage.py
```

## Features Demonstrated

### Basic Usage (Hy)
- Simple logging at different levels
- Context-based logging
- Timer utilities from batteries module
- Error handling and logging
- Different output formats (JSON/text)

### Advanced Usage (Python)
- Python/Hy interoperability
- Thread-safe concurrent logging
- Performance monitoring
- Complex nested data structures
- All log levels with use cases

## Example Output

JSON formatted log entry:
```json
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "level": "INFO",
  "message": "User logged in",
  "user_id": "12345",
  "session": "abc-def-ghi",
  "ip": "192.168.1.1"
}
```