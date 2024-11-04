
#!/bin/bash

# Function to kill processes holding given port
kill_processes() {
    port="$1"
    pids=$(lsof -i tcp:"$port" | grep -v PID | awk '{print $2}')

    if [ -n "$pids" ]; then
        echo "Killing PIDs for port $port: $pids"
        echo "$pids" | xargs kill -9
    else
        echo "No processes found holding port $port"
    fi
}

# Single port input
if [[ "$#" -eq 1 ]]; then
    port=$1
    kill_processes "$port"
    exit 0
fi

# Port range input
if [[ "$#" -eq 3 && "$2" == "-" ]]; then
    start_port=$1
    end_port=$3

    if ! [[ "$start_port" =~ ^[0-9]+$ ]] || ! [[ "$end_port" =~ ^[0-9]+$ ]]; then
        echo "Invalid port range input. Please provide valid numeric range."
        exit 1
    fi

    for (( port = start_port; port <= end_port; port++ )); do
        kill_processes "$port"
    done
    exit 0
fi

echo "Invalid input. Please provide either a single port or a valid port range."
exit 1
