#!/bin/bash
# ln -s ../../pre-commit.sh .git/hooks/pre-commit
set -ex
terraform fmt -check=true ./
