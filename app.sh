#!/bin/bash

usage() {
    echo -e "\e[35mUsage: app -i <package> or app install <package>\e[0m"
    exit 1
}

error() {
    dialog --title "ERROR" --msgbox "ERROR: Target not found" 7 40
    clear
    exit 1
}

fakesteps=("Reading database" "Downloading" "Unzipping files" "Compiling" "Installing")
steps_count=${#fakesteps[@]}
declare -a step_counts
for ((i=0; i<steps_count; i++)); do step_counts[$i]=0; done

fullscreen_bar_until_done() {
    local task="$1"
    local pid="$2"
    local step=0

    (
      while kill -0 "$pid" 2>/dev/null; do
        step_counts[$step]=$((step_counts[$step] + 1))
        for ((percent=0; percent<=100; percent+=5)); do
          if ! kill -0 "$pid" 2>/dev/null; then break; fi
          echo "XXX"
          echo $percent
          echo -e "\n${fakesteps[$step]} $task (${step_counts[$step]})"
          echo "XXX"
          sleep 0.07
        done
        step=$(( (step + 1) % steps_count ))
      done
      # Final bar and message
      echo "XXX"
      echo 100
      echo -e "\nDone $task!"
      echo "XXX"
      sleep 0.5
    ) | dialog --colors --title "$task" --gauge "" 10 60 0
    clear
}

run_silent() {
    bash -c "$1" >"$2" 2>&1 &
    echo $!
}

if [[ $# -lt 2 ]]; then
    usage
fi

if [[ "$1" == "-i" ]]; then
    PKG="$2"
elif [[ "$1" == "install" ]]; then
    PKG="$2"
else
    usage
fi

TMPLOG=$(mktemp)

# Install .deb
if [[ "$PKG" =~ \.deb$ ]]; then
    pid=$(run_silent "sudo dpkg -i \"$PKG\"" "$TMPLOG")
    fullscreen_bar_until_done "with dpkg" $pid
    wait $pid
    cat "$TMPLOG"
    rm "$TMPLOG"
    exit $?
fi

# Install .rpm
if [[ "$PKG" =~ \.rpm$ ]]; then
    pid=$(run_silent "sudo rpm -i \"$PKG\"" "$TMPLOG")
    fullscreen_bar_until_done "with rpm" $pid
    wait $pid
    cat "$TMPLOG"
    rm "$TMPLOG"
    exit $?
fi

# Try pacman
if command -v pacman >/dev/null; then
    if pacman -Si "$PKG" &>/dev/null; then
        pid=$(run_silent "sudo pacman -S --noconfirm \"$PKG\"" "$TMPLOG")
        fullscreen_bar_until_done "with pacman" $pid
        wait $pid
        cat "$TMPLOG"
        rm "$TMPLOG"
        exit $?
    fi
fi

# Try yay (AUR)
if command -v yay >/dev/null; then
    if yay -Si "$PKG" &>/dev/null; then
        pid=$(run_silent "yay -S --noconfirm --answerdiff None --answerclean None \"$PKG\"" "$TMPLOG")
        fullscreen_bar_until_done "with yay (AUR)" $pid
        wait $pid
        cat "$TMPLOG"
        rm "$TMPLOG"
        exit $?
    fi
fi

# Try flatpak
if command -v flatpak >/dev/null; then
    if flatpak search "$PKG" | grep -qw "$PKG"; then
        pid=$(run_silent "flatpak install -y \"$PKG\"" "$TMPLOG")
        fullscreen_bar_until_done "with flatpak" $pid
        wait $pid
        cat "$TMPLOG"
        rm "$TMPLOG"
        exit $?
    fi
fi

# Try dnf
if command -v dnf >/dev/null; then
    if dnf info "$PKG" &>/dev/null; then
        pid=$(run_silent "sudo dnf install -y \"$PKG\"" "$TMPLOG")
        fullscreen_bar_until_done "with dnf" $pid
        wait $pid
        cat "$TMPLOG"
        rm "$TMPLOG"
        exit $?
    fi
fi

error
