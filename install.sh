#!/bin/sh

REPLACE_ZSHRC=false
if [ -f ~/.zshrc ] && [ ! -L ~/.zshrc ]; then
  echo "Backing up existing .zshrc to .zshrc.backup"
  mv ~/.zshrc ~/.zshrc.backup
  REPLACE_ZSHRC=true
fi

if [ -f ~/.zshrc ]; then
  echo ".zshrc already exists. Replace it? (y/n)"
  read -r replace
  if [ "$replace" = "y" ]; then
    REPLACE_ZSHRC=true
  fi
else
  REPLACE_ZSHRC=true
fi

if $REPLACE_ZSHRC; then
  rm ~/.zshrc
  ln -sw $HOME/.dotfiles/zshrc.sh ~/.zshrc
fi

function has() {
  which "$@" > /dev/null 2>&1
}

if ! has brew ; then
  echo "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew already installed"
fi

brew update
brew upgrade

brew tap homebrew/bundle
brew bundle --file=./Brewfile
