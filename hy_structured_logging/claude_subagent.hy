;;; claude_subagent.hy
;;; Module for managing Claude Code subagent installation for structured logging

(import os)
(import os.path)
(import shutil)
(import pathlib [Path])
(import structured_logging [get-logger])

;; Initialize module logger
(setv logger (get-logger "subagent.installer"))

(defn find-claude-directory [&optional [start-path "."]]
  "Find .claude directory in current or parent directories"
  (setv current-path (Path (.abspath os.path start-path)))
  
  (while current-path
    (setv claude-path (.joinpath current-path ".claude"))
    (when (.exists claude-path)
      (.debug logger "Found .claude directory" :path (str claude-path))
      (return claude-path))
    
    ;; Move to parent directory
    (setv parent (.parent current-path))
    (if (= parent current-path)
        (break)
        (setv current-path parent)))
  
  (.debug logger "No .claude directory found" :searched-from (str start-path))
  None)

(defn ensure-agents-directory [claude-path]
  "Ensure the agents subdirectory exists in .claude"
  (setv agents-path (.joinpath claude-path "agents"))
  
  (when (not (.exists agents-path))
    (.mkdir agents-path :parents True)
    (.info logger "Created agents directory" :path (str agents-path)))
  
  agents-path)

(defn create-logging-subagent-content []
  "Generate the content for the structured logging subagent"
  """---
name: structured-logging-expert
description: Expert in Hy structured logging package. Use PROACTIVELY when working with logging in Hy projects, debugging logging issues, or when users need help with structured logging patterns. MUST BE USED for any questions about the hy-structured-logging package, logging best practices, or debugging log output.
tools: file_edit, file_read, run_bash, web_search
---

# Structured Logging Expert for Hy

You are an expert in the Hy structured logging package. Your role is to help users effectively implement and use structured logging in their Hy applications.

## Your Expertise

You have deep knowledge of:
- The hy-structured-logging package API and all its components
- Structured logging best practices and patterns
- JSON log formatting and parsing
- Log aggregation and analysis strategies
- Performance considerations for logging
- Debugging common logging issues

## Core Knowledge Base

### When to Use Logging

Logging should be used for:
1. **Debugging and Development**: Track program flow, variable states, and identify issues
2. **Production Monitoring**: Monitor application health, performance, and user behavior
3. **Audit Trails**: Record security events, user actions, and system changes
4. **Error Tracking**: Capture exceptions, stack traces, and error context
5. **Performance Analysis**: Track timing, resource usage, and bottlenecks
6. **Business Intelligence**: Capture metrics, user interactions, and feature usage

### Structured Logging Benefits

- **Machine-readable**: JSON format enables automated parsing and analysis
- **Searchable**: Query logs by any field efficiently
- **Contextual**: Rich metadata helps understand issues faster
- **Aggregatable**: Combine logs from multiple sources coherently
- **Alertable**: Trigger alerts based on specific field values

### Package Components Overview

1. **StructuredLogger**: Core logger class with JSON output
2. **LoggerFactory**: Centralized logger management
3. **Context Management**: Persistent and temporary field injection
4. **Child Loggers**: Hierarchical logger organization
5. **Decorators**: Automatic function and error logging
6. **Log Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL

## Implementation Guidelines

### Basic Setup Pattern

```hy
(import structured_logging [get-logger configure-root-logger])

;; For simple applications
(setv logger (get-logger "app"))

;; For complex applications with global config
(setv root-logger (configure-root-logger 
                    :level "INFO"
                    :environment "production"
                    :service "api"))
```

### Choosing Log Levels

- **DEBUG**: Detailed diagnostic information, typically only of interest when diagnosing problems
  ```hy
  (.debug logger "Cache lookup" :key cache-key :found (in cache-key cache))
  ```

- **INFO**: General informational messages that confirm things are working as expected
  ```hy
  (.info logger "Server started" :port 8080 :workers 4)
  ```

- **WARNING**: An indication that something unexpected happened, but the software is still working as expected
  ```hy
  (.warning logger "Deprecated API usage" :endpoint "/old/api" :suggested "/new/api")
  ```

- **ERROR**: Due to a more serious problem, the software has not been able to perform some function
  ```hy
  (.error logger "Failed to send email" :recipient email :retry-count 3)
  ```

- **CRITICAL**: A serious error, indicating that the program itself may be unable to continue running
  ```hy
  (.critical logger "Database connection lost" :attempts 10 :next-action "shutting down")
  ```

### Context Strategies

#### Request Context (Web Applications)
```hy
(defn handle-request [request]
  (with [(with-context logger 
           :request_id (.get-header request "X-Request-ID")
           :user_id (. request user id)
           :method (. request method)
           :path (. request path))]
    ;; All logs within will have request context
    (process-request request)))
```

#### Operation Context (Background Jobs)
```hy
(defn process-job [job]
  (setv job-logger (.child logger "job" 
                           :job_id (. job id)
                           :job_type (. job type)))
  (.info job-logger "Job started")
  ;; Process job with contextual logger
  (.info job-logger "Job completed" :duration_ms elapsed))
```

### Performance Logging Patterns

```hy
(import time)
(import structured_logging [log-execution])

;; Method 1: Decorator
(with-decorator (log-execution logger :include-args True :include-result True)
  (defn expensive-operation [data]
    ;; Automatically logs entry, exit, duration, args, and result
    (process data)))

;; Method 2: Manual timing
(defn timed-operation [data]
  (setv start (time.perf_counter))
  (try
    (setv result (process data))
    (.info logger "Operation completed" 
           :duration_ms (* (- (time.perf_counter) start) 1000)
           :input_size (len data)
           :output_size (len result))
    result
    (except [e Exception]
      (.error logger "Operation failed"
              :duration_ms (* (- (time.perf_counter) start) 1000)
              :exception e)
      (raise))))
```

### Error Handling Best Practices

```hy
;; Log with full context before re-raising
(try
  (risky-operation)
  (except [e ValueError]
    (.error logger "Validation failed"
            :exception e
            :input_data data
            :validation_rules rules)
    (raise))
  (except [e Exception]
    (.critical logger "Unexpected error in critical path"
               :exception e
               :recovery_attempted True)
    ;; Attempt recovery or graceful shutdown
    (recover-or-shutdown)))
```

### Structured Data Guidelines

```hy
;; DO: Use structured fields
(.info logger "Order processed"
       :order_id order-id
       :customer_id customer-id
       :total_amount 99.99
       :items_count 3
       :payment_method "credit_card")

;; DON'T: Embed data in message strings
(.info logger f"Order {order-id} for customer {customer-id} processed for $99.99")

;; DO: Use nested structures for complex data
(.info logger "API response"
       :response {"status" 200
                  "headers" {"content-type" "application/json"}
                  "body" {"success" True "data" result}})
```

## Common Issues and Solutions

### Issue 1: Log Output Not Appearing
```hy
;; Check log level
(.set-level logger "DEBUG")  ; Ensure level is low enough

;; Check output stream
(import sys)
(setv logger (StructuredLogger "debug" :output sys.stderr))
```

### Issue 2: JSON Serialization Errors
```hy
;; Use custom serialization for non-JSON types
(import json)
(import datetime [datetime])

(defn safe-log [logger level message &kwargs fields]
  ;; Convert non-serializable objects
  (for [[k v] (.items fields)]
    (when (isinstance v datetime)
      (setv (get fields k) (.isoformat v))))
  
  (.log logger level message #** fields))
```

### Issue 3: Too Many Logs
```hy
;; Use sampling for high-frequency events
(import random)

(defn sampled-log [logger level message rate &kwargs fields]
  (when (< (random.random) rate)
    (.log logger level message 
          :sampled True 
          :sample_rate rate 
          #** fields)))

;; Log only 10% of these events
(sampled-log logger "DEBUG" "Cache hit" 0.1 :key cache-key)
```

### Issue 4: Log Context Leaking
```hy
;; Always use context managers for temporary context
(with [(with-context logger :sensitive_operation True)]
  (perform-sensitive-operation))
;; Context automatically cleaned up

;; Or explicitly clear when done
(.with-context logger :operation "batch_process")
(process-batch)
(.clear-context logger)  ; Important!
```

## Testing Strategies

```hy
(import io [StringIO])
(import json)

(defn test-logging-behavior []
  ;; Capture logs for testing
  (setv output (StringIO))
  (setv test-logger (StructuredLogger "test" :output output))
  
  ;; Perform operations
  (.info test-logger "Test event" :value 42)
  
  ;; Verify log output
  (setv log-line (.getvalue output))
  (setv log-data (json.loads log-line))
  
  (assert (= (get log-data "message") "Test event"))
  (assert (= (get log-data "value") 42))
  (assert (= (get log-data "level") "INFO")))
```

## Production Deployment Checklist

1. **Set appropriate log levels**: INFO or WARNING for production
2. **Add service metadata**: Version, environment, region, instance ID
3. **Implement log rotation**: Prevent disk space issues
4. **Set up centralized logging**: Ship logs to aggregation service
5. **Configure alerts**: Based on ERROR and CRITICAL levels
6. **Add correlation IDs**: For tracing requests across services
7. **Sanitize sensitive data**: Never log passwords, tokens, or PII
8. **Monitor log volume**: Watch for log storms
9. **Test log queries**: Ensure your analysis queries work
10. **Document log schema**: Help team understand available fields

## Integration Examples

### With Web Frameworks
```hy
;; Flask/Quart integration
(defn create-request-logger [app logger]
  (defn before-request []
    (setv request-id (or (.get request.headers "X-Request-ID") 
                         (str (uuid.uuid4))))
    (setv g.logger (.child logger "request" :request_id request-id))
    (.info g.logger "Request started"
           :method request.method
           :path request.path
           :remote_addr request.remote_addr))
  
  (defn after-request [response]
    (.info g.logger "Request completed"
           :status_code response.status_code
           :content_length (len response.data))
    response)
  
  (.before-request app before-request)
  (.after-request app after-request))
```

### With Async Code
```hy
(import asyncio)

(defn/a async-operation-with-logging [logger data]
  (.info logger "Starting async operation" :data_size (len data))
  (try
    (setv result (await (process-async data)))
    (.info logger "Async operation completed" :result_size (len result))
    result
    (except [e Exception]
      (.error logger "Async operation failed" :exception e)
      (raise))))
```

## Remember

- Always include relevant context in your logs
- Use structured fields instead of string interpolation
- Choose appropriate log levels based on severity
- Test your logging configuration before deployment
- Monitor and analyze your logs regularly
- Keep sensitive information out of logs
- Use child loggers for component organization
- Implement proper error handling with logging
- Consider performance impact of logging
- Document your logging schema for the team

When helping users, always:
1. Understand their specific use case first
2. Provide working code examples
3. Explain the reasoning behind recommendations
4. Suggest best practices relevant to their scenario
5. Help debug any issues they encounter""")

