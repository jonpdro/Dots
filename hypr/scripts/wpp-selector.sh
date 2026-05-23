#!/bin/bash

# Wallpaper selector script for Arch + Hyprland

WALLPAPER_DIR="/JP/Wallpapers"
MENU_THEME="/home/jon/.config/rofi/wallpaper-list.rasi"
SEARCH_THEME="/home/jon/.config/rofi/wallpaper-search.rasi"
HYPRPAPER_CONF="/home/jon/.config/hypr/hyprpaper.conf"
HYPRLOCK_CONF="/home/jon/.config/hypr/hyprlock.conf"

# Global cache variables
declare -a WALLPAPER_ARRAY
declare CURRENT_WALLPAPER_CACHE

# Initialize and validate
initialize_script() {
  if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "Error: Wallpaper directory $WALLPAPER_DIR does not exist"
    exit 1
  fi

  if [ ! -f "$MENU_THEME" ]; then
    echo "Error: Rofi menu theme $MENU_THEME does not exist"
    exit 1
  fi

  if [ ! -f "$SEARCH_THEME" ]; then
    echo "Error: Rofi search theme $SEARCH_THEME does not exist"
    exit 1
  fi

  if [ ! -f "$HYPRPAPER_CONF" ]; then
    echo "Error: hyprpaper config $HYPRPAPER_CONF does not exist"
    exit 1
  fi

  if [ ! -f "$HYPRLOCK_CONF" ]; then
    echo "Error: hyprlock config $HYPRLOCK_CONF does not exist"
    exit 1
  fi

  load_wallpapers_cache
}

load_wallpapers_cache() {
  mapfile -t WALLPAPER_ARRAY < <(
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.webp" \) -printf "%f\n" | sort
  )

  if [ ${#WALLPAPER_ARRAY[@]} -eq 0 ]; then
    echo "Error: No wallpapers found in $WALLPAPER_DIR"
    exit 1
  fi
}

get_current_wallpaper() {
  if [ -z "$CURRENT_WALLPAPER_CACHE" ]; then
    if [ -f "$HYPRPAPER_CONF" ]; then
      CURRENT_WALLPAPER_CACHE=$(grep -E '^\s*path\s*=\s*' "$HYPRPAPER_CONF" | head -1 | sed -E 's/^\s*path\s*=\s*//' | tr -d '"')
    fi
  fi
  echo "$CURRENT_WALLPAPER_CACHE"
}

get_random_wallpaper() {
  local count=${#WALLPAPER_ARRAY[@]}
  local current_wallpaper current_filename

  if [ $count -eq 0 ]; then
    echo ""
    return 1
  fi

  current_wallpaper=$(get_current_wallpaper)
  current_filename=$(basename "$current_wallpaper" 2>/dev/null)

  if [ -n "$current_filename" ] && [ $count -gt 1 ]; then
    local filtered_wallpapers=()
    for wp in "${WALLPAPER_ARRAY[@]}"; do
      if [ "$wp" != "$current_filename" ]; then
        filtered_wallpapers+=("$wp")
      fi
    done

    local filtered_count=${#filtered_wallpapers[@]}
    if [ $filtered_count -gt 0 ]; then
      echo "${filtered_wallpapers[$((RANDOM % filtered_count))]}"
      return 0
    fi
  fi

  echo "${WALLPAPER_ARRAY[$((RANDOM % count))]}"
}

display_wallpapers() {
  local theme="$1"
  if [ "$theme" = "$MENU_THEME" ]; then
    printf '%s\n' "${WALLPAPER_ARRAY[@]}" | rofi -dmenu -theme "$theme" -p "" -kb-custom-1 "F1" -kb-custom-2 "r"
  else
    printf '%s\n' "${WALLPAPER_ARRAY[@]}" | rofi -dmenu -theme "$theme" -p "" -kb-custom-1 "F1" -i
  fi
}

send_notification() {
  local display_name
  display_name=$(basename "$1" | sed 's/\.[^.]*$//')

  if command -v dunstify &>/dev/null; then
    dunstify "Wallpaper:" "$display_name" -r 1000 -t 3000
  elif command -v notify-send &>/dev/null; then
    notify-send "Wallpaper:" "$display_name" -t 3000
  fi
}

update_hyprpaper_conf() {
  local wallpaper_file="$1"
  local wallpaper_path="$WALLPAPER_DIR/$wallpaper_file"
  local temp_conf
  temp_conf=$(mktemp)
  local in_wallpaper_block=0

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*wallpaper[[:space:]]*\{[[:space:]]*$ ]]; then
      in_wallpaper_block=1
      echo "$line" >>"$temp_conf"
      continue
    fi

    if [[ $in_wallpaper_block -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then
      in_wallpaper_block=0
      echo "$line" >>"$temp_conf"
      continue
    fi

    if [[ $in_wallpaper_block -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]* ]]; then
      local line_indent
      line_indent=$(echo "$line" | sed 's/path.*//')
      echo "${line_indent}path = $wallpaper_path" >>"$temp_conf"
    else
      echo "$line" >>"$temp_conf"
    fi
  done <"$HYPRPAPER_CONF"

  mv "$temp_conf" "$HYPRPAPER_CONF"
}

update_hyprpaper() {
  local wallpaper_path="$1"

  if ! command -v hyprctl &>/dev/null; then
    echo "Error: hyprctl not available"
    return 1
  fi

  hyprctl hyprpaper preload "$wallpaper_path"
  hyprctl hyprpaper wallpaper "DP-1,$wallpaper_path"
  hyprctl hyprpaper unload all
}

update_hyprlock() {
  local wallpaper_path="$1"
  local escaped_path
  escaped_path=$(echo "$wallpaper_path" | sed 's/\//\\\//g')

  sed -i '/^background {/,/^}/ s/\(^[[:space:]]*path = \).*$/\1'"$escaped_path"'/' "$HYPRLOCK_CONF"
}

apply_wallpaper() {
  local selected="$1"
  local wallpaper_path="$WALLPAPER_DIR/$selected"

  CURRENT_WALLPAPER_CACHE="$wallpaper_path"

  update_hyprpaper_conf "$selected"
  update_hyprpaper "$wallpaper_path"
  update_hyprlock "$wallpaper_path"
  send_notification "$selected"
}

main() {
  initialize_script

  if [[ "$1" == "-r" || "$1" == "--random" ]]; then
    local random_wallpaper
    random_wallpaper=$(get_random_wallpaper)
    if [ -n "$random_wallpaper" ]; then
      apply_wallpaper "$random_wallpaper"
    else
      echo "Error: No wallpapers found to select randomly"
      exit 1
    fi
    return
  fi

  local current_theme="$MENU_THEME"
  local selected rofi_exit_code

  while true; do
    selected=$(display_wallpapers "$current_theme")
    rofi_exit_code=$?

    if [ $rofi_exit_code -eq 10 ]; then
      # F1 — toggle theme
      if [ "$current_theme" = "$MENU_THEME" ]; then
        current_theme="$SEARCH_THEME"
      else
        current_theme="$MENU_THEME"
      fi

    elif [ $rofi_exit_code -eq 11 ]; then
      # r — random
      local random_wallpaper
      random_wallpaper=$(get_random_wallpaper)
      if [ -n "$random_wallpaper" ]; then
        apply_wallpaper "$random_wallpaper"
      else
        echo "Error: No wallpapers found to select randomly"
        exit 1
      fi
      return

    elif [ $rofi_exit_code -eq 0 ] && [ -n "$selected" ]; then
      apply_wallpaper "$selected"
      return

    else
      # Cancelled / dismissed
      return
    fi
  done
}

main "$@"
