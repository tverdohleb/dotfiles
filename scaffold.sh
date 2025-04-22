#!/bin/sh

# We should have two arguments:
# 1. Scaffold name (available: "frontend"; case-insensitive, as we will lowercase it)
# 2. Project name (any valid string consisting of letters of any case, numbers, dashes, and underscores)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print error message and exit
error_exit() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  exit 1
}

# Function to print success message
success_msg() {
  echo -e "${GREEN}$1${NC}"
}

# Function to print warning message
warning_msg() {
  echo -e "${YELLOW}$1${NC}"
}

# Verify preconditions (git, node, yarn)
if ! command -v git >/dev/null 2>&1; then
  error_exit "Git is not installed. Please install git and try again."
fi

if ! command -v node >/dev/null 2>&1; then
  error_exit "Node.js is not installed. Please install Node.js and try again."
fi

if ! command -v yarn >/dev/null 2>&1; then
  error_exit "Yarn is not installed. Please install yarn and try again."
fi

# Validate arguments, notify user if something is wrong
if [ $# -ne 2 ]; then
  error_exit "Expected 2 arguments, got $#.\nUsage: scaffold <scaffold-name> <project-name>"
fi

SCAFFOLD_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
PROJECT_NAME="$2"

# Check if scaffold name is valid
REPO_URL="https://github.com/tverdohleb/scaffold-${SCAFFOLD_NAME}.git"

# Check if the repository exists on GitHub
if command -v curl >/dev/null 2>&1; then
  # Using curl to check if repo exists (will follow redirects and check status code)
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L "https://github.com/tverdohleb/scaffold-${SCAFFOLD_NAME}")
  if [ "$HTTP_STATUS" = "404" ]; then
    error_exit "Scaffold '${SCAFFOLD_NAME}' does not exist. Repository not found: ${REPO_URL}"
  elif [ "$HTTP_STATUS" != "200" ]; then
    warning_msg "Couldn't verify scaffold existence (HTTP status: ${HTTP_STATUS}). Continuing anyway..."
  fi
elif command -v wget >/dev/null 2>&1; then
  # Alternative using wget
  if ! wget --spider --quiet "https://github.com/tverdohleb/scaffold-${SCAFFOLD_NAME}"; then
    error_exit "Scaffold '${SCAFFOLD_NAME}' does not exist. Repository not found: ${REPO_URL}"
  fi
else
  warning_msg "Neither curl nor wget is installed. Cannot verify if scaffold exists. Continuing anyway..."
fi

# Validate project name (letters, numbers, dashes, and underscores)
if ! echo "$PROJECT_NAME" | grep -q '^[a-zA-Z0-9_-]\+$'; then
  error_exit "Invalid project name: '$PROJECT_NAME'. Project name should consist of letters, numbers, dashes, and underscores only."
fi

# Check if the project directory already exists
if [ -d "$PROJECT_NAME" ]; then
  error_exit "Project directory '$PROJECT_NAME' already exists."
fi

# Concatenate scaffold name into source repository url
echo "Using repository: $REPO_URL"

# Clone the repository
echo "Cloning repository..."
if ! git clone "$REPO_URL" "$PROJECT_NAME"; then
  error_exit "Failed to clone repository. Please check your internet connection and try again."
fi

cd "$PROJECT_NAME" || error_exit "Failed to switch to project directory '$PROJECT_NAME'"

# Remove .git and init fresh one
echo "Initializing fresh git repository..."
rm -rf .git
if ! git init; then
  error_exit "Failed to initialize git repository."
fi

# Rename package name in package.json
echo "Updating templates..."
if [ -f "package.json" ]; then
  if command -v sed >/dev/null 2>&1; then
    # Different sed syntax for macOS vs GNU/Linux
    if [ "$(uname)" = "Darwin" ]; then
      sed -i '' "s/\"name\": \".*\"/\"name\": \"$PROJECT_NAME\"/" package.json || error_exit "Failed to update package.json"
    else
      sed -i "s/\"name\": \".*\"/\"name\": \"$PROJECT_NAME\"/" package.json || error_exit "Failed to update package.json"
    fi
  else
    error_exit "sed is not installed. Cannot update package.json."
  fi
else
  warning_msg "package.json not found. Skipping package name update."
fi

# Run `yarn install`
echo "Installing dependencies..."
if ! yarn install; then
  error_exit "Failed to install dependencies. Please check your internet connection and try again."
fi

# Run `git commit --no-verify -m "feat: project initialized from scaffold"`
echo "Creating initial commit..."
git add .
if ! git commit --no-verify -m "feat: project initialized from scaffold"; then
  error_exit "Failed to create initial commit."
fi

success_msg "Project '$PROJECT_NAME' has been successfully initialized from '$SCAFFOLD_NAME' scaffold!"
echo "You can now start working on your project. Change directory with: cd $PROJECT_NAME"
echo "Open it in cursor? [y/N]"
read -r OPEN_IN_CURSOR
if [ "$OPEN_IN_CURSOR" = "y" ]; then
  open -a Cursor .
fi

success_msg "Happy coding!🎉"