#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color


# Check if necessary tools are installed
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: This script requires jq. Install with 'brew install jq'${NC}"
  exit 1
fi

if command -v parallel &> /dev/null; then
  HAS_PARALLEL=1
else
  HAS_PARALLEL=0
  echo -e "${YELLOW}Note: For better performance, install GNU parallel: 'brew install parallel'${NC}"
fi

echo -e "${BLUE}Gathering package information...${NC}"

# Start timer
start_time=$(date +%s)

# Get all installed packages
packages=$(brew list --formula)
casks=$(brew list --cask 2>/dev/null)

# Get reverse dependencies (what depends on what)
dependencies=$(brew deps --installed --for-each)

# Create temporary files for results (WITHOUT ANSI COLOR CODES)
TMPDIR=$(mktemp -d)
WANTED_FILE="$TMPDIR/wanted.txt"
DEPENDENCY_FILE="$TMPDIR/dependency.txt"
REMOVABLE_FILE="$TMPDIR/removable.txt"
WANTED_CASKS_FILE="$TMPDIR/wanted_casks.txt"
REMOVABLE_CASKS_FILE="$TMPDIR/removable_casks.txt"
PROGRESS_FILE="$TMPDIR/progress.txt"
INFO_FORMULA="$TMPDIR/info_formula.json"
INFO_CASKS="$TMPDIR/info_casks.json"
ERROR_LOG="$TMPDIR/error.log"

touch "$WANTED_FILE" "$DEPENDENCY_FILE" "$REMOVABLE_FILE" "$WANTED_CASKS_FILE" "$REMOVABLE_CASKS_FILE" "$PROGRESS_FILE" "$ERROR_LOG"
truncate -s 0 "$PROGRESS_FILE"

# Prefetch formula and cask JSON info for faster lookups - use v2 JSON format for casks
echo -e "${BLUE}Gathering formula information...${NC}"
brew info --json=v1 $(brew list --formula) > "$INFO_FORMULA" 2>>"$ERROR_LOG"

# Initialize casks JSON even if empty
echo '{"casks":[]}' > "$INFO_CASKS"

if [ -n "$casks" ]; then
  echo -e "${BLUE}Gathering cask information...${NC}"
  # Process casks individually to handle errors
  echo '{"casks":[' > "$INFO_CASKS.tmp"
  
  first=true
  for cask in $casks; do
    # Try to get cask info
    cask_info=$(brew info --json=v2 "$cask" 2>"$TMPDIR/current_error.log" || echo '{"casks":[]}')
    
    # Extract the cask object from the JSON array
    cask_obj=$(echo "$cask_info" | jq '.casks[0] // empty' 2>/dev/null)
    
    # If we got valid JSON for this cask, add it to our combined JSON
    if [ -n "$cask_obj" ] && [ "$cask_obj" != "null" ]; then
      if ! $first; then
        echo "," >> "$INFO_CASKS.tmp"
      else
        first=false
      fi
      echo "$cask_obj" >> "$INFO_CASKS.tmp"
    else
      # Get error message from log if available
      error_msg=$(cat "$TMPDIR/current_error.log" | tail -1)
      if [ -z "$error_msg" ]; then
        error_msg="Unknown error"
      fi
      echo -e "${YELLOW}Warning: Could not get info for cask '$cask': $error_msg${NC}"
      # Add a placeholder object for this cask
      if ! $first; then
        echo "," >> "$INFO_CASKS.tmp"
      else
        first=false
      fi
      # Add minimal valid JSON with error info in description
      echo "{\"token\":\"$cask\",\"desc\":\"[Error: Failed to retrieve cask information]\",\"name\":\"$cask\"}" >> "$INFO_CASKS.tmp"
    fi
  done
  
  echo ']}' >> "$INFO_CASKS.tmp"
  mv "$INFO_CASKS.tmp" "$INFO_CASKS"
fi

# Parse Brewfile to get explicitly wanted packages
BREWFILE="$HOME/.dotfiles/Brewfile"
if [ -f "$BREWFILE" ]; then
  wanted_packages=$(grep -E '^brew' "$BREWFILE" | awk -F"'" '{print $2}' | awk '{print $1}')
  wanted_casks=$(grep -E '^cask' "$BREWFILE" | awk -F"'" '{print $2}' | awk '{print $1}')
else
  echo -e "${YELLOW}Warning: Brewfile not found at $BREWFILE${NC}"
  wanted_packages=""
  wanted_casks=""
fi

total_packages=$(echo "$packages" | wc -w | tr -d ' ')
total_casks=$(echo "$casks" | wc -w | tr -d ' ')
total_items=$((total_packages + total_casks))

# Function to format time
format_time() {
  local seconds=$1
  if [ $seconds -lt 60 ]; then
    echo "${seconds}s"
  else
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    echo "${minutes}m ${remaining_seconds}s"
  fi
}

