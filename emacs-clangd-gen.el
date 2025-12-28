;;; emacs-clangd-gen.el --- Generate clangd configuration -*- lexical-binding: t -*-

;; Author: Calle Olsen
;; Maintainer: Calle Olsen
;; Version: version
;; Package-Requires: (s)
;; Homepage: https://cocode.se
;; Keywords: clangd emacs-lisp

;;; Commentary:
;; This Emacs Lisp package generates a project-specific .clangd configuration
;; file, facilitating enhanced clangd features within Emacs for C/C++ development.
;; It automatically discovers compiler-specific include paths and allows for the
;; exclusion of problematic compiler flags and inclusion of custom settings
;; like clang-tidy configurations.
;; Its a short hack, and was created to be able to use clangd together with
;; esp-idf, but should work with any sort of cross compiler setup.
;; I was kind of lazy with the additional flags, but they serve the purpose
;; for now.
;;

;; commentary

;;; Code:
(require 's)

(defgroup emacs-clangd-gen nil
  "Generate clangd configuration files for C/C++ projects."
  :group 'tools
  :prefix "emacs-clangd-gen-")

(defcustom emacs-clangd-gen-rejected-compiler-flags
  '("-fmacro-prefix-map*"
    "-fno-shrink-wrap"
    "-fno-tree-switch-conversion"
    "-fstrict-volatile-bitfields"
    "-march=*"
    "-mabi=*")
  "List of compiler flags to exclude from the .clangd configuration.
These flags are typically incompatible with clangd or cause issues."
  :type '(repeat string)
  :group 'emacs-clangd-gen)

(defcustom emacs-clangd-gen-added-compiler-flags
  '("--target=riscv32-esp-elf")
  "List of additional compiler flags to add to the .clangd configuration.
These flags are added to help clangd understand the target environment."
  :type '(repeat string)
  :group 'emacs-clangd-gen)

(defcustom emacs-clangd-gen-additional-clangd-config
  '("Diagnostics:
   UnusedIncludes: Strict
   MissingIncludes: Strict
   ClangTidy:
     Add:
       - modernize*
       - bugprone-*
       - performance-*
       - readability-braces-around-statements
       - readability-simplify-boolean-expr
     Remove:
       - modernize-use-trailing-return-type
       - performance-no-int-to-ptr
"
    "Completion:
  AllScopes: Yes
  ArgumentLists: FullPlaceholders
  HeaderInsertion: IWYU
  CodePatterns: All
")
  "Additional YAML configuration blocks to append to .clangd file.
Each element should be a valid YAML string."
  :type '(repeat string)
  :group 'emacs-clangd-gen)

;; (defvar rejected-compiler-flags '("-fmacro-prefix-map*"
;;                                  "-fno-shrink-wrap"
;;                                  "-fno-tree-switch-conversion"
;;                                  "-fstrict-volatile-bitfields"
;;                                  "-march=*"
;;                                  "-mabi=*"))

;; (defvar added-compiler-flags '("--target=riscv32-esp-elf"))

;; (defvar additional-clangd-config '(
;; "Diagnostics:
;;    UnusedIncludes: Strict
;;    MissingIncludes: Strict
;;    ClangTidy:
;;      Add:
;;        - modernize*
;;        - bugprone-*
;;        - performance-*
;;        - readability-braces-around-statements
;;        - readability-simplify-boolean-expr
;;      Remove:
;;        - modernize-use-trailing-return-type
;;        - performance-no-int-to-ptr
;; "
;; "Completion:
;;   AllScopes: Yes
;;   ArgumentLists: FullPlaceholders
;;   HeaderInsertion: IWYU
;;   CodePatterns: All
;; "
;; ))


(defun write-clangd-yaml (project-path includes-list list-of-remove-flags added-compiler-flags)
  "Write a .clangd file in the project path with the given include paths and remove flags."
    (with-temp-file (concat (file-name-as-directory project-path) ".clangd")
      (insert "CompileFlags:\n")
      (insert "  BuiltinHeaders: QueryDriver\n")
      (insert "  Add: [\n")
      (dolist (compile-flag added-compiler-flags)
        (insert (format "    \"%s\",\n" compile-flag)))
      (dolist (include-path includes-list)
        (insert (format "    \"-I%s\",\n" include-path)))
      (insert "  ]\n")
      (when list-of-remove-flags
        (insert "  Remove: [\n")
        (dolist (remove-flag list-of-remove-flags)
          (insert (format "    \"%s\",\n" remove-flag)))
        (insert "  ]\n" ))
      (dolist (addition additional-clangd-config)
        (insert (format "%s\n" addition))
        )
      ))


(defun find-implicit-compile-includes (compiler)
  "Find the implicit include paths used by the compiler."
  (let* ((compiler-output (shell-command-to-string (format "%s -E -x c++ - -v < /dev/null 2>&1" compiler)))
         (include-paths nil))
    (with-temp-buffer
      (insert compiler-output)
      (goto-char (point-min))
      (when (re-search-forward "#include <...> search starts here:" nil t)
        (forward-line 1)
        (while (and (not (looking-at "End of search list\\."))
                    (not (eobp)))
          (when (looking-at "^[ \t]*\\(/[^\n]*\\)")
            (push (string-trim (match-string 1)) include-paths))
          (forward-line 1))))
    (nreverse include-paths)))



(defun find-exec-path (exec-name)
  "find the full path of the executable, same as which in shell"
  (let ((exec-path (executable-find exec-name)))
    (if exec-path
        exec-path
      (message "Executable %s not found in PATH" exec-name)
      nil))
  )

(defun emacs-clangd-generator (project-root compiler)
  "docstring"
  (interactive "DProject root: \nsCompiler: ")
  (let* (
         (compiler-path (find-exec-path compiler))
         ;; (sysroot-path (s-chop-suffix (format "/bin/%s" compiler)
         ;;                              compiler-path))
         (implicit-includes (find-implicit-compile-includes compiler))

         )
    (write-clangd-yaml project-root implicit-includes rejected-compiler-flags added-compiler-flags)
    ))



(provide 'emacs-clangd-gen)

;;; emacs-clangd-gen.el ends here
