upall() {
  if command -v apt &> /dev/null; then
    sudo apt update
    sudo apt upgrade -y
    sudo apt -y full-upgrade
    sudo apt autoremove -y
    sudo apt autoclean
  fi

  if command -v snap &> /dev/null; then
    sudo snap refresh
  fi

  if command -v flatpak &> /dev/null; then
    flatpak update -y
  fi

  if command -v brew &> /dev/null; then
    brew update
    brew upgrade
  fi
}

alias upallpip="pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U"
