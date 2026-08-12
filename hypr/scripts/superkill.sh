#!/bin/bash

PID=$(hyprctl activewindow -j | jq '.pid')

if [ "$PID" != "null" ]; then
    kill -9 "$PID"
fi
