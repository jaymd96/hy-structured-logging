;;; integrations/cherrypy.hy
;;; CherryPy integration for structured logging

(import cherrypy)
(import time)
(import json)
(import uuid)
(import threading)
(import logging)
(import structured_logging [StructuredLogger])

(defclass CherryPyStructuredHandler [logging.Handler]
  "Logging handler that converts CherryPy logs to structured format"
  
  (defn __init__ [self structured-logger]
    (super.__init__)
    (setv self.structured-logger structured-logger))
  
  (defn emit [self record]
    "Emit a log record in structured format"
    ;; Map Python log levels to our levels
    (setv level-map {
      logging.DEBUG "DEBUG"
      logging.INFO "INFO"
      logging.WARNING "WARNING"
      logging.ERROR "ERROR"
      logging.CRITICAL "CRITICAL"})
    
    (setv level (get level-map record.levelno "INFO"))
    
    ;; Build structured log entry
    (setv fields {
      "logger_name" record.name
      "module" record.module
      "function" record.funcName
      "line" record.lineno})
    
    ;; Add exception info if present
    (when record.exc_info
      (import traceback)
      (setv (get fields "exception") {
        "type" (. (get record.exc_info 0) __name__)
        "message" (str (get record.exc_info 1))
        "stacktrace" (traceback.format_exception #* record.exc_info)}))
    
    ;; Log using structured logger
    (self.structured-logger.log level record.getMessage #** fields)))

(defclass RequestContextTool [cherrypy.Tool]
  "CherryPy tool for adding request context to logs"
  
  (defn __init__ [self logger-factory]
    (super.__init__ "before_handler" self.add-context :priority 10)
    (setv self.logger-factory logger-factory)
    (setv self.local (threading.local)))
  
  (defn add-context [self]
    "Add request context to logger"
    ;; Generate request ID
    (setv request-id (str (uuid.uuid4)))
    (setv cherrypy.request.id request-id)
    
    ;; Store start time
    (setv cherrypy.request.start_time (time.time))
    
    ;; Get logger for this request
    (setv logger (self.logger-factory.get-logger "cherrypy.request"))
    
    ;; Add request context
    (.with-context logger
                   :request_id request-id
                   :method cherrypy.request.method
                   :path cherrypy.request.path_info
                   :remote_ip cherrypy.request.remote.ip
                   :user_agent (cherrypy.request.headers.get "User-Agent" ""))
    
    ;; Store logger in thread local
    (setv self.local.logger logger)
    
    ;; Log request start
    (.info logger "Request started"
           :query_string cherrypy.request.query_string
           :content_length (cherrypy.request.headers.get "Content-Length" 0))))

(defclass ResponseLoggingTool [cherrypy.Tool]
  "CherryPy tool for logging responses"
  
  (defn __init__ [self logger-factory config]
    (super.__init__ "on_end_request" self.log-response)
    (setv self.logger-factory logger-factory)
    (setv self.config config))
  
  (defn log-response [self]
    "Log response details"
    (setv logger (self.logger-factory.get-logger "cherrypy.response"))
    
    ;; Calculate duration
    (setv duration-ms 0)
    (when (hasattr cherrypy.request "start_time")
      (setv duration-ms (* (- (time.time) cherrypy.request.start_time) 1000)))
    
    ;; Get response details
    (setv status cherrypy.response.status)
    (setv response-size (len (or cherrypy.response.body [b""])))
    
    ;; Determine log level based on status code
    (setv status-code (int (.split (str status) " ") [0]))
    (setv level (cond
      [(< status-code 400) "INFO"]
      [(< status-code 500) "WARNING"]
      [True "ERROR"]))
    
    ;; Check if slow request
    (setv slow-threshold (get self.config.cherrypy-config "SLOW_REQUEST_MS"))
    (when (> duration-ms slow-threshold)
      (setv level "WARNING"))
    
    ;; Build log fields
    (setv fields {
      "request_id" (getattr cherrypy.request "id" "unknown")
      "status_code" status-code
      "duration_ms" duration-ms
      "response_size" response-size
      "content_type" (cherrypy.response.headers.get "Content-Type" "")})
    
    ;; Add slow request warning
    (when (> duration-ms slow-threshold)
      (setv (get fields "slow_request") True)
      (setv (get fields "threshold_ms") slow-threshold))
    
    ;; Log response
    (.log logger level "Request completed" #** fields)))

(defclass ErrorLoggingTool [cherrypy.Tool]
  "CherryPy tool for structured error logging"
  
  (defn __init__ [self logger-factory]
    (super.__init__ "before_error_response" self.log-error)
    (setv self.logger-factory logger-factory))
  
  (defn log-error [self]
    "Log errors in structured format"
    (setv logger (self.logger-factory.get-logger "cherrypy.error"))
    
    ;; Get error details
    (setv status cherrypy.response.status)
    (setv error-msg (or (getattr cherrypy.response "body" "") "Unknown error"))
    
    ;; Get traceback if available
    (setv traceback-info None)
    (when (hasattr cherrypy "serving.request.error_response")
      (import traceback)
      (setv traceback-info (traceback.format_exc)))
    
    ;; Build error fields
    (setv fields {
      "request_id" (getattr cherrypy.request "id" "unknown")
      "status_code" status
      "method" cherrypy.request.method
      "path" cherrypy.request.path_info
      "error_message" error-msg})
    
    (when traceback-info
      (setv (get fields "stacktrace") traceback-info))
    
    ;; Log error
    (.error logger "Request error" #** fields)))

(defn configure-cherrypy [logger-factory config]
  "Configure CherryPy with structured logging
  
  Args:
      logger-factory: LoggerFactory instance
      config: EnvironmentConfig instance
  
  Returns:
      Dictionary with configured tools and handlers"
  
  ;; Create structured logger for CherryPy
  (setv cherrypy-logger (logger-factory.get-logger "cherrypy"))
  
  ;; Replace CherryPy's default loggers
  (when (get config.cherrypy-config "ACCESS")
    (setv handler (CherryPyStructuredHandler 
                    (logger-factory.get-logger "cherrypy.access")))
    (cherrypy.log.access_log.addHandler handler)
    ;; Remove default handlers
    (setv cherrypy.log.access_log.handlers [handler]))
  
  (when (get config.cherrypy-config "ERRORS")
    (setv handler (CherryPyStructuredHandler
                    (logger-factory.get-logger "cherrypy.error")))
    (cherrypy.log.error_log.addHandler handler)
    ;; Remove default handlers
    (setv cherrypy.log.error_log.handlers [handler]))
  
  ;; Create tools
  (setv request-tool (RequestContextTool logger-factory))
  (setv response-tool (ResponseLoggingTool logger-factory config))
  (setv error-tool (ErrorLoggingTool logger-factory))
  
  ;; Register tools
  (setv cherrypy.tools.structured_request request-tool)
  (setv cherrypy.tools.structured_response response-tool)
  (setv cherrypy.tools.structured_error error-tool)
  
  ;; Enable tools globally if configured
  (when (get config.cherrypy-config "REQUESTS")
    (setv (get cherrypy.config "tools.structured_request.on") True))
  
  (when (get config.cherrypy-config "RESPONSES")
    (setv (get cherrypy.config "tools.structured_response.on") True))
  
  (when (get config.cherrypy-config "ERRORS")
    (setv (get cherrypy.config "tools.structured_error.on") True))
  
  ;; Return configuration
  {"logger" cherrypy-logger
   "request_tool" request-tool
   "response_tool" response-tool
   "error_tool" error-tool
   "access_handler" (when (get config.cherrypy-config "ACCESS") handler)
   "error_handler" (when (get config.cherrypy-config "ERRORS") handler)})

(defclass CherryPyLogPlugin [cherrypy.process.plugins.SimplePlugin]
  "Plugin for managing structured logging lifecycle"
  
  (defn __init__ [self logger-factory bus]
    (super.__init__ bus)
    (setv self.logger-factory logger-factory)
    (setv self.logger (logger-factory.get-logger "cherrypy.plugin")))
  
  (defn start [self]
    "Called when the engine starts"
    (.info self.logger "CherryPy engine started"))
  
  (defn stop [self]
    "Called when the engine stops"
    (.info self.logger "CherryPy engine stopped"))
  
  (defn graceful [self]
    "Called for graceful shutdown"
    (.info self.logger "CherryPy graceful shutdown initiated")))

(defn create-cherrypy-app [root-class logger-factory config]
  "Create a CherryPy application with structured logging
  
  Args:
      root-class: Root application class
      logger-factory: LoggerFactory instance
      config: EnvironmentConfig instance
  
  Returns:
      Configured CherryPy application"
  
  ;; Configure logging
  (setv log-config (configure-cherrypy logger-factory config))
  
  ;; Create and configure app
  (setv app-config {
    "/" {
      "tools.structured_request.on" (get config.cherrypy-config "REQUESTS")
      "tools.structured_response.on" (get config.cherrypy-config "RESPONSES")
      "tools.structured_error.on" (get config.cherrypy-config "ERRORS")}})
  
  ;; Create plugin
  (setv plugin (CherryPyLogPlugin logger-factory cherrypy.engine))
  (plugin.subscribe)
  
  ;; Return configured app
  (cherrypy.tree.mount root-class "/" app-config))

;; Export components
(setv __all__ ["CherryPyStructuredHandler" "RequestContextTool"
               "ResponseLoggingTool" "ErrorLoggingTool"
               "configure-cherrypy" "CherryPyLogPlugin"
               "create-cherrypy-app"])
