;;; test_structured_logging.hy
;;; Tests for the structured logging package

(import structured_logging [StructuredLogger LoggerFactory get-logger 
                            log-execution log-errors with-context
                            parse-log-level format-exception LOG_LEVELS])
(import json)
(import io [StringIO])
(import sys)

(defclass TestStructuredLogger []
  "Test cases for StructuredLogger"
  
  (defn setup [self]
    "Set up test fixtures"
    (setv self.output (StringIO))
    (setv self.logger (StructuredLogger "test" :output self.output)))
  
  (defn get-log-output [self]
    "Get and parse the log output"
    (setv output-str (.getvalue self.output))
    (if output-str
        (lfor line (.strip (.split output-str "\n"))
              :if line
              (json.loads line))
        []))
  
  (defn test-basic-logging [self]
    "Test basic logging functionality"
    (self.setup)
    
    (.info self.logger "Test message" :key "value")
    (setv logs (self.get-log-output))
    
    (assert (= (len logs) 1))
    (setv log (get logs 0))
    (assert (= (get log "message") "Test message"))
    (assert (= (get log "level") "INFO"))
    (assert (= (get log "key") "value"))
    (assert (in "timestamp" log))
    (print "✓ Basic logging test passed"))
  
  (defn test-log-levels [self]
    "Test different log levels"
    (self.setup)
    
    (.set-level self.logger "WARNING")
    
    (.debug self.logger "Debug message")
    (.info self.logger "Info message")
    (.warning self.logger "Warning message")
    (.error self.logger "Error message")
    
    (setv logs (self.get-log-output))
    
    ;; Only WARNING and above should be logged
    (assert (= (len logs) 2))
    (assert (= (get (get logs 0) "level") "WARNING"))
    (assert (= (get (get logs 1) "level") "ERROR"))
    (print "✓ Log levels test passed"))
  
  (defn test-context-fields [self]
    "Test context field management"
    (self.setup)
    
    (.with-context self.logger :request_id "123" :user_id "456")
    (.info self.logger "First message")
    (.info self.logger "Second message")
    
    (setv logs (self.get-log-output))
    
    (assert (= (len logs) 2))
    (for [log logs]
      (assert (= (get log "request_id") "123"))
      (assert (= (get log "user_id") "456")))
    
    (.clear-context self.logger)
    (.info self.logger "Third message")
    
    (setv all-logs (self.get-log-output))
    (setv third-log (get all-logs 2))
    (assert (not (in "request_id" third-log)))
    (assert (not (in "user_id" third-log)))
    (print "✓ Context fields test passed"))
  
  (defn test-child-logger [self]
    "Test child logger functionality"
    (self.setup)
    
    (setv child (.child self.logger "child" :component "auth"))
    (.info child "Child message")
    
    (setv logs (self.get-log-output))
    (setv log (get logs 0))
    
    (assert (= (get log "logger") "test.child"))
    (assert (= (get log "component") "auth"))
    (print "✓ Child logger test passed"))
  
  (defn test-exception-logging [self]
    "Test exception logging"
    (self.setup)
    
    (try
      (/ 1 0)
      (except [e Exception]
        (.error self.logger "Math error" :exception e)))
    
    (setv logs (self.get-log-output))
    (setv log (get logs 0))
    
    (assert (= (get log "error_type") "ZeroDivisionError"))
    (assert (in "division" (.lower (get log "error_message"))))
    (assert (in "stacktrace" log))
    (print "✓ Exception logging test passed"))
  
  (defn test-with-context-manager [self]
    "Test the with-context context manager"
    (self.setup)
    
    (.with-context self.logger :persistent "value")
    
    (with [(with-context self.logger :temporary "temp")]
      (.info self.logger "Inside context"))
    
    (.info self.logger "Outside context")
    
    (setv logs (self.get-log-output))
    
    (setv inside-log (get logs 0))
    (assert (= (get inside-log "persistent") "value"))
    (assert (= (get inside-log "temporary") "temp"))
    
    (setv outside-log (get logs 1))
    (assert (= (get outside-log "persistent") "value"))
    (assert (not (in "temporary" outside-log)))
    (print "✓ Context manager test passed")))

