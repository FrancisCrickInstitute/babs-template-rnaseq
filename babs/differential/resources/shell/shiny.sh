shiny() {
if [ -z "$@" ]; then 
    my_caller R --quiet --no-echo --no-restore -e "cat('✅ Starting app...\n'); shiny::runApp(host='0.0.0.0',port=${PORT})" &
    PID=$!
else
    my_caller R --quiet --no-echo --no-restore -e "cat('✅ Starting app...\n'); shiny::runApp(appDir='$1', host='0.0.0.0',port=${PORT})" &
    PID=$!
fi

## Produce the informative message
server_info shiny 3838

wait $PID
}
