#!/usr/local/bin/sbcl --script

(load "~/quicklisp/setup.lisp")
(quicklisp:quickload "cl-fad" :silent t)
(quicklisp:quickload "cl-ppcre" :silent t)
(use-package :cl-fad)
(use-package :cl-ppcre)
(load "model-parameters.lisp")
(load "required-tile-iterator.lisp")

(defun directory* (directory file-mask)
  (let* ((file-mask (concatenate 'string
				 (cl-ppcre:regex-replace-all "\\*" (cl-ppcre:regex-replace "\\." file-mask "\\.") ".*")
				 "$"))
	 (scanner (cl-ppcre:create-scanner file-mask))
	 (files (remove-if-not (lambda (x) (cl-ppcre:scan scanner (file-namestring x)))
			       (cl-fad:list-directory directory))))
    files))

(defun make-files ()
  (destructuring-bind (year month day hour h outputfile)
      (or (cdr *posix-argv*) '("2018" "08" "18" "18" "03" "blarg.txt"))
    (let* ((files (directory* *directory* (file-glob-for year month day hour h))))
      (format t "Processing ~A files for hour ~A into ~A~%" (length files) h outputfile)
      (with-open-file (str outputfile :direction :output :if-exists :supersede)
	(map nil (lambda (file)
		   (let ((f (file-namestring file))
			 (tile-iterator (only-required-tile-iterator)))
		     (labels ((do-it (&optional (limit 100))
				(let ((count 0))
				  (loop :for tile = (funcall tile-iterator)
				     :if (and (> count 0) (or (= count limit) (not tile))) :collect (enough-namestring file)
				     :while (and tile (< count limit))
				     :collect
				     (destructuring-bind (tile-id (lon1 lat1 lon2 lat2)) tile
				       (format nil "-small_grib ~f:~f ~f:~f ~A/~A/~A "
					       (- lon1 0.2) (+ lon2 0.2) lat1 lat2 *tiledir* tile-id f))
				     ;;:finally (when (> count 0) (format t "Wrote ~A lines ~%" count))
				     :do (incf count)))))
		       (write-line 
			(apply #'concatenate 'string
			       "wgrib2 -v0 -set_grib_type simple "
			       (do-it 400))
			str)
		       (let ((res (do-it 100000)))
			 (when res
			   (write-line 
			    (apply #'concatenate 'string
				   "wgrib2 -v0 -set_grib_type simple "
				   res)
			    str))))))
		   files)))))

(make-files)
