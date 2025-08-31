#!/usr/bin/env hy

(import doit)
(import os)
(import sys)
(import shutil)
(import subprocess)

(defn run-command [cmd]
  "Run a shell command and return the result"
  (subprocess.run cmd :shell True :check True))

(defn task-clean []
  "Clean build artifacts and cache"
  {"actions" [(fn []
                (for [dir ["build" "dist" "*.egg-info" "__pycache__" ".pytest_cache"]]
                  (when (os.path.exists dir)
                    (if (os.path.isdir dir)
                      (shutil.rmtree dir)
                      (os.remove dir))))
                (print "Cleaned build artifacts"))]
   "verbosity" 2
   "doc" "Remove build artifacts, dist, egg-info, and cache directories"})

(defn task-lint []
  "Run code quality checks"
  {"actions" [(fn []
                (print "Checking Hy syntax...")
                (for [file (os.listdir "hy_structured_logging")]
                  (when (.endswith file ".hy")
                    (let [filepath (os.path.join "hy_structured_logging" file)]
                      (try
                        (with [f (open filepath "r")]
                          (hy.read-many (.read f)))
                        (print f"  ✓ {filepath}")
                        (except [e Exception]
                          (print f"  ✗ {filepath}: {e}")
                          (raise e))))))
                (print "All Hy files passed syntax check"))]
   "verbosity" 2
   "doc" "Check Hy syntax in all package files"})

(defn task-test []
  "Run tests"
  {"actions" [(fn []
                (print "Running tests...")
                (try
                  (run-command "hy test_structured_logging.hy")
                  (print "✓ structured_logging tests passed")
                  (except [e Exception]
                    (print f"✗ structured_logging tests failed: {e}")))
                
                (try
                  (run-command "hy test_claude_subagent.hy")
                  (print "✓ claude_subagent tests passed")
                  (except [e Exception]
                    (print f"✗ claude_subagent tests failed: {e}"))))]
   "task_dep" ["lint"]
   "verbosity" 2
   "doc" "Run all test files"})

(defn task-build []
  "Build distribution packages"
  {"actions" [
     (fn [] (print "Building distribution packages..."))
     "python3 -m pip install --upgrade build"
     "python3 -m build"
     (fn [] (print "Build complete - check dist/ directory"))]
   "task_dep" ["clean" "test"]
   "targets" ["dist/*.whl" "dist/*.tar.gz"]
   "verbosity" 2
   "doc" "Build wheel and source distribution"})

(defn task-install []
  "Install package in development mode"
  {"actions" [
     "python3 -m pip install -e ."
     (fn [] (print "Package installed in development mode"))]
   "verbosity" 2
   "doc" "Install the package in editable/development mode"})

(defn task-install-prod []
  "Install package from built distribution"
  {"actions" [
     (fn []
       (if (os.path.exists "dist")
         (do
           (run-command "python3 -m pip uninstall -y hy-structured-logging")
           (run-command "python3 -m pip install dist/*.whl")
           (print "Package installed from distribution"))
         (print "No dist/ directory found. Run 'doit build' first")))]
   "task_dep" ["build"]
   "verbosity" 2
   "doc" "Install the package from the built wheel"})

(defn task-demo []
  "Run demonstration scripts"
  {"actions" [
     (fn [] (print "\n" "=" (* 50)))
     (fn [] (print "Running Hy demo..."))
     (fn [] (print "=" (* 50) "\n"))
     "hy demo/basic_usage.hy"
     (fn [] (print "\n" "=" (* 50)))
     (fn [] (print "Running Python demo..."))
     (fn [] (print "=" (* 50) "\n"))
     "python3 demo/advanced_usage.py"]
   "verbosity" 2
   "doc" "Run both Hy and Python demonstration scripts"})

(defn task-check-deps []
  "Check and install dependencies"
  {"actions" [
     "python3 -m pip install --upgrade pip"
     "python3 -m pip install hy>=0.28.0"
     "python3 -m pip install build twine"
     (fn [] (print "Dependencies checked and installed"))]
   "verbosity" 2
   "doc" "Ensure all required dependencies are installed"})

