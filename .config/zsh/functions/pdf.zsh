shrinkpdf() {
  if (( $# < 1 )); then
    echo "Usage: $0 file.pdf"
    echo "  will shrink file.pdf"
    return 1
  fi

  local out="${1:r}-s.pdf"
  gs \
    -dNOPAUSE \
    -dBATCH \
    -sDEVICE=pdfwrite \
    -dCompatibilityLevel=1.5 \
    -dPDFSETTINGS=/printer \
    -sOutputFile="$out" \
    "$1"
}
