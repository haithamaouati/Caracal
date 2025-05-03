#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati

# ASCII format
normal="\e[0m"
bold="\e[1m"
underlined="\e[4m"
bold_green="\e[1;32m"
bold_red="\e[1;31m"

# Config
DEPENDENCIES=("curl" "grep" "sed" "head" "shuf")
MAX_RETRIES=3
FALLBACK_MODE=true
PROXY_MODE=false
PROXY_LIST=()
AVAILABLE_FILE="available.txt"
> "$AVAILABLE_FILE"  # clear previous content

# Banner
BANNER=$(
clear
echo -e "${bold}"
cat <<'EOF'
   _____                                __
  / ___/ ___ _  ____ ___ _ ____ ___ _  / /
 / /__  / _ `/ / __// _ `// __// _ `/ / /
 \___/  \_,_/ /_/   \_,_/ \__/ \_,_/ /_/
EOF

echo -e "\n${bold}  Caracal${normal} — Instagram Username Checker\n"
)

check_dependencies() {
  for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      echo -e "${bold_red}[!] Missing dependency:${normal} $cmd"
      exit 1
    fi
  done
}

show_help() {
  echo
  echo "Usage: $0 -u <username> [-p <proxies.txt>]"
  echo "Options:"
  echo "  -u, --username     Username or file with usernames"
  echo "  -p, --proxy        Proxy list (optional)"
  echo "  -h, --help         Show this help"
  echo
  exit 0
}

fetch_user_id() {
  local username="$1"
  local url="https://www.instagram.com/$username/"
  local html=""
  local user_id=""
  local success=false

  for attempt in $(seq 1 $MAX_RETRIES); do
    if $PROXY_MODE && [ ${#PROXY_LIST[@]} -gt 0 ]; then
      proxy=$(shuf -n 1 -e "${PROXY_LIST[@]}")
      html=$(curl -s --max-time 10 --proxy "$proxy" -A "Mozilla/5.0" "$url")

      if [ -z "$html" ]; then
        echo -e "${bold_red}[!]${normal} Dead proxy removed: $proxy"
        PROXY_LIST=("${PROXY_LIST[@]/$proxy}")
        continue
      fi
    else
      html=$(curl -s -A "Mozilla/5.0" "$url")
    fi

    user_id=$(echo "$html" | grep -o '"profile_id":"[0-9]*"' | head -n1 | sed 's/[^0-9]*//g')
    if [ -n "$user_id" ]; then
      success=true
      break
    fi

    if echo "$html" | grep -q "Page Not Found"; then
      break
    fi
  done

  if $success; then
    echo -e "${bold_red}[-]${normal} Username:${bold_red} $username${normal} | User ID:${bold_red} $user_id${normal}"
    ((taken++))
  else
    if ! $PROXY_MODE && echo "$html" | grep -q "Please wait a few minutes before you try again."; then
      echo -e "${bold_red}[!]${normal} Rate limited by Instagram."
      exit 1
    fi
    echo -e "${bold_green}[+]${normal} Username:${bold_green} $username${normal}"
    echo "$username" >> "$AVAILABLE_FILE"
    ((available++))
  fi
  ((checked++))
}

# Print banner
echo -e "$BANNER"

# Check dependencies
check_dependencies

# Parse arguments
if [ $# -eq 0 ]; then
  show_help
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--username)
      INPUT="$2"
      if [[ -z "$INPUT" || "$INPUT" == -* ]]; then
        echo -e "${bold_red}[!]${normal} No username or file provided after -u"
        exit 1
      fi
      shift 2
      ;;
    -p|--proxy)
      PROXY_FILE="$2"
      if [[ -z "$PROXY_FILE" || "$PROXY_FILE" == -* || ! -f "$PROXY_FILE" ]]; then
        echo -e "${bold_red}[!]${normal} Invalid proxy file"
        exit 1
      fi
      mapfile -t PROXY_LIST < "$PROXY_FILE"
      PROXY_MODE=true
      shift 2
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# Init counters
checked=0
available=0
taken=0
START_TIME=$(date +%s)

echo -e "\nChecking for usernames: ${bold}$INPUT${normal}\n"

# Input check: file or single username
if [ -f "$INPUT" ]; then
  while IFS= read -r username || [[ -n "$username" ]]; do
    [ -z "$username" ] && continue
    if $PROXY_MODE && [ ${#PROXY_LIST[@]} -eq 0 ]; then
      if $FALLBACK_MODE; then
        echo -e "${bold}[*]${normal} Fallback to direct connection."
        PROXY_MODE=false
      else
        echo -e "${bold_red}[x]${normal} No proxies left. Exiting."
        exit 1
      fi
    fi
    fetch_user_id "$username"
  done < "$INPUT"
else
  fetch_user_id "$INPUT"
fi

# Finish log
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "\n${bold}[¡]${normal} ${bold_green}Process finished.${normal} Total time: ${bold}${DURATION}s${normal}\n"
echo -e "${bold}[*]${normal} Total usernames checked: ${bold}$checked${normal}"
echo -e "${bold_green}[+]${normal} Available usernames: ${bold_green}$available${normal}"
echo -e "${bold_red}[-]${normal} Taken usernames: ${bold_red}$taken${normal}\n"

# Save available usernames to a file
if [ "$available" -gt 0 ]; then
  echo -e "${bold_green}[¡]${normal} Saved available usernames to ${bold}$AVAILABLE_FILE${normal}\n"
fi
