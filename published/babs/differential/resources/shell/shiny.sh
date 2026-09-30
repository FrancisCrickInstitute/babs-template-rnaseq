shiny() {
    if [ -z "$@" ]; then
	app="Shiny App"
	appSource="app.R"
    else
	app=${1%.*}
	appSource=$1
    fi
    if [[ ! -e "$appSource" ]]; then
	if [[ -e "resources/shiny/$appSource.r" ]]; then
	    appSource="resources/shiny/$appSource.r"
	elif [[ -e "resources/shiny/$appSource.R" ]]; then
	    appSource="resources/shiny/$appSource.R"
	elif [[ -e "resources/shiny/$appSource" ]]; then
	    appSource="resources/shiny/$appSource"
	else
	    echo "Can't find a default $appSource in current direcory or resources/shiny"
	    exit
	fi
    fi
    my_caller R --quiet --no-echo --no-restore -e "my_title <- '${shortTitle} ${app}'; cat('✅ Starting app', my_title, '...\n'); source('$appSource'); shiny::runApp(app, host='0.0.0.0',port=${PORT})" &
    PID=$!
    server_info shiny 3838
    [ -n "$run_tmux" ] || wait $PID
}
