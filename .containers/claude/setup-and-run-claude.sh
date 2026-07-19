yes n | rtk init -g --auto-patch
codegraph install --yes --target claude --location local
codegraph init && codegraph sync
claude
