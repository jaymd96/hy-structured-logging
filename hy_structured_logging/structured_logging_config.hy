;;; structured_logging_config.hy
;;; Environment-based configuration for structured logging

(import os)
(import sys)
(import json)
(import re)
(import structured_logging [StructuredLogger LoggerFactory get-logger])

;; Default configuration values
(setv DEFAULT_CONFIG {
  ;; Core settings
  "LEVEL" "INFO"
  "OUTPUT" "stdout"
  "FORMAT" "json"
  "APP_NAME" "app"
  "ENV" "development"
  "REGION" ""
  "VERSION" ""
  
  ;; Feature flags
  "ADD_HOSTNAME" "true"
  "ADD_PROCESS_INFO" "true"
  "ADD_THREAD_INFO" "false"
  "CORRELATION_ID" "true"
  
  ;; Performance settings
  "BUFFER_SIZE" "1000"
  "FLUSH_INTERVAL" "5"
  "SAMPLE_RATE" "1.0"
  
  ;; Privacy and security
  "REDACT_PATTERNS" "password,token,secret,key,authorization,api_key,access_token"
  "REDACT_EMAILS" "false"
  "REDACT_IPS" "false"
  "HASH_USER_IDS" "false"
  
  ;; Development settings
  "DEV_MODE" "false"
  "SHOW_LOCALS" "false"
  "PROFILE" "false"
  
  ;; File output
  "FILE_PATH" ""
  "FILE_ROTATION" "daily"
  "FILE_MAX_BYTES" "104857600"
  "FILE_BACKUP_COUNT" "7"
  
  ;; Remote logging
  "REMOTE_ENABLED" "false"
  "REMOTE_URL" ""
  "REMOTE_API_KEY" ""
  "REMOTE_BATCH_SIZE" "100"
  "REMOTE_TIMEOUT" "5"})

(setv CHERRYPY_DEFAULTS {
  "ENABLED" "false"
  "REQUESTS" "true"
  "RESPONSES" "true"
  "ERRORS" "true"
  "ACCESS" "true"
  "SLOW_REQUEST_MS" "1000"
  "REQUEST_BODY" "false"
  "RESPONSE_BODY" "false"
  "HEADERS" "true"})

(setv SQLOBJECT_DEFAULTS {
  "ENABLED" "false"
  "QUERIES" "true"
  "SLOW_QUERY_MS" "100"
  "CONNECTIONS" "true"
  "TRANSACTIONS" "true"
  "SIGNALS" "true"
  "AUDIT" "true"
  "EXPLAIN" "false"
  "POOL_STATS" "true"})

