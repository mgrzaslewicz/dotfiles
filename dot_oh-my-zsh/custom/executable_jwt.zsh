jwtDecode() {
  payload=$(printf '%s' "$1" | cut -d '.' -f 2)

  # Convert base64url to base64
  payload=$(printf '%s' "$payload" | tr '_-' '/+')

  # Add missing padding
  case $((${#payload} % 4)) in
    2) payload="${payload}==" ;;
    3) payload="${payload}=" ;;
    1) echo "Invalid base64url payload" >&2; return 1 ;;
  esac

  # Decode and add newline
  printf '%s' "$payload" | base64 -d | jq
  echo
}

jwtDecodeClipboard() {
  local clip
  if command -v pbpaste >/dev/null 2>&1; then
    clip=$(pbpaste)
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1; then
    clip=$(wl-paste)
  elif command -v xclip >/dev/null 2>&1; then
    clip=$(xclip -selection clipboard -o)
  elif command -v xsel >/dev/null 2>&1; then
    clip=$(xsel --clipboard --output)
  else
    echo "No clipboard tool found (need pbpaste, wl-paste, xclip, or xsel)" >&2
    return 1
  fi

  jwtDecode "$clip"
}
