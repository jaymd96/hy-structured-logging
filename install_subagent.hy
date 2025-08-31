#!/usr/bin/env hy
;;; install_subagent.hy
;;; Quick script to install the Claude Code subagent for structured logging

(import claude_subagent [install-subagent check-subagent-status])
(import sys)
(import os)

(defn main []
  (print "===========================================")
  (print "Structured Logging Claude Code Subagent Installer")
  (print "===========================================\n")
  
  ;; Check current status
  (print "Checking for existing installation...")
  (setv status (check-subagent-status))
  
  (if (get status "installed")
      (do
        (print f"ℹ️  Subagent already installed at: {(get status 'path')}")
        (print "\nWould you like to reinstall it? (y/n): " :end "")
        (setv response (.lower (.strip (input))))
        (when (= response "y")
          (print "\nReinstalling subagent...")
          (install-subagent "." True)))
      
      (if (get status "claude_dir")
          (do
            (print f"Found .claude directory at: {(get status 'claude_dir')}")
            (print "Installing subagent...")
            (install-subagent))
          
          (do
            (print "❌ No .claude directory found in current path or parent directories.\n")
            (print "Please ensure you're in a Claude Code project directory.")
            (print "If you haven't initialized Claude Code yet, run: claude code")
            (sys.exit 1))))
  
  (print "\n===========================================")
  (print "Installation complete!")
  (print "\nThe subagent is now available in Claude Code.")
  (print "It will automatically help with:")
  (print "  • Structured logging implementation")
  (print "  • Debugging logging issues")
  (print "  • Best practices and patterns")
  (print "  • Performance optimization")
  (print "\nYou can also invoke it explicitly:")
  (print "  'Ask the structured-logging-expert about...'")
  (print "==========================================="))

(when (= __name__ "__main__")
  (main))
