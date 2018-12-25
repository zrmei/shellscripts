function list_of_commands_you_use_most_often() {
    history | awk '{a[$2]++}END{for(i in a){print a[i] " " i}}' | sort -rn | head
}

function watch_star_wars_via_telnet() {
    telnet towel.blinkenlights.nl
}