# Function to update progress
update_progress() {
  local processed_items=$1
  # determine terminal width
  local cols=$(tput cols 2>/dev/null || echo 80)
  local percent=$((processed_items * 100 / total_items))
  local current_time=$(date +%s)
  local elapsed=$((current_time - start_time))
  local elapsed_formatted=$(format_time $elapsed)
  local remaining_formatted="calculating..."
  if [ $processed_items -gt 0 ]; then
    local estimated_total=$((elapsed * total_items / processed_items))
    local remaining=$((estimated_total - elapsed))
    remaining_formatted=$(format_time $remaining)
  fi
  
  # Safe text for progress display without special format characters
  local items_text="${processed_items}/${total_items}"
  local status_text="Elapsed: ${elapsed_formatted} - Remaining: ${remaining_formatted}"
  
  # build dynamic progress bar
  local prefix="Progress: ["
  local suffix="] ${percent}% ${items_text} - ${status_text}"
  
  # calculate bar width safely
  local bar_width=$((cols - ${#prefix} - ${#suffix} - 5))
  [ $bar_width -lt 10 ] && bar_width=10
  
  # Create progress bar with proper width
  local filled_width=$((bar_width * percent / 100))
  local empty_width=$((bar_width - filled_width))
  
  local progress_bar=""
  local padding=""
  
  # Generate bar using safer methods
  [ $filled_width -gt 0 ] && progress_bar=$(head -c $filled_width < /dev/zero | tr '\0' '#')
  [ $empty_width -gt 0 ] && padding=$(head -c $empty_width < /dev/zero | tr '\0' '-')
  
  # clear line and print progress
  printf "\r%-${cols}s" " " # Clear the entire line safely
  printf "\r${CYAN}%s%s%s%s${NC}" "$prefix" "$progress_bar" "$padding" "$suffix"
}

# Function to process a single package
process_package() {
  local package=$1
  local description=""
  
  if [ -f "$INFO_FORMULA" ]; then
    description=$(jq -r --arg name "$package" '.[] | select(.name==$name) | .desc // "[No description available]"' "$INFO_FORMULA" 2>/dev/null)
  fi
  
  if [ -z "$description" ] || [ "$description" == "null" ]; then
    # Try to get description directly as a fallback
    description=$(brew desc "$package" 2>/dev/null || echo "[No description available]")
    # If that fails too, use a generic message
    if [ -z "$description" ] || [[ "$description" == *"Error"* ]]; then
      description="[No description available]"
    fi
  fi
  
  # Find what packages depend on this one
  local dependants=$(echo "$dependencies" | grep -E "^[^:]+: .*\\b$package\\b" | cut -d: -f1 | tr '\n' ', ' | sed 's/,$//' | sed 's/, /, /g')
  
  # Store data WITHOUT color codes to temporary files
  if echo "$wanted_packages" | grep -q "^$package$"; then
    if [ -z "$dependants" ]; then
      echo "$package|$description" >> "$WANTED_FILE"
    else
      echo "$package|$description|$dependants" >> "$WANTED_FILE"
    fi
  elif [ -n "$dependants" ]; then
    echo "$package|$description|$dependants" >> "$DEPENDENCY_FILE"
  else
    echo "$package|$description" >> "$REMOVABLE_FILE"
  fi
  
  # Update progress file (atomic append)
  echo "x" >> "$PROGRESS_FILE"
}

# Function to process a single cask
process_cask() {
  local cask=$1
  local description=""
  
  if [ -f "$INFO_CASKS" ]; then
    # For v2 JSON format, the structure is different
    description=$(jq -r --arg name "$cask" '.casks[] | select(.token==$name) | .desc // "[No description available]"' "$INFO_CASKS" 2>/dev/null)
  fi
  
  if [ -z "$description" ] || [ "$description" == "null" ]; then
    # Try to get description directly as a fallback
    description=$(brew desc "$cask" 2>/dev/null || echo "[No description available]")
    # If that fails too, use a generic message
    if [ -z "$description" ] || [[ "$description" == *"Error"* ]]; then
      description="[No description available]"
    fi
  fi
  
  # Store data WITHOUT color codes to temporary files
  if echo "$wanted_casks" | grep -q "^$cask$"; then
    echo "$cask|$description" >> "$WANTED_CASKS_FILE"
  else
    echo "$cask|$description" >> "$REMOVABLE_CASKS_FILE"
  fi
  
  # Update progress file (atomic append)
  echo "x" >> "$PROGRESS_FILE"
}

# Function to monitor progress file while parallel processes run
monitor_progress() {
  local last_count=0
  
  while [[ -f "$PROGRESS_FILE" && $(cat "$PROGRESS_FILE" | wc -l) -lt $total_items ]]; do
    local current_count=$(cat "$PROGRESS_FILE" | wc -l | tr -d ' ')
    
    if [[ $current_count -gt $last_count ]]; then
      update_progress $current_count
      last_count=$current_count
    fi
    
    sleep 0.5
  done
  
  # Ensure we show 100% at the end
  if [[ -f "$PROGRESS_FILE" ]]; then
    local final_count=$(cat "$PROGRESS_FILE" | wc -l | tr -d ' ')
    update_progress $final_count
  fi
}

# Export required variables for parallel
export dependencies
export wanted_packages
export wanted_casks
export WANTED_FILE DEPENDENCY_FILE REMOVABLE_FILE WANTED_CASKS_FILE REMOVABLE_CASKS_FILE PROGRESS_FILE
export INFO_FORMULA INFO_CASKS
export -f process_package
export -f process_cask
export -f format_time

echo -e "${BLUE}Processing packages and casks...${NC}"

# Use parallel processing if available, otherwise process sequentially
if [ "$HAS_PARALLEL" -eq 1 ]; then
  # Show initial progress
  update_progress 0
  
  # Start processing in background
  echo "$packages" | parallel -j 16 process_package &
  packages_pid=$!
  
  # Monitor progress while packages are processing
  monitor_progress &
  monitor_pid=$!
  
  # Wait for packages to complete
  wait $packages_pid
  
  # Process casks if any
  if [ -n "$casks" ]; then
    echo "$casks" | parallel -j 16 process_cask &
    casks_pid=$!
    wait $casks_pid
  fi
  
  # Wait for monitor to complete
  wait $monitor_pid
  
  # Ensure 100% completion
  update_progress $total_items
  echo # New line after progress
else
  # Process packages sequentially with progress updates
  for package in $packages; do
    process_package "$package"
    processed_items=$(cat "$PROGRESS_FILE" | wc -l | tr -d ' ')
    update_progress $processed_items
  done
  
  # Process casks sequentially with progress updates
  for cask in $casks; do
    process_cask "$cask"
    processed_items=$(cat "$PROGRESS_FILE" | wc -l | tr -d ' ')
    update_progress $processed_items
  done
  
  # End line after progress
  echo
fi

# Final time calculation
end_time=$(date +%s)
total_time=$((end_time - start_time))
total_time_formatted=$(format_time $total_time)

echo -e "\n${GREEN}[WANTED]${NC} - Explicitly listed in Brewfile"
echo -e "${BLUE}[DEPENDENCY]${NC} - Required by other packages"
echo -e "${RED}[CAN REMOVE]${NC} - Not in Brewfile and not a dependency"

# Display packages by group - NOW WITH PROPER COLOR CODES
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}WANTED PACKAGES${NC} (Explicitly listed in Brewfile)"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ -s "$WANTED_FILE" ]; then
  # Read from file and add color formatting at display time
  while IFS="|" read -r package description dependencies; do
    if [ -z "$dependencies" ]; then
      echo -e "${GREEN}[WANTED]${NC} ${YELLOW}$package${NC}: $description"
    else
      echo -e "${GREEN}[WANTED]${NC} ${YELLOW}$package${NC}: $description (Used by: $dependencies)"
    fi
  done < "$WANTED_FILE"
else
  echo -e "${YELLOW}No wanted packages found.${NC}"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}DEPENDENCY PACKAGES${NC} (Required by other packages)"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ -s "$DEPENDENCY_FILE" ]; then
  # Read from file and add color formatting at display time
  while IFS="|" read -r package description dependencies; do
    echo -e "${BLUE}[DEPENDENCY]${NC} ${YELLOW}$package${NC}: $description (Used by: $dependencies)"
  done < "$DEPENDENCY_FILE"
else
  echo -e "${YELLOW}No dependency packages found.${NC}"
fi

echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}REMOVABLE PACKAGES${NC} (Can be removed safely)"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ -s "$REMOVABLE_FILE" ]; then
  # Read from file and add color formatting at display time
  while IFS="|" read -r package description; do
    echo -e "${RED}[CAN REMOVE]${NC} ${YELLOW}$package${NC}: $description"
  done < "$REMOVABLE_FILE"
else
  echo -e "${YELLOW}No removable packages found.${NC}"
fi

if [ -n "$casks" ]; then
  echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}WANTED CASKS${NC} (Explicitly listed in Brewfile)"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if [ -s "$WANTED_CASKS_FILE" ]; then
    # Read from file and add color formatting at display time
    while IFS="|" read -r cask description; do
      echo -e "${GREEN}[WANTED]${NC} ${YELLOW}$cask${NC} (cask): $description"
    done < "$WANTED_CASKS_FILE"
  else
    echo -e "${YELLOW}No wanted casks found.${NC}"
  fi
  
  echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}REMOVABLE CASKS${NC} (Can be removed safely)"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if [ -s "$REMOVABLE_CASKS_FILE" ]; then
    # Read from file and add color formatting at display time
    while IFS="|" read -r cask description; do
      echo -e "${RED}[CAN REMOVE]${NC} ${YELLOW}$cask${NC} (cask): $description"
    done < "$REMOVABLE_CASKS_FILE"
  else
    echo -e "${YELLOW}No removable casks found.${NC}"
  fi
fi

echo -e "\nDone! Processed ${total_packages} packages and ${total_casks} casks in ${total_time_formatted}."

# Clean up temporary files
rm -rf "$TMPDIR" 