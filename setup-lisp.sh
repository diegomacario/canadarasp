#!/bin/sh
# Create the ~/.config/common-lisp/source-registry.conf.d directory if it doesn't already exist.
# This directory is used to configure the Common Lisp source registry.
mkdir -p ~/.config/common-lisp/source-registry.conf.d

cd /home/ubuntu

# Support for reading and writing PNGs
git clone https://github.com/ajberkley/cl-png.git
# Support for reading and writing geospatial data
git clone https://github.com/ajberkley/cl-gdal.git
# Support for shared memory caching
git clone https://github.com/ajberkley/mmap-shared-cache.git

# These lines create three configuration files in
# the ~/.config/common-lisp/source-registry.conf.d directory.
# These configuration files specify the locations of the cl-png, cl-gdal, and
# mmap-shared-cache libraries in the Common Lisp source registry.
echo '(:tree "/home/ubuntu/cl-png")' > ~/.config/common-lisp/source-registry.conf.d/10-cl-png.conf
echo '(:tree "/home/ubuntu/cl-gdal")' > ~/.config/common-lisp/source-registry.conf.d/11-cl-gdal.conf
echo '(:tree "/home/ubuntu/mmap-shared-cache")' > ~/.config/common-lisp/source-registry.conf.d/12-mmap-shared-cache.conf

# This line loads several Common Lisp libraries using the SBCL (Steel Bank Common Lisp)
# implementation. The quicklisp:quickload function is used to load the png, osicat, alexandria,
# cl-gd, and cl-ppcre libraries. These libraries provide various functions and utilities
# that are used by the RASP model. The (quit) function is used to exit SBCL
# after the libraries have been loaded.
sbcl --eval '(progn (quicklisp:quickload "png") (quicklisp:quickload "osicat") (quicklisp:quickload "alexandria") (quicklisp:quickload "cl-gd") (quicklisp:quickload "cl-ppcre") (quit))'
