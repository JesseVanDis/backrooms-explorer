#!/usr/bin/env bash

# Export .xcf files to .png's
# Change to the directory where this script is located
cd "/app/assets"

# Export every .xcf file in ./assets to ./resources/<name>.png

echo "gimp version:"
gimp --version

echo "Starting parse... "


{
cat <<EOF
(define (convert-xcf-png filename outpath)
    (let* (
            (image (car (gimp-xcf-load RUN-NONINTERACTIVE filename filename )))
            (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE)))
            )
        (begin (display "Exporting ")(display filename)(display " -> ")(display outpath)(newline))
        (file-png-save2 RUN-NONINTERACTIVE image drawable outpath outpath 0 9 0 0 0 0 0 0 0)
        (gimp-image-delete image)
    )
)

(gimp-message-set-handler 1) ; Messages to standard output
EOF

for i in *.xcf; do
  echo "(convert-xcf-png \"$i\" \"/app/resources/${i%%.xcf}.png\")"
done

echo "(gimp-quit 0)"

} | xvfb-run -a gimp -i -b -

# xvfb-run -a gimp -idf --batch-interpreter python-fu-eval -b "import sys;sys.path=['.']+sys.path;import convertXCF;convertXCF.run('/app/resources')" -b "pdb.gimp_quit(1)"