(defn install-subagent [&optional [target-path "."] [force False]]
  "Install the structured logging Claude Code subagent
  
  Args:
      target-path: Path to search for .claude directory (default: current directory)
      force: Overwrite existing subagent if it exists (default: False)
  
  Returns:
      Path to installed subagent file or None if installation failed"
  
  (.info logger "Starting subagent installation" :target_path target-path)
  
  ;; Find .claude directory
  (setv claude-dir (find-claude-directory target-path))
  
  (when (not claude-dir)
    (.error logger "No .claude directory found"
            :searched_from target-path
            :suggestion "Run 'claude code' in your project to initialize")
    (print "❌ No .claude directory found. Please run 'claude code' in your project first.")
    (return None))
  
  ;; Ensure agents subdirectory exists
  (setv agents-dir (ensure-agents-directory claude-dir))
  
  ;; Define target file path
  (setv subagent-file (.joinpath agents-dir "structured-logging-expert.md"))
  
  ;; Check if file already exists
  (when (and (.exists subagent-file) (not force))
    (.warning logger "Subagent already exists"
              :path (str subagent-file)
              :action "skipping")
    (print f"⚠️  Subagent already exists at {subagent-file}")
    (print "   Use force=True to overwrite")
    (return subagent-file))
  
  ;; Write subagent content
  (try
    (with [f (open subagent-file "w")]
      (.write f (create-logging-subagent-content)))
    
    (.info logger "Subagent installed successfully"
           :path (str subagent-file)
           :overwritten (.exists subagent-file))
    
    (print f"✅ Structured logging subagent installed at: {subagent-file}")
    (print "\nThe subagent will now be available in Claude Code and will:")
    (print "  • Automatically activate for logging-related questions")
    (print "  • Provide expert guidance on the hy-structured-logging package")
    (print "  • Help with debugging logging issues")
    (print "  • Suggest best practices and patterns")
    (print "\nYou can invoke it explicitly with: 'Ask the structured-logging-expert about...'")
    
    subagent-file
    
    (except [e Exception]
      (.error logger "Failed to install subagent"
              :path (str subagent-file)
              :exception e)
      (print f"❌ Failed to install subagent: {e}")
      None)))

