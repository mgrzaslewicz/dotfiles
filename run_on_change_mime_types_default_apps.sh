#!/bin/bash
set -e

# Only run on Linux and if xdg-mime is available
if [[ "$(uname)" != "Linux" ]] || ! command -v xdg-mime &> /dev/null; then
  exit 0
fi

# Set all image types to be opened by gwenview (if available)
if command -v gwenview &> /dev/null; then
  IMAGE_TYPES=(
    "image/bmp"
    "image/gif"
    "image/jpeg"
    "image/jpg"
    "image/pjpeg"
    "image/png"
    "image/tiff"
    "image/webp"
    "image/x-bmp"
    "image/x-pcx"
    "image/x-png"
    "image/x-portable-anymap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-tga"
    "image/x-xbitmap"
    "image/x-xcf"
    "image/x-xpixmap"
    "image/svg+xml"
  )
  xdg-mime default org.kde.gwenview.desktop "${IMAGE_TYPES[@]}"
fi

# Set all video types to be opened by vlc (if available)
if command -v vlc &> /dev/null; then
  VIDEO_TYPES=(
    "video/mp4"
    "video/mpeg"
    "video/quicktime"
    "video/webm"
    "video/x-anim"
    "video/x-avi"
    "video/x-flc"
    "video/x-fli"
    "video/x-flv"
    "video/x-m4v"
    "video/x-matroska"
    "video/x-mng"
    "video/x-ms-asf"
    "video/x-ms-asx"
    "video/x-ms-wm"
    "video/x-ms-wmv"
    "video/x-ms-wmx"
    "video/x-ms-wvx"
    "video/x-msvideo"
    "video/x-nsv"
    "video/x-ogm+xml"
    "video/x-theora+xml"
  )
  xdg-mime default vlc.desktop "${VIDEO_TYPES[@]}"
fi
