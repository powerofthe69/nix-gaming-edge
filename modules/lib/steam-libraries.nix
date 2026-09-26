# Shell helper shared by the cleanup modules: locates every steamapps dir a user has.
{ pkgs }:
''
  find_steam_libraries() {
    local user_home="$1"
    local libraries=""

    for config_path in \
      "$user_home/.local/share/Steam/steamapps/libraryfolders.vdf" \
      "$user_home/.steam/steam/steamapps/libraryfolders.vdf" \
      "$user_home/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/libraryfolders.vdf"; do

      if [ -f "$config_path" ]; then
        paths=$(${pkgs.gnugrep}/bin/grep -oP '"path"\s+"\K[^"]+' "$config_path" 2>/dev/null || true)
        for path in $paths; do
          [ -d "$path/steamapps" ] && libraries="$libraries $path/steamapps"
        done
      fi
    done

    echo "$libraries" | tr ' ' '\n' | sort -u | tr '\n' ' '
  }
''
