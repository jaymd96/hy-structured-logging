;;; batteries.hy
;;; Batteries-included setup for structured logging

(import structured_logging_config [auto-configure EnvironmentConfig])
(import structured_logging [get-logger])
(import os)
(import sys)

(setv _configured False)
(setv _configuration None)

(defn setup-from-environment [&optional [force False]]
  "Complete setup from environment variables only
  
  This is the true 'batteries included' approach:
  - Reads all config from environment
  - Auto-detects frameworks
  - Configures everything automatically
  - Returns ready-to-use loggers
  
  Args:
      force: Force reconfiguration even if already configured
  
  Returns:
      Dictionary with:
      - 'get_logger': Function to get configured loggers
      - 'factory': The logger factory
      - 'config': The configuration object
      - 'cherrypy': CherryPy integration (if enabled)
      - 'sqlobject': SQLObject integration (if enabled)
  
  Usage:
      (import structured_logging.batteries [setup-from-environment])
      (setv logging (setup-from-environment))
      (setv logger ((get logging 'get_logger) 'mymodule'))
      (.info logger 'Application started')"
  
  (global _configured _configuration)
  
  ;; Check if already configured
  (when (and _configured (not force))
    (return _configuration))
  
  ;; Run auto-configuration
  (setv result (auto-configure))
  
  ;; Add convenience function
  (setv (get result "get_logger") 
        (fn [name &kwargs fields]
          (.get-logger (get result "factory") name #** fields)))
  
  ;; Store configuration
  (setv _configured True)
  (setv _configuration result)
  
  ;; Print configuration summary if in dev mode
  (when (= (os.environ.get "STRUCTURED_LOG_DEV_MODE" "false") "true")
    (print "\n=== Structured Logging Configuration ===")
    (print f"Level: {(get result.config.config 'LEVEL')}")
    (print f"Output: {(get result.config.config 'OUTPUT')}")
    (print f"Format: {(get result.config.config 'FORMAT')}")
    (print f"App Name: {(get result.config.config 'APP_NAME')}")
    (print f"Environment: {(get result.config.config 'ENV')}")
    (when (in "cherrypy" result)
      (print "✓ CherryPy integration enabled"))
    (when (in "sqlobject" result)
      (print "✓ SQLObject integration enabled"))
    (print "=========================================\n"))
  
  result)

(defn with-defaults [&optional [env "development"] &kwargs overrides]
  "Setup with sensible defaults for different environments
  
  Args:
      env: Environment name ('development', 'staging', 'production')
      overrides: Additional configuration overrides
  
  Returns:
      Same as setup-from-environment"
  
  ;; Define environment presets
  (setv presets {
    "development" {
      "STRUCTURED_LOG_LEVEL" "DEBUG"
      "STRUCTURED_LOG_FORMAT" "pretty"
      "STRUCTURED_LOG_DEV_MODE" "true"
      "STRUCTURED_LOG_SHOW_LOCALS" "true"
      "STRUCTURED_LOG_ADD_HOSTNAME" "false"
      "STRUCTURED_LOG_ADD_PROCESS_INFO" "false"
      "CHERRYPY_STRUCTURED_LOG_REQUEST_BODY" "true"
      "CHERRYPY_STRUCTURED_LOG_RESPONSE_BODY" "true"
      "SQLOBJECT_STRUCTURED_LOG_EXPLAIN" "true"}
    
    "staging" {
      "STRUCTURED_LOG_LEVEL" "INFO"
      "STRUCTURED_LOG_FORMAT" "json"
      "STRUCTURED_LOG_DEV_MODE" "false"
      "STRUCTURED_LOG_ADD_HOSTNAME" "true"
      "STRUCTURED_LOG_ADD_PROCESS_INFO" "true"
      "STRUCTURED_LOG_SAMPLE_RATE" "0.5"
      "CHERRYPY_STRUCTURED_LOG_SLOW_REQUEST_MS" "2000"
      "SQLOBJECT_STRUCTURED_LOG_SLOW_QUERY_MS" "200"}
    
    "production" {
      "STRUCTURED_LOG_LEVEL" "INFO"
      "STRUCTURED_LOG_FORMAT" "json"
      "STRUCTURED_LOG_DEV_MODE" "false"
      "STRUCTURED_LOG_ADD_HOSTNAME" "true"
      "STRUCTURED_LOG_ADD_PROCESS_INFO" "true"
      "STRUCTURED_LOG_ADD_THREAD_INFO" "true"
      "STRUCTURED_LOG_CORRELATION_ID" "true"
      "STRUCTURED_LOG_SAMPLE_RATE" "0.1"
      "STRUCTURED_LOG_REDACT_EMAILS" "true"
      "STRUCTURED_LOG_REDACT_IPS" "false"
      "CHERRYPY_STRUCTURED_LOG_ENABLED" "true"
      "CHERRYPY_STRUCTURED_LOG_SLOW_REQUEST_MS" "1000"
      "CHERRYPY_STRUCTURED_LOG_REQUEST_BODY" "false"
      "CHERRYPY_STRUCTURED_LOG_RESPONSE_BODY" "false"
      "SQLOBJECT_STRUCTURED_LOG_ENABLED" "true"
      "SQLOBJECT_STRUCTURED_LOG_SLOW_QUERY_MS" "100"}})
  
  ;; Get preset for environment
  (setv preset (get presets env {}))
  
  ;; Apply overrides
  (.update preset overrides)
  
  ;; Set environment variables (only if not already set)
  (for [[key value] (.items preset)]
    (when (not (in key os.environ))
      (setv (get os.environ key) (str value))))
  
  ;; Run setup
  (setup-from-environment))

(defn quick-setup [app-name &optional [env None]]
  "Quickest possible setup with just an app name
  
  Args:
      app-name: Name of your application
      env: Optional environment (auto-detected if not provided)
  
  Returns:
      Logger instance ready to use
  
  Usage:
      (import structured_logging.batteries [quick-setup])
      (setv logger (quick-setup 'myapp'))
      (.info logger 'Application started')"
  
  ;; Auto-detect environment if not provided
  (when (is env None)
    (setv env (os.environ.get "ENV" 
                (os.environ.get "ENVIRONMENT"
                  (os.environ.get "APP_ENV" "development")))))
  
  ;; Set app name
  (setv (get os.environ "STRUCTURED_LOG_APP_NAME") app-name)
  
  ;; Setup with defaults for environment
  (setv config (with-defaults env))
  
  ;; Return a logger for the app
  ((get config "get_logger") app-name))

(defn detect-frameworks []
  "Detect which frameworks are available for integration
  
  Returns:
      Dictionary with framework availability"
  
  (setv frameworks {})
  
  ;; Check for CherryPy
  (try
    (import cherrypy)
    (setv (get frameworks "cherrypy") True)
    (setv (get frameworks "cherrypy_version") cherrypy.__version__)
    (except [ImportError]
      (setv (get frameworks "cherrypy") False)))
  
  ;; Check for SQLObject
  (try
    (import sqlobject)
    (setv (get frameworks "sqlobject") True)
    (setv (get frameworks "sqlobject_version") sqlobject.__version__)
    (except [ImportError]
      (setv (get frameworks "sqlobject") False)))
  
  frameworks)

(defn print-configuration []
  "Print current configuration for debugging"
  (setv config (EnvironmentConfig))
  
  (print "\n=== Current Structured Logging Configuration ===")
  (print "\nCore Settings:")
  (for [[key value] (.items config.config)]
    (print f"  {key}: {value}"))
  
  (print "\nCherryPy Settings:")
  (for [[key value] (.items config.cherrypy-config)]
    (print f"  {key}: {value}"))
  
  (print "\nSQLObject Settings:")
  (for [[key value] (.items config.sqlobject-config)]
    (print f"  {key}: {value}"))
  
  (print "\nDetected Frameworks:")
  (setv frameworks (detect-frameworks))
  (for [[framework available] (.items frameworks)]
    (print f"  {framework}: {available}"))
  
  (print "================================================\n"))

(defn validate-configuration []
  "Validate current environment configuration
  
  Returns:
      Tuple of (is_valid, errors)"
  
  (setv errors [])
  (setv warnings [])
  
  (try
    (setv config (EnvironmentConfig))
    
    ;; Check if frameworks are enabled but not installed
    (setv frameworks (detect-frameworks))
    
    (when (and (get config.cherrypy-config "ENABLED")
               (not (get frameworks "cherrypy")))
      (.append warnings "CherryPy integration enabled but CherryPy not installed"))
    
    (when (and (get config.sqlobject-config "ENABLED")
               (not (get frameworks "sqlobject")))
      (.append warnings "SQLObject integration enabled but SQLObject not installed"))
    
    ;; Check for conflicting settings
    (when (and (= (get config.config "FORMAT") "pretty")
               (= (get config.config "ENV") "production"))
      (.append warnings "Pretty format in production is not recommended"))
    
    ;; Check for missing app name in production
    (when (and (= (get config.config "ENV") "production")
               (= (get config.config "APP_NAME") "app"))
      (.append warnings "Default app name 'app' used in production"))
    
    (except [e Exception]
      (.append errors (str e))))
  
  (setv is-valid (= (len errors) 0))
  
  (, is-valid {"errors" errors "warnings" warnings}))

;; Convenience function for testing
(defn reset-configuration []
  "Reset configuration (mainly for testing)"
  (global _configured _configuration)
  (setv _configured False)
  (setv _configuration None))

;; Export functions
(setv __all__ ["setup-from-environment" "with-defaults" "quick-setup"
               "detect-frameworks" "print-configuration" 
               "validate-configuration" "reset-configuration"])
