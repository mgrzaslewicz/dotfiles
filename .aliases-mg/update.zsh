alias upall="sudo apt update && sudo apt -y full-upgrade && sudo apt autoremove -y && sudo apt autoclean && sudo snap refresh"
alias upallpip="pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U"
alias provision="(cd ~/repos/dev-machine-provision && ./provision.sh)"
