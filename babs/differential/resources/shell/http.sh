http() {
  my_caller python3 -m http.server ${PORT} --directory ${1:-.} &
  PID=$!
  server_info http ${PORT}
  [ -n "$run_tmux" ] || wait $PID
}
