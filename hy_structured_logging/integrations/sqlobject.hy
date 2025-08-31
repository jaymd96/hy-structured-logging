;;; integrations/sqlobject.hy
;;; SQLObject integration for structured logging

(import time)
(import threading)
(import logging)
(import structured_logging [StructuredLogger])

(defclass SQLObjectLoggerAdapter [logging.Handler]
  "Adapter to route SQLObject debug output to structured logging"
  
  (defn __init__ [self logger-factory config]
    (super.__init__)
    (setv self.logger-factory logger-factory)
    (setv self.config config)
    (setv self.query-logger (logger-factory.get-logger "sqlobject.query"))
    (setv self.slow-query-logger (logger-factory.get-logger "sqlobject.slow_query"))
    (setv self.local (threading.local)))
  
  (defn emit [self record]
    "Process SQLObject log records"
    (setv message record.getMessage)
    
    ;; Parse SQL query from message
    (when (self.is-sql-query message)
      (self.log-query message record))
    
    ;; Parse connection events
    (when (self.is-connection-event message)
      (self.log-connection message record))
    
    ;; Parse transaction events
    (when (self.is-transaction-event message)
      (self.log-transaction message record)))
  
  (defn is-sql-query [self message]
    "Check if message is a SQL query"
    (setv sql-keywords ["SELECT" "INSERT" "UPDATE" "DELETE" "CREATE" "DROP" "ALTER"])
    (any (lfor keyword sql-keywords (.startswith (.upper message) keyword))))
  
  (defn is-connection-event [self message]
    "Check if message is a connection event"
    (or (in "connect" (.lower message))
        (in "disconnect" (.lower message))
        (in "connection" (.lower message))))
  
  (defn is-transaction-event [self message]
    "Check if message is a transaction event"
    (or (in "BEGIN" message)
        (in "COMMIT" message)
        (in "ROLLBACK" message)))
  
  (defn log-query [self message record]
    "Log SQL query with timing and details"
    ;; Start timing if not already started
    (when (not (hasattr self.local "query_start"))
      (setv self.local.query_start (time.time)))
    
    ;; Parse query and parameters
    (setv query (self.clean-query message))
    (setv params (self.extract-params message))
    
    ;; Calculate duration if this is a result message
    (setv duration-ms None)
    (when (and (hasattr self.local "query_start")
               (or (in "rows" (.lower message))
                   (in "affected" (.lower message))))
      (setv duration-ms (* (- (time.time) self.local.query_start) 1000))
      (del self.local.query_start))
    
    ;; Build log fields
    (setv fields {
      "query" query
      "params" params
      "thread_id" (threading.get-ident)})
    
    (when duration-ms
      (setv (get fields "duration_ms") duration-ms)
      
      ;; Check for slow query
      (setv slow-threshold (get self.config.sqlobject-config "SLOW_QUERY_MS"))
      (when (> duration-ms slow-threshold)
        (.warning self.slow-query-logger "Slow query detected"
                  #** fields
                  :threshold_ms slow-threshold)
        (return)))
    
    ;; Log query
    (.debug self.query-logger "SQL Query" #** fields))
  
  (defn log-connection [self message record]
    "Log connection events"
    (setv conn-logger (self.logger-factory.get-logger "sqlobject.connection"))
    
    (setv fields {
      "event_type" (cond
        [(in "connect" (.lower message)) "connect"]
        [(in "disconnect" (.lower message)) "disconnect"]
        [True "connection_event"])
      "message" message
      "thread_id" (threading.get-ident)})
    
    (.info conn-logger "Connection event" #** fields))
  
  (defn log-transaction [self message record]
    "Log transaction events"
    (setv tx-logger (self.logger-factory.get-logger "sqlobject.transaction"))
    
    (setv fields {
      "event_type" (cond
        [(in "BEGIN" message) "begin"]
        [(in "COMMIT" message) "commit"]
        [(in "ROLLBACK" message) "rollback"]
        [True "transaction_event"])
      "message" message
      "thread_id" (threading.get-ident)})
    
    ;; Set transaction ID for correlation
    (when (in "BEGIN" message)
      (import uuid)
      (setv self.local.transaction_id (str (uuid.uuid4)))
      (setv (get fields "transaction_id") self.local.transaction_id))
    
    (when (hasattr self.local "transaction_id")
      (setv (get fields "transaction_id") self.local.transaction_id))
    
    ;; Clear transaction ID on commit/rollback
    (when (or (in "COMMIT" message) (in "ROLLBACK" message))
      (when (hasattr self.local "transaction_id")
        (del self.local.transaction_id)))
    
    (.info tx-logger "Transaction event" #** fields))
  
  (defn clean-query [self message]
    "Extract clean SQL query from message"
    ;; Remove timing info and other metadata
    (setv query message)
    (when (in ";" query)
      (setv query (.split query ";") [0]))
    (.strip query))
  
  (defn extract-params [self message]
    "Extract query parameters from message"
    ;; Look for parameters in parentheses or after VALUES
    (import re)
    (setv params [])
    
    (setv values-match (re.search r"VALUES\s*\((.*?)\)" message))
    (when values-match
      (setv params-str (values-match.group 1))
      (setv params (.split params-str ",")))
    
    (lfor p params (.strip p))))

(defclass SignalListener []
  "Listener for SQLObject signals to create audit trail"
  
  (defn __init__ [self logger-factory config]
    (setv self.logger-factory logger-factory)
    (setv self.config config)
    (setv self.audit-logger (logger-factory.get-logger "sqlobject.audit")))
  
  (defn on-row-created [self instance kwargs post-funcs]
    "Log row creation"
    (when (get self.config.sqlobject-config "AUDIT")
      (setv fields {
        "table" (. instance.__class__ __name__)
        "row_id" (getattr instance "id" None)
        "values" (self.get-field-values instance)
        "event" "created"})
      
      (.info self.audit-logger "Row created" #** fields)))
  
  (defn on-row-updated [self instance kwargs]
    "Log row updates"
    (when (get self.config.sqlobject-config "AUDIT")
      ;; Get changed fields
      (setv changed-fields [])
      (setv old-values {})
      (setv new-values {})
      
      (for [[key value] (.items kwargs)]
        (.append changed-fields key)
        (setv (get new-values key) value)
        ;; Try to get old value
        (when (hasattr instance key)
          (setv (get old-values key) (getattr instance key))))
      
      (setv fields {
        "table" (. instance.__class__ __name__)
        "row_id" (getattr instance "id" None)
        "changed_fields" changed-fields
        "old_values" old-values
        "new_values" new-values
        "event" "updated"})
      
      (.info self.audit-logger "Row updated" #** fields)))
  
  (defn on-row-deleted [self instance]
    "Log row deletion"
    (when (get self.config.sqlobject-config "AUDIT")
      (setv fields {
        "table" (. instance.__class__ __name__)
        "row_id" (getattr instance "id" None)
        "values" (self.get-field-values instance)
        "event" "deleted"})
      
      (.info self.audit-logger "Row deleted" #** fields)))
  
  (defn get-field-values [self instance]
    "Get all field values from an SQLObject instance"
    (setv values {})
    (try
      ;; Get column values
      (for [col (. instance.__class__ sqlmeta columns)]
        (setv col-name (. col name))
        (when (hasattr instance col-name)
          (setv (get values col-name) (getattr instance col-name))))
      (except [e Exception]
        ;; Fallback to simple dict conversion
        (try
          (setv values (dict instance))
          (except [e Exception]
            (setv values {"error" "Could not extract values"})))))
    values))

(defclass ConnectionWrapper []
  "Wrapper for database connections to add logging"
  
  (defn __init__ [self connection logger-factory config]
    (setv self.connection connection)
    (setv self.logger-factory logger-factory)
    (setv self.config config)
    (setv self.logger (logger-factory.get-logger "sqlobject.connection"))
    (setv self.pool-logger (logger-factory.get-logger "sqlobject.pool")))
  
  (defn __getattr__ [self name]
    "Proxy all attributes to wrapped connection"
    (getattr self.connection name))
  
  (defn execute [self query &rest args &kwargs kwargs]
    "Wrap execute to log queries"
    (setv start-time (time.time))
    
    (try
      (setv result (self.connection.execute query #* args #** kwargs))
      (setv duration-ms (* (- (time.time) start-time) 1000))
      
      ;; Log successful query
      (setv fields {
        "query" query
        "args" args
        "duration_ms" duration-ms
        "success" True})
      
      ;; Check for slow query
      (setv slow-threshold (get self.config.sqlobject-config "SLOW_QUERY_MS"))
      (when (> duration-ms slow-threshold)
        (.warning self.logger "Slow query" #** fields :threshold_ms slow-threshold))
      (else
        (.debug self.logger "Query executed" #** fields))
      
      result
      
      (except [e Exception]
        (setv duration-ms (* (- (time.time) start-time) 1000))
        
        ;; Log failed query
        (.error self.logger "Query failed"
                :query query
                :args args
                :duration_ms duration-ms
                :error (str e)
                :success False)
        (raise)))))

(defn configure-sqlobject [logger-factory config]
  "Configure SQLObject with structured logging
  
  Args:
      logger-factory: LoggerFactory instance
      config: EnvironmentConfig instance
  
  Returns:
      Dictionary with configured components"
  
  ;; Create logger adapter
  (setv adapter (SQLObjectLoggerAdapter logger-factory config))
  
  ;; Configure SQLObject to use our logger
  (setv sqlobject-logger (logging.getLogger "sqlobject"))
  (sqlobject-logger.addHandler adapter)
  (sqlobject-logger.setLevel logging.DEBUG)
  
  ;; Create signal listener if signals enabled
  (setv signal-listener None)
  (when (get config.sqlobject-config "SIGNALS")
    (setv signal-listener (SignalListener logger-factory config))
    
    ;; Register signal listeners
    (try
      (import sqlobject.events [listen RowCreatedSignal RowUpdateSignal RowDestroySignal])
      
      ;; Register for all SQLObject classes
      (listen signal-listener.on-row-created None RowCreatedSignal)
      (listen signal-listener.on-row-updated None RowUpdateSignal)
      (listen signal-listener.on-row-deleted None RowDestroySignal)
      
      (except [ImportError]
        (print "Warning: SQLObject signals not available"))))
  
  ;; Log configuration
  (setv config-logger (logger-factory.get-logger "sqlobject.config"))
  (.info config-logger "SQLObject logging configured"
         :queries_enabled (get config.sqlobject-config "QUERIES")
         :slow_query_threshold (get config.sqlobject-config "SLOW_QUERY_MS")
         :audit_enabled (get config.sqlobject-config "AUDIT")
         :signals_enabled (get config.sqlobject-config "SIGNALS"))
  
  ;; Return configuration
  {"adapter" adapter
   "signal_listener" signal-listener
   "logger" sqlobject-logger})

(defn create-logged-connection [connection-string logger-factory config]
  "Create a database connection with logging
  
  Args:
      connection-string: SQLObject connection string
      logger-factory: LoggerFactory instance
      config: EnvironmentConfig instance
  
  Returns:
      Logged connection object"
  
  ;; Parse and modify connection string to add logging
  (setv modified-string connection-string)
  
  ;; Add debug and logger parameters if not present
  (when (not (in "debug=" modified-string))
    (setv separator (if (in "?" modified-string) "&" "?"))
    (setv modified-string (+ modified-string separator "debug=1")))
  
  (when (not (in "logger=" modified-string))
    (setv modified-string (+ modified-string "&logger=sqlobject")))
  
  ;; Create connection
  (import sqlobject)
  (setv connection (sqlobject.connectionForURI modified-string))
  
  ;; Wrap if connection logging enabled
  (when (get config.sqlobject-config "CONNECTIONS")
    (setv connection (ConnectionWrapper connection logger-factory config)))
  
  connection)

;; Export components
(setv __all__ ["SQLObjectLoggerAdapter" "SignalListener" "ConnectionWrapper"
               "configure-sqlobject" "create-logged-connection"])
