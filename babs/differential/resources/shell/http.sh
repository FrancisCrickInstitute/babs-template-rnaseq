http() {
  my_caller python3 -m http.server ${PORT} "$@" &
  PID=$!
  server_info http ${PORT}
  wait $PID
}