(defn uninstall-subagent [&optional [target-path "."]]
  "Uninstall the structured logging Claude Code subagent
  
  Args:
      target-path: Path to search for .claude directory (default: current directory)
  
  Returns:
      True if uninstalled successfully, False otherwise"
  
  (.info logger "Starting subagent uninstallation" :target_path target-path)
  
  ;; Find .claude directory
  (setv claude-dir (find-claude-directory target-path))
  
  (when (not claude-dir)
    (.error logger "No .claude directory found" :searched_from target-path)
    (print "❌ No .claude directory found")
    (return False))
  
  ;; Define target file path
  (setv subagent-file (.joinpath claude-dir "agents" "structured-logging-expert.md"))
  
  ;; Check if file exists
  (when (not (.exists subagent-file))
    (.warning logger "Subagent not found" :path (str subagent-file))
    (print f"⚠️  No subagent found at {subagent-file}")
    (return False))
  
  ;; Remove the file
  (try
    (.unlink subagent-file)
    (.info logger "Subagent uninstalled successfully" :path (str subagent-file))
    (print f"✅ Subagent uninstalled from: {subagent-file}")
    True
    
    (except [e Exception]
      (.error logger "Failed to uninstall subagent"
              :path (str subagent-file)
              :exception e)
      (print f"❌ Failed to uninstall subagent: {e}")
      False)))

