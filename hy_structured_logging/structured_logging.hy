;;; structured_logging.hy
;;; A structured logging package for Hy with JSON output support

(import json)
(import datetime [datetime])
(import sys)
(import traceback)
(import functools)
(import os)

;; Log levels
(setv LOG_LEVELS {
  "DEBUG" 10
  "INFO" 20
  "WARNING" 30
  "ERROR" 40
  "CRITICAL" 50})

(defclass StructuredLogger []
  "A structured logger that outputs JSON-formatted log entries"
  
  (defn __init__ [self &optional [name "root"] [level "INFO"] [output None] [default-fields {}]]
    "Initialize the structured logger
    
    Args:
        name: Logger name
        level: Minimum log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        output: Output stream (defaults to sys.stdout)
        default-fields: Default fields to include in every log entry"
    (setv self.name name)
    (setv self.level (get LOG_LEVELS level level))
    (setv self.output (or output sys.stdout))
    (setv self.default-fields default-fields)
    (setv self.context-fields {}))
  
  (defn set-level [self level]
    "Set the minimum log level"
    (setv self.level (get LOG_LEVELS level level)))
  
  (defn with-context [self &kwargs context]
    "Add context fields that will be included in subsequent log entries"
    (for [[k v] (.items context)]
      (setv (get self.context-fields k) v))
    self)
  
  (defn clear-context [self]
    "Clear all context fields"
    (setv self.context-fields {})
    self)
  
  (defn child [self name &kwargs default-fields]
    "Create a child logger with additional default fields"
    (setv child-name f"{self.name}.{name}")
    (setv merged-fields (.copy self.default-fields))
    (.update merged-fields default-fields)
    (StructuredLogger child-name 
                      :level self.level
                      :output self.output
                      :default-fields merged-fields))
  
  (defn _should-log [self level]
    "Check if a message at the given level should be logged"
    (>= (get LOG_LEVELS level level) self.level))
  
  (defn _format-entry [self level message &kwargs fields]
    "Format a log entry as a dictionary"
    (setv entry {})
    
    ;; Add default fields
    (.update entry self.default-fields)
    
    ;; Add context fields
    (.update entry self.context-fields)
    
    ;; Add user-provided fields
    (.update entry fields)
    
    ;; Add standard fields
    (setv (get entry "timestamp") (.isoformat (datetime.utcnow)))
    (setv (get entry "level") level)
    (setv (get entry "logger") self.name)
    (setv (get entry "message") message)
    
    ;; Handle exception info if present
    (when (in "exception" fields)
      (setv exc (get fields "exception"))
      (del (get fields "exception"))
      (if (isinstance exc Exception)
          (do
            (setv (get entry "error_type") (. exc __class__ __name__))
            (setv (get entry "error_message") (str exc))
            (setv (get entry "stacktrace") 
                  (traceback.format_exception (type exc) exc (. exc __traceback__))))
          (setv (get entry "error_info") (str exc))))
    
    entry)
  
  (defn _emit [self entry]
    "Emit a log entry to the output stream"
    (try
      (setv json-str (json.dumps entry :default str :ensure-ascii False))
      (.write self.output f"{json-str}\n")
      (.flush self.output)
      (except [e Exception]
        ;; Fallback for JSON serialization errors
        (.write sys.stderr f"Failed to serialize log entry: {e}\n")
        (.flush sys.stderr))))
  
  (defn log [self level message &kwargs fields]
    "Log a message at the specified level with optional fields"
    (when (self._should-log level)
      (setv entry (self._format-entry level message #** fields))
      (self._emit entry)))
  
  (defn debug [self message &kwargs fields]
    "Log a debug message"
    (self.log "DEBUG" message #** fields))
  
  (defn info [self message &kwargs fields]
    "Log an info message"
    (self.log "INFO" message #** fields))
  
  (defn warning [self message &kwargs fields]
    "Log a warning message"
    (self.log "WARNING" message #** fields))
  
  (defn error [self message &kwargs fields]
    "Log an error message"
    (self.log "ERROR" message #** fields))
  
  (defn critical [self message &kwargs fields]
    "Log a critical message"
    (self.log "CRITICAL" message #** fields)))

(defclass LoggerFactory []
  "Factory for creating and managing loggers"
  
  (defn __init__ [self &optional [default-level "INFO"] [output None] [global-fields {}]]
    "Initialize the logger factory
    
    Args:
        default-level: Default log level for new loggers
        output: Default output stream
        global-fields: Fields to include in all loggers"
    (setv self.default-level default-level)
    (setv self.output output)
    (setv self.global-fields global-fields)
    (setv self.loggers {}))
  
  (defn get-logger [self &optional [name "root"] &kwargs default-fields]
    "Get or create a logger with the specified name"
    (when (not (in name self.loggers))
      (setv merged-fields (.copy self.global-fields))
      (.update merged-fields default-fields)
      (setv (get self.loggers name)
            (StructuredLogger name
                              :level self.default-level
                              :output self.output
                              :default-fields merged-fields)))
    (get self.loggers name))
  
  (defn set-global-level [self level]
    "Set the log level for all existing loggers"
    (for [logger (.values self.loggers)]
      (.set-level logger level))))

;; Decorators for automatic logging

(defn log-execution [logger &optional [level "INFO"] [include-args False] [include-result False]]
  "Decorator to automatically log function execution"
  (defn decorator [func]
    (defn wrapper [#* args #** kwargs]
      (setv func-name (. func __name__))
      (setv start-time (datetime.utcnow))
      
      ;; Log function entry
      (setv entry-fields {"event" "function_entry"
                          "function" func-name})
      (when include-args
        (setv (get entry-fields "args") (list args))
        (setv (get entry-fields "kwargs") kwargs))
      
      (.log logger level f"Entering function {func-name}" #** entry-fields)
      
      (try
        ;; Execute the function
        (setv result (func #* args #** kwargs))
        
        ;; Log successful execution
        (setv duration-ms (* (- (datetime.utcnow) start-time).total-seconds 1000))
        (setv exit-fields {"event" "function_exit"
                           "function" func-name
                           "duration_ms" duration-ms
                           "status" "success"})
        (when include-result
          (setv (get exit-fields "result") result))
        
        (.log logger level f"Exiting function {func-name}" #** exit-fields)
        result
        
        (except [e Exception]
          ;; Log exception
          (setv duration-ms (* (- (datetime.utcnow) start-time).total-seconds 1000))
          (.log logger "ERROR" f"Exception in function {func-name}"
                :event "function_exception"
                :function func-name
                :duration_ms duration-ms
                :status "error"
                :exception e)
          (raise))))
    
    (functools.wraps func wrapper))
  decorator)

(defn log-errors [logger]
  "Decorator to automatically log exceptions"
  (defn decorator [func]
    (defn wrapper [#* args #** kwargs]
      (try
        (func #* args #** kwargs)
        (except [e Exception]
          (.error logger f"Exception in {(. func __name__)}"
                  :function (. func __name__)
                  :exception e)
          (raise))))
    (functools.wraps func wrapper))
  decorator)

;; Context managers for temporary context

(defclass LogContext []
  "Context manager for temporary logging context"
  
  (defn __init__ [self logger &kwargs fields]
    (setv self.logger logger)
    (setv self.fields fields)
    (setv self.old-context None))
  
  (defn __enter__ [self]
    (setv self.old-context (.copy self.logger.context-fields))
    (.with-context self.logger #** self.fields)
    self.logger)
  
  (defn __exit__ [self exc-type exc-val exc-tb]
    (setv self.logger.context-fields self.old-context)
    None))

(defn with-context [logger &kwargs fields]
  "Create a context manager for temporary logging context"
  (LogContext logger #** fields))

;; Utility functions

(defn configure-root-logger [&optional [level "INFO"] [output None] &kwargs global-fields]
  "Configure the root logger with default settings"
  (setv output (or output sys.stdout))
  (StructuredLogger "root" :level level :output output :default-fields global-fields))

(defn parse-log-level [level-str]
  "Parse a log level string and return the numeric value"
  (get LOG_LEVELS (.upper level-str) 20))

(defn format-exception [exc]
  "Format an exception for structured logging"
  {"error_type" (. exc __class__ __name__)
   "error_message" (str exc)
   "stacktrace" (traceback.format_exception (type exc) exc (. exc __traceback__))})

;; Default factory instance
(setv default-factory (LoggerFactory))

;; Convenience function for getting loggers
(defn get-logger [&optional [name "root"] &kwargs default-fields]
  "Get a logger from the default factory"
  (.get-logger default-factory name #** default-fields))

;; Export main components
(setv __all__ ["StructuredLogger" "LoggerFactory" "get-logger" "configure-root-logger"
               "log-execution" "log-errors" "with-context" "LOG_LEVELS"
               "parse-log-level" "format-exception"])