(defclass EnvironmentConfig []
  "Loads and validates configuration from environment variables"
  
  (defn __init__ [self &optional [prefix "STRUCTURED_LOG_"]]
    (setv self.prefix prefix)
    (setv self.config {})
    (setv self.cherrypy-config {})
    (setv self.sqlobject-config {})
    (self.load-from-env)
    (self.validate)
    (self.process-values))
  
  (defn load-from-env [self]
    "Load all environment variables with prefix"
    ;; Load core config
    (for [[key default] (.items DEFAULT_CONFIG)]
      (setv env-key (+ self.prefix key))
      (setv value (os.environ.get env-key default))
      (setv (get self.config key) value))
    
    ;; Load CherryPy config
    (setv cherrypy-prefix (+ "CHERRYPY_" self.prefix))
    (for [[key default] (.items CHERRYPY_DEFAULTS)]
      (setv env-key (+ cherrypy-prefix key))
      (setv value (os.environ.get env-key default))
      (setv (get self.cherrypy-config key) value))
    
    ;; Load SQLObject config
    (setv sqlobject-prefix (+ "SQLOBJECT_" self.prefix))
    (for [[key default] (.items SQLOBJECT_DEFAULTS)]
      (setv env-key (+ sqlobject-prefix key))
      (setv value (os.environ.get env-key default))
      (setv (get self.sqlobject-config key) value)))
  
  (defn validate [self]
    "Validate configuration values"
    ;; Validate log level
    (setv valid-levels ["DEBUG" "INFO" "WARNING" "ERROR" "CRITICAL"])
    (when (not (in (.upper (get self.config "LEVEL")) valid-levels))
      (raise (ValueError f"Invalid log level: {(get self.config 'LEVEL')}")))
    
    ;; Validate format
    (setv valid-formats ["json" "pretty" "compact"])
    (when (not (in (.lower (get self.config "FORMAT")) valid-formats))
      (raise (ValueError f"Invalid log format: {(get self.config 'FORMAT')}")))
    
    ;; Validate sample rate
    (setv sample-rate (float (get self.config "SAMPLE_RATE")))
    (when (or (< sample-rate 0.0) (> sample-rate 1.0))
      (raise (ValueError f"Sample rate must be between 0.0 and 1.0"))))
  
  (defn process-values [self]
    "Convert string values to appropriate types"
    ;; Convert booleans
    (for [key ["ADD_HOSTNAME" "ADD_PROCESS_INFO" "ADD_THREAD_INFO" 
               "CORRELATION_ID" "DEV_MODE" "SHOW_LOCALS" "PROFILE"
               "REDACT_EMAILS" "REDACT_IPS" "HASH_USER_IDS"
               "REMOTE_ENABLED"]]
      (setv (get self.config key) 
            (self.parse-bool (get self.config key))))
    
    (for [key ["ENABLED" "REQUESTS" "RESPONSES" "ERRORS" "ACCESS"
               "REQUEST_BODY" "RESPONSE_BODY" "HEADERS"]]
      (setv (get self.cherrypy-config key)
            (self.parse-bool (get self.cherrypy-config key))))
    
    (for [key ["ENABLED" "QUERIES" "CONNECTIONS" "TRANSACTIONS"
               "SIGNALS" "AUDIT" "EXPLAIN" "POOL_STATS"]]
      (setv (get self.sqlobject-config key)
            (self.parse-bool (get self.sqlobject-config key))))
    
    ;; Convert integers
    (for [key ["BUFFER_SIZE" "FILE_MAX_BYTES" "FILE_BACKUP_COUNT"
               "REMOTE_BATCH_SIZE" "REMOTE_TIMEOUT" "FLUSH_INTERVAL"]]
      (when (get self.config key)
        (setv (get self.config key) (int (get self.config key)))))
    
    (setv (get self.cherrypy-config "SLOW_REQUEST_MS")
          (int (get self.cherrypy-config "SLOW_REQUEST_MS")))
    (setv (get self.sqlobject-config "SLOW_QUERY_MS")
          (int (get self.sqlobject-config "SLOW_QUERY_MS")))
    
    ;; Convert float
    (setv (get self.config "SAMPLE_RATE") 
          (float (get self.config "SAMPLE_RATE")))
    
    ;; Parse redact patterns
    (setv patterns-str (get self.config "REDACT_PATTERNS"))
    (if patterns-str
        (setv (get self.config "REDACT_PATTERNS")
              (.split patterns-str ","))
        (setv (get self.config "REDACT_PATTERNS") [])))
  
  (defn parse-bool [self value]
    "Parse boolean from string"
    (in (.lower (str value)) ["true" "1" "yes" "on"]))
  
  (defn get-output-stream [self]
    "Get the output stream based on configuration"
    (setv output-setting (get self.config "OUTPUT"))
    (cond
      [(= output-setting "stdout") sys.stdout]
      [(= output-setting "stderr") sys.stderr]
      [(and output-setting (.startswith output-setting "/"))
       (open output-setting "a")]
      [True sys.stdout]))
  
  (defn get-global-fields [self]
    "Get global fields to include in all logs"
    (setv fields {})
    
    ;; Add basic fields
    (when (get self.config "APP_NAME")
      (setv (get fields "app") (get self.config "APP_NAME")))
    (when (get self.config "ENV")
      (setv (get fields "environment") (get self.config "ENV")))
    (when (get self.config "REGION")
      (setv (get fields "region") (get self.config "REGION")))
    (when (get self.config "VERSION")
      (setv (get fields "version") (get self.config "VERSION")))
    
    ;; Add system info if enabled
    (when (get self.config "ADD_HOSTNAME")
      (import socket)
      (setv (get fields "hostname") (socket.gethostname)))
    
    (when (get self.config "ADD_PROCESS_INFO")
      (setv (get fields "pid") (os.getpid))
      (setv (get fields "process") (get sys.argv 0)))
    
    (when (get self.config "ADD_THREAD_INFO")
      (import threading)
      (setv (get fields "thread_id") (threading.get-ident))
      (setv (get fields "thread_name") (. (threading.current-thread) name)))
    
    fields)
  
  (defn should-enable-cherrypy [self]
    "Check if CherryPy integration should be enabled"
    (get self.cherrypy-config "ENABLED"))
  
  (defn should-enable-sqlobject [self]
    "Check if SQLObject integration should be enabled"
    (get self.sqlobject-config "ENABLED")))

