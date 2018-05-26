;; Lisp image build script
;;   run with `sbcl --no-sysinit --no-userinit --load`

(defpackage #:jpc.core
  (:use #:common-lisp))
(in-package #:jpc.core)

(defvar *user-lisp-directory*
  (merge-pathnames ".common-lisp/" (user-homedir-pathname)))
(defvar *asdf-file*
  (merge-pathnames "asdf.lisp" *user-lisp-directory*))
(defvar *quicklisp-file*
  (merge-pathnames "quicklisp/setup.lisp" *user-lisp-directory*))
(defvar *image-name*
  (string-downcase (package-name *package*)))
(defvar *image-timestamp*
  (get-universal-time))

(defmacro message (format &rest args)
  `(format *error-output* (concatenate 'string "!! " ,format "~%") ,@args))

(defun format-timestamp (stream time)
  (multiple-value-bind (se mi hr dd mm yyyy)
      (decode-universal-time time)
    (format stream "~D-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D" yyyy mm dd hr mi se)))

(unless (probe-file *asdf-file*)
  (message "Could not find ASDF at path ~A." *asdf-file*)
  (sb-ext:exit :code 1))
(unless (probe-file *quicklisp-file*)
  (message "Could not find Quicklisp at path ~A." *quicklisp-file*)
  (sb-ext:exit :code 1))

#-asdf (load *asdf-file*)
(require :asdf)
(message "+asdf ~A" asdf/upgrade:*asdf-version*)

(load *quicklisp-file*)
(require :quicklisp)
(message "+quicklisp ~A" ql-info:*version*)

(defvar *quicklisp-dist-version*
  (ql:dist-version "quicklisp"))

(defvar *toplevel-init-hooks*
  '())

(defun toplevel-init ()
  (dolist (hook *toplevel-init-hooks*) (funcall hook))
  (sb-impl::toplevel-init))

(defun ensure-find-package (designator)
  (let ((p (find-package designator)))
    (unless p (error "Cannot find a package named ~A." designator))
    (the package p)))

(let ((cl-package (ensure-find-package '#:common-lisp))
      (user-package (ensure-find-package '#:common-lisp-user)))
  (dolist (package (delete cl-package (package-use-list user-package)))
    (unuse-package package user-package)))

(defun package-symbols-import (source destination)
  (setf source (ensure-find-package source)
        destination (ensure-find-package destination))
  (with-package-iterator (generate source :external :inherited)
    (loop (multiple-value-bind (more? symbol access package)
              (generate)
            (declare (ignore access package))
            (unless more? (return))
            (let ((existing (find-symbol (symbol-name symbol) destination)))
              (cond ((and existing (not (eq symbol existing)))
                     (message "not importing symbol ~A due to conflict with ~A."
                              symbol (package-name (symbol-package existing))))
                    (t (import symbol destination))))))))

(macrolet ((load-system (sys)
             (check-type sys (or string symbol))
             `(ql:quickload ',sys))
           (use-system (sys &rest pkgs)
             (check-type sys (or string symbol))
             (setf pkgs (or pkgs (list sys)))
             (dolist (pkg pkgs) (check-type pkg (or string symbol)))
             `(progn (ql:quickload ',sys)
                     ,@(loop :for pkg :in pkgs :collect `(package-symbols-import ',pkg '#:common-lisp-user)))))
  (use-system #:uiop)
  (use-system #:alexandria)
  (use-system #:iterate)
  (use-system #:anaphora)
  (use-system #:let-plus)
  (use-system #:nibbles)
  (use-system #:trivia)
  (use-system #:babel)
  (use-system #:bordeaux-threads)
  (use-system #:flexi-streams)
  (use-system #:usocket)
  (use-system #:closer-mop)
  (use-system #:named-readtables)
  (use-system #:trivial-backtrace)
  (use-system #:trivial-garbage)
  (use-system #:trivial-gray-streams)
  (use-system #:macroexpand-dammit)
  (use-system #:log4cl)
  (use-system #:quri)
  (use-system #:rt)
  (use-system #:fare-utils)
  (use-system #:fare-memoization)
  (use-system #:command-line-arguments)
  (use-system #:narrowed-types)
  (use-system #:cl-ppcre)
  (use-system #:colorize)
  (use-system #:cffi)
  (use-system #:iolib)
  (use-system #:ironclad)
  (use-system #:cl-slice)
  (use-system #:cl-syntax)
  (use-system #:yacc)
  (load-system #:cl-syntax-annot)
  (load-system #:cl-syntax-interpol)
  (use-system #:quickproject)
  (load-system #:swank))

(macrolet ((initialize (&body body)
             `(push (lambda () ,@body) *toplevel-init-hooks*)))
  (initialize (message ".image ~A ~A"
                       *image-name* (format-timestamp nil *image-timestamp*)))
  (initialize (message ".implementation ~A ~A"
                       (lisp-implementation-type) (lisp-implementation-version)))
  (initialize (message "+asdf ~A" asdf/upgrade:*asdf-version*))
  (initialize (message "+quicklisp ~A dist ~A"
                       ql-info:*version* *quicklisp-dist-version*))
  (initialize (message "+syntax cl-annot")
              (cl-syntax:use-syntax :cl-annot))
  (initialize (message "+syntax cl-interpol")
              (cl-syntax:use-syntax :cl-interpol)))

(setf *toplevel-init-hooks* (nreverse *toplevel-init-hooks*))

(let ((toplevel-fn #'toplevel-init)
      (output-pn (make-pathname :defaults *load-pathname* :type nil :version nil))
      (build-package *package*))
  (let ((*package* (ensure-find-package '#:common-lisp-user)))
    (message "deleting package ~A" (package-name build-package))
    (delete-package build-package)
    (message "building image ~A" output-pn)
    (sb-ext:save-lisp-and-die output-pn :toplevel toplevel-fn :executable t)))
