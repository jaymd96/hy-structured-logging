#!/usr/bin/env hy

(import hy-structured-logging.structured-logging :as log)
(import hy-structured-logging.batteries :as batteries)
(import json)
(import sys)
(import traceback)

(defn demo-basic-logging []
  "Demonstrate basic logging functionality"
  (print "\n=== Basic Logging Demo ===\n")
  
  (log.init-logging :level "INFO" :format "json")
  
  (log.info "Application started" {"version" "1.0.0" "mode" "demo"})
  (log.debug "This won't show in INFO level" {"detail" "hidden"})
  (log.warning "This is a warning" {"threshold" 0.8 "current" 0.85})
  (log.error "An error occurred" {"error_code" "E001" "module" "demo"}))

(defn demo-context-logging []
  "Demonstrate logging with context"
  (print "\n=== Context Logging Demo ===\n")
  
  (log.with-context {"user_id" "12345" "session" "abc-def-ghi"}
    (log.info "User logged in" {"ip" "192.168.1.1"})
    (log.info "User performed action" {"action" "view_dashboard"})
    
    (log.with-context {"request_id" "req-001"}
      (log.info "Processing request" {"endpoint" "/api/data"})
      (log.info "Request completed" {"status" 200 "duration_ms" 145}))))

(defn demo-batteries []
  "Demonstrate batteries module features"
  (print "\n=== Batteries Module Demo ===\n")
  
  (let [timer (batteries.Timer "data_processing")]
    (batteries.time-function batteries.example-slow-function 2)
    
    (with [t timer]
      (print "Simulating data processing...")
      (batteries.example-slow-function 1))
    
    (log.info "Timer stats" {"elapsed" (.elapsed timer)})))

(defn demo-error-handling []
  "Demonstrate error logging"
  (print "\n=== Error Handling Demo ===\n")
  
  (try
    (/ 1 0)
    (except [ZeroDivisionError e]
      (log.error "Division by zero caught" 
                 {"error" (str e)
                  "traceback" (traceback.format-exc)}))))

(defn demo-structured-output []
  "Demonstrate different output formats"
  (print "\n=== Output Format Demo ===\n")
  
  (print "JSON format:")
  (log.init-logging :level "INFO" :format "json")
  (log.info "JSON message" {"key" "value"})
  
  (print "\nText format:")
  (log.init-logging :level "INFO" :format "text")
  (log.info "Text message" {"key" "value"})
  
  (print "\nJSON format again:")
  (log.init-logging :level "INFO" :format "json")
  (log.info "Back to JSON" {"nested" {"data" [1 2 3]}}))

(defn main []
  "Run all demos"
  (print "Hy Structured Logging Demo")
  (print "=" (* 40))
  
  (demo-basic-logging)
  (demo-context-logging)
  (demo-batteries)
  (demo-error-handling)
  (demo-structured-output)
  
  (print "\n" "=" (* 40))
  (print "Demo completed!"))

(when (= __name__ "__main__")
  (main))