(defclass LogRedactor []
  "Handles redaction of sensitive information in logs"
  
  (defn __init__ [self config]
    (setv self.config config)
    (setv self.patterns (self.compile-patterns))
    (setv self.email-pattern 
          (re.compile r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"))
    (setv self.ip-pattern
          (re.compile r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b")))
  
  (defn compile-patterns [self]
    "Compile redaction patterns"
    (setv patterns [])
    (for [pattern (get self.config "REDACT_PATTERNS")]
      (try
        (.append patterns 
                 (re.compile (+ r"\b" pattern r"['\"]?\s*[:=]\s*['\"]?([^'\"}\s]+)")))
        (except [e Exception]
          ;; Skip invalid patterns
          pass)))
    patterns)
  
  (defn redact [self data]
    "Redact sensitive information from data"
    (if (isinstance data str)
        (self.redact-string data)
        (if (isinstance data dict)
            (self.redact-dict data)
            data)))
  
  (defn redact-string [self text]
    "Redact sensitive information from string"
    ;; Redact based on patterns
    (for [pattern self.patterns]
      (setv text (pattern.sub r"\1=***REDACTED***" text)))
    
    ;; Redact emails if enabled
    (when (get self.config "REDACT_EMAILS")
      (setv text (self.email-pattern.sub "***EMAIL***" text)))
    
    ;; Redact IPs if enabled
    (when (get self.config "REDACT_IPS")
      (setv text (self.ip-pattern.sub "***IP***" text)))
    
    text)
  
  (defn redact-dict [self data]
    "Redact sensitive information from dictionary"
    (setv redacted {})
    (for [[key value] (.items data)]
      ;; Check if key should be redacted
      (setv should-redact False)
      (for [pattern (get self.config "REDACT_PATTERNS")]
        (when (in pattern (.lower (str key)))
          (setv should-redact True)
          (break)))
      
      (if should-redact
          (setv (get redacted key) "***REDACTED***")
          (if (isinstance value str)
              (setv (get redacted key) (self.redact-string value))
              (if (isinstance value dict)
                  (setv (get redacted key) (self.redact-dict value))
                  (setv (get redacted key) value)))))
    redacted))

(defclass CorrelationIDGenerator []
  "Generates and manages correlation IDs for request tracing"
  
  (defn __init__ [self]
    (import uuid)
    (import threading)
    (setv self.uuid uuid)
    (setv self.local (threading.local)))
  
  (defn generate [self]
    "Generate a new correlation ID"
    (str (self.uuid.uuid4)))
  
  (defn get-or-create [self]
    "Get existing or create new correlation ID for current context"
    (if (hasattr self.local "correlation_id")
        self.local.correlation_id
        (do
          (setv self.local.correlation_id (self.generate))
          self.local.correlation_id)))
  
  (defn set [self correlation-id]
    "Set correlation ID for current context"
    (setv self.local.correlation_id correlation-id))
  
  (defn clear [self]
    "Clear correlation ID for current context"
    (when (hasattr self.local "correlation_id")
      (del self.local.correlation_id))))

(defclass SamplingLogger [StructuredLogger]
  "Logger with sampling support for high-volume logs"
  
  (defn __init__ [self &kwargs kwargs]
    (setv self.sample-rate (kwargs.pop "sample_rate" 1.0))
    (super.__init__ #** kwargs)
    (import random)
    (setv self.random random))
  
  (defn should-log [self level]
    "Check if message should be logged based on level and sampling"
    (setv base-should-log (super._should-log level))
    (if (and base-should-log (< level 20))  ; Sample DEBUG only
        (< (self.random.random) self.sample-rate)
        base-should-log)))

(defn create-logger-factory [config]
  "Create a logger factory with environment configuration"
  (setv factory (LoggerFactory 
                  :default-level (get config.config "LEVEL")
                  :output (config.get-output-stream)
                  :global-fields (config.get-global-fields)))
  
  ;; Add redactor if patterns configured
  (when (get config.config "REDACT_PATTERNS")
    (setv factory.redactor (LogRedactor config.config)))
  
  ;; Add correlation ID generator if enabled
  (when (get config.config "CORRELATION_ID")
    (setv factory.correlation-generator (CorrelationIDGenerator)))
  
  ;; Set sample rate
  (setv factory.sample-rate (get config.config "SAMPLE_RATE"))
  
  factory)

;; Main auto-configuration function
(defn auto-configure [&optional [prefix "STRUCTURED_LOG_"]]
  "Automatically configure logging from environment variables
  
  Returns:
    Dictionary with configured components:
    - 'factory': LoggerFactory instance
    - 'config': EnvironmentConfig instance
    - 'cherrypy': CherryPy integration (if enabled)
    - 'sqlobject': SQLObject integration (if enabled)"
  
  ;; Load configuration
  (setv config (EnvironmentConfig prefix))
  
  ;; Create logger factory
  (setv factory (create-logger-factory config))
  
  ;; Result dictionary
  (setv result {"factory" factory
                "config" config})
  
  ;; Configure CherryPy if enabled
  (when (config.should-enable-cherrypy)
    (try
      (import structured_logging.integrations.cherrypy [configure-cherrypy])
      (setv cherrypy-result (configure-cherrypy factory config))
      (setv (get result "cherrypy") cherrypy-result)
      (except [ImportError]
        (print "Warning: CherryPy integration enabled but module not found"))))
  
  ;; Configure SQLObject if enabled
  (when (config.should-enable-sqlobject)
    (try
      (import structured_logging.integrations.sqlobject [configure-sqlobject])
      (setv sqlobject-result (configure-sqlobject factory config))
      (setv (get result "sqlobject") sqlobject-result)
      (except [ImportError]
        (print "Warning: SQLObject integration enabled but module not found"))))
  
  ;; Log configuration if in debug mode
  (when (os.environ.get "STRUCTURED_LOG_DEBUG_CONFIG")
    (setv logger (factory.get-logger "config"))
    (.info logger "Logging configured from environment"
           :config (dict config.config)
           :cherrypy_enabled (config.should-enable-cherrypy)
           :sqlobject_enabled (config.should-enable-sqlobject)))
  
  result)

;; Export main components
(setv __all__ ["EnvironmentConfig" "LogRedactor" "CorrelationIDGenerator"
               "SamplingLogger" "auto-configure" "create-logger-factory"])