(defn task-docs []
  "Generate or update documentation"
  {"actions" [
     (fn []
       (print "Checking README.md exists...")
       (if (os.path.exists "README.md")
         (print "✓ README.md found")
         (print "✗ README.md not found")))
     (fn []
       (print "Checking demo documentation...")
       (if (os.path.exists "demo/README.md")
         (print "✓ demo/README.md found")
         (print "✗ demo/README.md not found")))]
   "verbosity" 2
   "doc" "Check documentation files"})

(defn task-version []
  "Show package version"
  {"actions" [
     (fn []
       (try
         (import toml)
         (let [config (toml.load "pyproject.toml")]
           (print f"Package version: {(get-in config [\"project\" \"version\"])}"))
         (except [ImportError]
           (print "Install toml: pip install toml")
           (print "Version is defined in pyproject.toml as 1.0.0"))))]
   "verbosity" 2
   "doc" "Display the current package version"})

(defn task-upload-test []
  "Upload package to TestPyPI"
  {"actions" [
     (fn [] (print "Uploading to TestPyPI..."))
     "python3 -m twine upload --repository testpypi dist/*"
     (fn [] (print "Upload to TestPyPI complete"))
     (fn [] (print "Install from TestPyPI with:"))
     (fn [] (print "  pip install -i https://test.pypi.org/simple/ hy-structured-logging"))]
   "task_dep" ["build"]
   "verbosity" 2
   "doc" "Upload distribution to TestPyPI (test repository)"})

(defn task-upload []
  "Upload package to PyPI"
  {"actions" [
     (fn [] 
       (print "=" (* 50))
       (print "WARNING: This will upload to the real PyPI!")
       (print "Make sure you have:")
       (print "  1. Updated the version in pyproject.toml")
       (print "  2. Tested the package thoroughly")
       (print "  3. Updated the README and documentation")
       (print "  4. Set up PyPI credentials (~/.pypirc or keyring)")
       (print "=" (* 50))
       (input "Press Enter to continue or Ctrl+C to cancel..."))
     "python3 -m twine upload dist/*"
     (fn [] (print "Upload to PyPI complete"))
     (fn [] (print "Install from PyPI with:"))
     (fn [] (print "  pip install hy-structured-logging"))]
   "task_dep" ["build"]
   "verbosity" 2
   "doc" "Upload distribution to PyPI (PRODUCTION - use with caution)"})

(defn task-dev []
  "Set up development environment"
  {"actions" [
     (fn [] (print "Setting up development environment..."))
     "task_dep" ["check-deps" "install" "lint" "test"]
     (fn [] (print "\nDevelopment environment ready!"))
     (fn [] (print "Run 'doit list' to see available tasks"))]
   "verbosity" 2
   "doc" "Complete development environment setup"})

(defn task-release []
  "Prepare a new release"
  {"actions" [
     (fn []
       (print "Release checklist:"))
     (fn [] (print "  [ ] Update version in pyproject.toml"))
     (fn [] (print "  [ ] Update CHANGELOG (if exists)"))
     (fn [] (print "  [ ] Run all tests"))
     (fn [] (print "  [ ] Update documentation"))
     (fn [] (print "  [ ] Commit all changes"))
     (fn [] (print "  [ ] Tag the release (git tag -a v1.0.0 -m 'Release v1.0.0')"))
     (fn [] (print "  [ ] Push tag (git push origin v1.0.0)"))
     (fn [] (print "\nWhen ready, run:"))
     (fn [] (print "  1. doit build    # Build distributions"))
     (fn [] (print "  2. doit upload-test  # Test on TestPyPI"))
     (fn [] (print "  3. doit upload   # Upload to PyPI"))]
   "verbosity" 2
   "doc" "Show release preparation checklist"})

(setv DOIT_CONFIG {"default_tasks" ["build"]})