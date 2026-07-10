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
