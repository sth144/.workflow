#!/bin/bash

CONFIG_FILE="$HOME/.trello-cli/default/config.json"
API_KEY=$(jq -r .apiKey "$CONFIG_FILE")
TOKEN=$(jq -r .token "$CONFIG_FILE")

# Function to get board ID from board name
get_board_id() {
    local board_name="$1"
    curl -s "https://api.trello.com/1/members/me/boards?key=$API_KEY&token=$TOKEN" |
        jq -r --arg name "$board_name" '.[] | select(.name == $name) | .id'
}

# Function to get list ID from list name and board ID
get_list_id() {
    local board_id="$1"
    local list_name="$2"
    curl -s "https://api.trello.com/1/boards/$board_id/lists?key=$API_KEY&token=$TOKEN" |
        jq -r --arg name "$list_name" '.[] | select(.name == $name) | .id'
}

# Function to get and print card names from a list
print_card_names_from_list() {
    local board_name="$1"
    local list_name="$2"
    local board_id=$(get_board_id "$board_name")
    local list_id=$(get_list_id "$board_id" "$list_name")

    curl -s "https://api.trello.com/1/lists/$list_id/cards?key=$API_KEY&token=$TOKEN" |
        jq -r '.[].name'
}

echo "To Do"
print_card_names_from_list "ToDo" "Today"

DOW=$(date +%u)
if (( DOW < 6 )); then
    echo "Work"
    print_card_names_from_list "Work" "Today"
fi
