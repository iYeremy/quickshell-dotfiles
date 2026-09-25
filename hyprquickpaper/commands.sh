awww img "$1" -t random --transition-duration 1
wal -i "$1" -n -q
bash ~/generate-brave-theme.sh
kitty +kitten themes --reload-in=all 2>/dev/null || pkill -SIGUSR1 kitty