(defclass TestLoggerFactory []
  "Test cases for LoggerFactory"
  
  (defn test-factory-singleton [self]
    "Test that factory returns same logger instance for same name"
    (setv output (StringIO))
    (setv factory (LoggerFactory :output output))
    
    (setv logger1 (.get-logger factory "test"))
    (setv logger2 (.get-logger factory "test"))
    
    (assert (is logger1 logger2))
    (print "✓ Factory singleton test passed"))
  
  (defn test-factory-global-fields [self]
    "Test global fields in factory"
    (setv output (StringIO))
    (setv factory (LoggerFactory :output output 
                                  :global-fields {"env" "test"}))
    
    (setv logger (.get-logger factory "app"))
    (.info logger "Test message")
    
    (setv output-str (.getvalue output))
    (setv log (json.loads output-str))
    
    (assert (= (get log "env") "test"))
    (print "✓ Factory global fields test passed"))
  
  (defn test-set-global-level [self]
    "Test setting global log level"
    (setv output (StringIO))
    (setv factory (LoggerFactory :output output :default-level "DEBUG"))
    
    (setv logger1 (.get-logger factory "app1"))
    (setv logger2 (.get-logger factory "app2"))
    
    (.set-global-level factory "ERROR")
    
    (.info logger1 "This won't log")
    (.error logger2 "This will log")
    
    (setv output-str (.getvalue output))
    (setv logs (.strip (.split output-str "\n")))
    (setv logs (lfor line logs :if line line))
    
    (assert (= (len logs) 1))
    (print "✓ Global level test passed")))

(defclass TestDecorators []
  "Test cases for logging decorators"
  
  (defn test-log-execution [self]
    "Test log-execution decorator"
    (setv output (StringIO))
    (setv logger (StructuredLogger "test" :output output))
    
    (with-decorator (log-execution logger :include-args True :include-result True)
      (defn test-func [x y]
        (+ x y)))
    
    (setv result (test-func 2 3))
    (assert (= result 5))
    
    (setv output-str (.getvalue output))
    (setv logs (lfor line (.strip (.split output-str "\n"))
                     :if line
                     (json.loads line)))
    
    ;; Should have entry and exit logs
    (assert (= (len logs) 2))
    
    (setv entry-log (get logs 0))
    (assert (= (get entry-log "event") "function_entry"))
    (assert (= (get entry-log "args") [2 3]))
    
    (setv exit-log (get logs 1))
    (assert (= (get exit-log "event") "function_exit"))
    (assert (= (get exit-log "status") "success"))
    (assert (= (get exit-log "result") 5))
    (assert (in "duration_ms" exit-log))
    (print "✓ Log execution decorator test passed"))
  
  (defn test-log-errors [self]
    "Test log-errors decorator"
    (setv output (StringIO))
    (setv logger (StructuredLogger "test" :output output))
    
    (with-decorator (log-errors logger)
      (defn failing-func []
        (raise (ValueError "Test error"))))
    
    (try
      (failing-func)
      (except [e ValueError]
        pass))
    
    (setv output-str (.getvalue output))
    (setv logs (lfor line (.strip (.split output-str "\n"))
                     :if line
                     (json.loads line)))
    
    (assert (= (len logs) 1))
    (setv log (get logs 0))
    (assert (= (get log "level") "ERROR"))
    (assert (in "failing-func" (get log "message")))
    (assert (= (get log "error_type") "ValueError"))
    (print "✓ Log errors decorator test passed")))

(defclass TestUtilities []
  "Test utility functions"
  
  (defn test-parse-log-level [self]
    "Test log level parsing"
    (assert (= (parse-log-level "debug") 10))
    (assert (= (parse-log-level "INFO") 20))
    (assert (= (parse-log-level "warning") 30))
    (assert (= (parse-log-level "ERROR") 40))
    (assert (= (parse-log-level "CRITICAL") 50))
    (assert (= (parse-log-level "unknown") 20))  ; Default to INFO
    (print "✓ Parse log level test passed"))
  
  (defn test-format-exception [self]
    "Test exception formatting"
    (try
      (/ 1 0)
      (except [e Exception]
        (setv formatted (format-exception e))
        (assert (= (get formatted "error_type") "ZeroDivisionError"))
        (assert (in "division" (.lower (get formatted "error_message"))))
        (assert (isinstance (get formatted "stacktrace") list))))
    (print "✓ Format exception test passed")))

;; Run all tests
(defn run-tests []
  (print "Running Structured Logging Tests\n")
  
  (print "Testing StructuredLogger:")
  (setv logger-tests (TestStructuredLogger))
  (.test-basic-logging logger-tests)
  (.test-log-levels logger-tests)
  (.test-context-fields logger-tests)
  (.test-child-logger logger-tests)
  (.test-exception-logging logger-tests)
  (.test-with-context-manager logger-tests)
  
  (print "\nTesting LoggerFactory:")
  (setv factory-tests (TestLoggerFactory))
  (.test-factory-singleton factory-tests)
  (.test-factory-global-fields factory-tests)
  (.test-set-global-level factory-tests)
  
  (print "\nTesting Decorators:")
  (setv decorator-tests (TestDecorators))
  (.test-log-execution decorator-tests)
  (.test-log-errors decorator-tests)
  
  (print "\nTesting Utilities:")
  (setv utility-tests (TestUtilities))
  (.test-parse-log-level utility-tests)
  (.test-format-exception utility-tests)
  
  (print "\n✅ All tests passed!"))

(when (= __name__ "__main__")
  (run-tests))
