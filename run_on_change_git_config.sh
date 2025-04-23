#!/bin/bash
set -e
set -x
# when the list is empty, it will return non-zero code so prevent it
git config --global --unset-all include.path || true
git config --global --add include.path ~/gitalias.txt
git config --global --add include.path ~/my-gitalias.txt

git config --global user.email "mikolaj.grzaslewicz@gmail.com"
git config --global user.name "Mikolaj Grzaslewicz"
