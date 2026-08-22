#!/usr/bin/env bash

# Export .xcf files to .png's
# Change to the directory where this script is located
cd "$(dirname "$0")" || exit 1

# Create resources directory if it doesn't exist
mkdir -p "./resources"

# Export every .xcf file in ./assets to ./resources/<name>.png

echo "Starting parse... "
xvfb-run -a gimp -idf -n -b "
(let* ((file-list (cadr (file-glob \"assets/*.xcf\" 1))))
  (while (not (null? file-list))
    (let* ((filename (car file-list))
           (image (car (gimp-file-load RUN-NONINTERACTIVE filename filename)))
           (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE)))
           (output-path (string-append \"resources/\" (substring filename 7 (- (string-length filename) 4)) \".png\")))
      (gimp-message (string-append \"Exporting: \" filename \" -> \" output-path))
      (file-png-save RUN-NONINTERACTIVE image drawable output-path output-path 0 9 0 0 0 0 0)
      (gimp-image-delete image)
      (set! file-list (cdr file-list)))))
(gimp-quit 0)"
