;;; test_claude_subagent.hy
;;; Tests for the Claude Code subagent module

(import claude_subagent [find-claude-directory ensure-agents-directory
                         create-logging-subagent-content check-subagent-status
                         install-subagent uninstall-subagent])
(import tempfile)
(import pathlib [Path])
(import shutil)
(import os)

(defclass TestClaudeSubagent []
  "Test cases for Claude subagent functionality"
  
  (defn setup [self]
    "Set up test environment with temporary directories"
    ;; Create a temporary directory for testing
    (setv self.temp-dir (Path (tempfile.mkdtemp)))
    (setv self.project-dir (.joinpath self.temp-dir "test-project"))
    (.mkdir self.project-dir)
    
    ;; Create a .claude directory structure
    (setv self.claude-dir (.joinpath self.project-dir ".claude"))
    (.mkdir self.claude-dir)
    (setv self.agents-dir (.joinpath self.claude-dir "agents"))
    
    ;; Change to project directory for tests
    (setv self.original-cwd (os.getcwd))
    (os.chdir (str self.project-dir)))
  
  (defn teardown [self]
    "Clean up test environment"
    ;; Restore original directory
    (os.chdir self.original-cwd)
    
    ;; Remove temporary directory
    (try
      (shutil.rmtree (str self.temp-dir))
      (except [e Exception]
        (print f"Warning: Could not clean up temp dir: {e}"))))
  
  (defn test-find-claude-directory [self]
    "Test finding .claude directory"
    (self.setup)
    
    ;; Test finding in current directory
    (setv found (find-claude-directory "."))
    (assert (not (is found None)))
    (assert (= (.name found) ".claude"))
    
    ;; Test finding from subdirectory
    (setv subdir (.joinpath self.project-dir "subdir"))
    (.mkdir subdir)
    (os.chdir (str subdir))
    
    (setv found (find-claude-directory "."))
    (assert (not (is found None)))
    (assert (.endswith (str found) ".claude"))
    
    ;; Test not finding (create isolated directory)
    (setv isolated (.joinpath self.temp-dir "isolated"))
    (.mkdir isolated)
    (os.chdir (str isolated))
    
    (setv found (find-claude-directory "."))
    (assert (is found None))
    
    (self.teardown)
    (print "✓ Find claude directory test passed"))
  
  (defn test-ensure-agents-directory [self]
    "Test ensuring agents directory exists"
    (self.setup)
    
    ;; Agents directory should not exist initially
    (assert (not (.exists self.agents-dir)))
    
    ;; Ensure it exists
    (setv agents-path (ensure-agents-directory self.claude-dir))
    
    (assert (.exists agents-path))
    (assert (= (.name agents-path) "agents"))
    (assert (.is-dir agents-path))
    
    ;; Running again should not cause issues
    (setv agents-path2 (ensure-agents-directory self.claude-dir))
    (assert (= agents-path agents-path2))
    
    (self.teardown)
    (print "✓ Ensure agents directory test passed"))
  
  (defn test-subagent-content-generation [self]
    "Test that subagent content is properly generated"
    (setv content (create-logging-subagent-content))
    
    ;; Check that content contains expected sections
    (assert (in "name: structured-logging-expert" content))
    (assert (in "description:" content))
    (assert (in "tools:" content))
    (assert (in "# Structured Logging Expert for Hy" content))
    (assert (in "## Your Expertise" content))
    (assert (in "## Implementation Guidelines" content))
    (assert (in "## Common Issues and Solutions" content))
    
    ;; Check for specific technical content
    (assert (in "StructuredLogger" content))
    (assert (in "LoggerFactory" content))
    (assert (in "DEBUG" content))
    (assert (in "INFO" content))
    (assert (in "ERROR" content))
    
    (print "✓ Subagent content generation test passed"))
  
  (defn test-check-status [self]
    "Test checking subagent installation status"
    (self.setup)
    
    ;; Initially not installed
    (setv status (check-subagent-status "."))
    (assert (not (get status "installed")))
    (assert (not (is (get status "claude_dir") None)))
    
    ;; Create subagent file manually
    (.mkdir self.agents-dir)
    (setv subagent-file (.joinpath self.agents-dir "structured-logging-expert.md"))
    (with [f (open subagent-file "w")]
      (.write f "test content"))
    
    ;; Check status again
    (setv status (check-subagent-status "."))
    (assert (get status "installed"))
    (assert (= (str subagent-file) (get status "path")))
    (assert (> (get status "size") 0))
    
    (self.teardown)
    (print "✓ Check status test passed"))
  
  (defn test-install-uninstall [self]
    "Test installing and uninstalling the subagent"
    (self.setup)
    
    ;; Install subagent
    (setv install-path (install-subagent "." False))
    (assert (not (is install-path None)))
    (assert (.exists install-path))
    
    ;; Verify content
    (with [f (open install-path "r")]
      (setv content (.read f)))
    (assert (in "structured-logging-expert" content))
    
    ;; Check status shows installed
    (setv status (check-subagent-status))
    (assert (get status "installed"))
    
    ;; Try installing again without force (should skip)
    (setv install-path2 (install-subagent "." False))
    (assert (= install-path install-path2))
    
    ;; Install with force (should overwrite)
    (setv install-path3 (install-subagent "." True))
    (assert (= install-path install-path3))
    
    ;; Uninstall
    (setv uninstalled (uninstall-subagent "."))
    (assert uninstalled)
    (assert (not (.exists install-path)))
    
    ;; Check status shows not installed
    (setv status (check-subagent-status))
    (assert (not (get status "installed")))
    
    ;; Try uninstalling again (should fail gracefully)
    (setv uninstalled2 (uninstall-subagent "."))
    (assert (not uninstalled2))
    
    (self.teardown)
    (print "✓ Install/uninstall test passed"))
  
  (defn test-no-claude-directory [self]
    "Test behavior when no .claude directory exists"
    (self.setup)
    
    ;; Remove .claude directory
    (shutil.rmtree (str self.claude-dir))
    
    ;; Try to install
    (setv result (install-subagent "." False))
    (assert (is result None))
    
    ;; Check status
    (setv status (check-subagent-status "."))
    (assert (not (get status "installed")))
    (assert (is (get status "claude_dir") None))
    
    ;; Try to uninstall
    (setv result (uninstall-subagent "."))
    (assert (not result))
    
    (self.teardown)
    (print "✓ No claude directory test passed")))

;; Run all tests
(defn run-tests []
  (print "Running Claude Subagent Tests\n")
  
  (setv tests (TestClaudeSubagent))
  
  (print "Testing Core Functions:")
  (.test-find-claude-directory tests)
  (.test-ensure-agents-directory tests)
  (.test-subagent-content-generation tests)
  
  (print "\nTesting Status and Installation:")
  (.test-check-status tests)
  (.test-install-uninstall tests)
  (.test-no-claude-directory tests)
  
  (print "\n✅ All Claude subagent tests passed!"))

(when (= __name__ "__main__")
  (run-tests))
