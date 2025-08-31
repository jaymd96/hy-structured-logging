;;; example.hy
;;; Example usage of the structured logging package

(import structured_logging [get-logger StructuredLogger LoggerFactory 
                            log-execution log-errors with-context configure-root-logger])
(import claude_subagent [check-subagent-status install-subagent])
(import time)
(import random)

;; Example 1: Basic logging
(defn basic-example []
  (print "\n=== Basic Logging Example ===")
  (setv logger (get-logger "app.basic"))
  
  (.debug logger "Debug message" :user_id 123 :action "login")
  (.info logger "User logged in successfully" :user_id 123 :ip_address "192.168.1.1")
  (.warning logger "Rate limit approaching" :requests_made 95 :limit 100)
  (.error logger "Failed to connect to database" :host "db.example.com" :port 5432))

;; Example 2: Using context
(defn context-example []
  (print "\n=== Context Example ===")
  (setv logger (get-logger "app.context"))
  
  ;; Add persistent context
  (.with-context logger :request_id "req-12345" :user_id 456)
  
  (.info logger "Processing request")
  (.info logger "Fetching user data")
  
  ;; Use temporary context
  (with [(with-context logger :operation "database_query")]
    (.info logger "Executing query")
    (.info logger "Query completed" :rows_returned 42))
  
  ;; Context reverted after with block
  (.info logger "Request completed"))

;; Example 3: Child loggers
(defn child-logger-example []
  (print "\n=== Child Logger Example ===")
  (setv parent-logger (get-logger "app" :service "api"))
  (setv auth-logger (.child parent-logger "auth" :module "authentication"))
  (setv db-logger (.child parent-logger "db" :module "database"))
  
  (.info parent-logger "API server starting")
  (.info auth-logger "Authentication service initialized")
  (.info db-logger "Database connection established" :pool_size 10))

;; Example 4: Error handling with decorators
(defn error-handling-example []
  (print "\n=== Error Handling Example ===")
  (setv logger (get-logger "app.errors"))
  
  ;; Define functions with error logging
  (with-decorator (log-errors logger)
    (defn risky-operation [x]
      (if (> x 5)
          (raise (ValueError f"Value {x} is too large"))
          (* x 2))))
  
  ;; This will work fine
  (.info logger "Trying safe operation")
  (risky-operation 3)
  
  ;; This will log an error
  (.info logger "Trying risky operation")
  (try
    (risky-operation 10)
    (except [e ValueError]
      (.info logger "Error was logged and handled"))))

;; Example 5: Function execution logging
(defn execution-logging-example []
  (print "\n=== Execution Logging Example ===")
  (setv logger (get-logger "app.execution"))
  
  ;; Define a function with execution logging
  (with-decorator (log-execution logger :level "INFO" :include-args True :include-result True)
    (defn calculate-something [x y]
      (time.sleep 0.1)  ; Simulate work
      (+ (* x 2) y)))
  
  (calculate-something 5 3))

;; Example 6: Custom factory with global fields
(defn factory-example []
  (print "\n=== Factory Example ===")
  (setv factory (LoggerFactory :default-level "DEBUG" 
                                :global-fields {"environment" "production"
                                                "version" "1.2.3"}))
  
  (setv logger1 (.get-logger factory "service.api"))
  (setv logger2 (.get-logger factory "service.worker"))
  
  (.info logger1 "API request received" :endpoint "/users")
  (.info logger2 "Processing background job" :job_id "job-789"))

;; Example 7: Different log levels
(defn log-levels-example []
  (print "\n=== Log Levels Example ===")
  (setv logger (StructuredLogger "app.levels" :level "WARNING"))
  
  (.debug logger "This won't be logged")
  (.info logger "This won't be logged either")
  (.warning logger "This will be logged")
  (.error logger "This will also be logged")
  (.critical logger "Critical issues are always logged"))

;; Example 8: Exception logging
(defn exception-logging-example []
  (print "\n=== Exception Logging Example ===")
  (setv logger (get-logger "app.exceptions"))
  
  (try
    (/ 1 0)
    (except [e Exception]
      (.error logger "Division by zero error" :exception e :operation "divide"))))

;; Example 9: Structured data logging
(defn structured-data-example []
  (print "\n=== Structured Data Example ===")
  (setv logger (get-logger "app.data"))
  
  ;; Log complex data structures
  (.info logger "User profile updated"
         :user {"id" 789
                "name" "Alice"
                "email" "alice@example.com"}
         :changes ["email" "preferences"]
         :metadata {"source" "web_app"
                    "ip" "192.168.1.100"}))

;; Example 10: Performance monitoring
(defn performance-example []
  (print "\n=== Performance Monitoring Example ===")
  (setv logger (get-logger "app.performance"))
  
  (defn monitor-operation [operation-name func]
    (setv start-time (time.time))
    (try
      (setv result (func))
      (setv duration (* (- (time.time) start-time) 1000))
      (.info logger f"Operation completed: {operation-name}"
             :operation operation-name
             :duration_ms duration
             :status "success")
      result
      (except [e Exception]
        (setv duration (* (- (time.time) start-time) 1000))
        (.error logger f"Operation failed: {operation-name}"
                :operation operation-name
                :duration_ms duration
                :status "error"
                :exception e)
        (raise))))
  
  ;; Monitor different operations
  (monitor-operation "fetch_data" (fn [] (time.sleep 0.05)))
  (monitor-operation "process_data" (fn [] (time.sleep 0.1)))
  (monitor-operation "save_results" (fn [] (time.sleep 0.03))))

;; Example 11: Claude Code Subagent Integration
(defn subagent-example []
  (print "\n=== Claude Code Subagent Example ===")
  (setv logger (get-logger "app.subagent"))
  
  ;; Check if subagent is installed
  (setv status (check-subagent-status))
  
  (if (get status "installed")
      (do
        (.info logger "Claude Code subagent is installed"
               :path (get status "path")
               :size (get status "size"))
        (print f"✅ Subagent found at: {(get status 'path')}"))
      (do
        (.warning logger "Claude Code subagent not installed"
                  :claude_dir (get status "claude_dir"))
        (print "⚠️  Subagent not installed.")
        (when (get status "claude_dir")
          (print f"   .claude directory found at: {(get status 'claude_dir')}")
          (print "   Run 'hy install_subagent.hy' to install")))))

;; Run all examples
(defn main []
  (print "Structured Logging Examples for Hy\n")
  (print "All log output is in JSON format\n")
  
  (basic-example)
  (context-example)
  (child-logger-example)
  (error-handling-example)
  (execution-logging-example)
  (factory-example)
  (log-levels-example)
  (exception-logging-example)
  (structured-data-example)
  (performance-example)
  (subagent-example)
  
  (print "\n=== Examples Complete ==="))

(when (= __name__ "__main__")
  (main))