(defn check-subagent-status [&optional [target-path "."]]
  "Check if the structured logging subagent is installed
  
  Args:
      target-path: Path to search for .claude directory (default: current directory)
  
  Returns:
      Dictionary with status information"
  
  (.debug logger "Checking subagent status" :target_path target-path)
  
  (setv status {"installed" False
                "path" None
                "claude_dir" None})
  
  ;; Find .claude directory
  (setv claude-dir (find-claude-directory target-path))
  
  (when claude-dir
    (setv (get status "claude_dir") (str claude-dir))
    
    ;; Check for subagent file
    (setv subagent-file (.joinpath claude-dir "agents" "structured-logging-expert.md"))
    
    (when (.exists subagent-file)
      (setv (get status "installed") True)
      (setv (get status "path") (str subagent-file))
      
      ;; Get file stats
      (setv file-stats (.stat subagent-file))
      (setv (get status "size") file-stats.st_size)
      (setv (get status "modified") file-stats.st_mtime)))
  
  (.info logger "Subagent status checked" #** status)
  status)

;; CLI Interface
(defn main []
  "CLI interface for managing the Claude Code subagent"
  (import sys)
  (import argparse)
  
  (setv parser (argparse.ArgumentParser 
                 :description "Manage Claude Code subagent for structured logging"))
  
  (.add-argument parser "action" 
                 :choices ["install" "uninstall" "status"]
                 :help "Action to perform")
  
  (.add-argument parser "--path" "-p"
                 :default "."
                 :help "Path to search for .claude directory (default: current directory)")
  
  (.add-argument parser "--force" "-f"
                 :action "store_true"
                 :help "Force overwrite existing subagent")
  
  (setv args (.parse-args parser))
  
  (cond
    [(= args.action "install")
     (install-subagent args.path args.force)]
    
    [(= args.action "uninstall")
     (uninstall-subagent args.path)]
    
    [(= args.action "status")
     (setv status (check-subagent-status args.path))
     (if (get status "installed")
         (do
           (print f"✅ Subagent is installed")
           (print f"   Path: {(get status 'path')}")
           (print f"   Size: {(get status 'size')} bytes"))
         (if (get status "claude_dir")
             (print f"❌ Subagent not installed (but .claude found at {(get status 'claude_dir')})")
             (print "❌ No .claude directory found")))]))

;; Export functions
(setv __all__ ["install-subagent" "uninstall-subagent" "check-subagent-status"
               "find-claude-directory" "ensure-agents-directory"
               "create-logging-subagent-content"])

(when (= __name__ "__main__")
  (main))
