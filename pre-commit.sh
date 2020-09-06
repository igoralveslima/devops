#!/bin/bash
# chmod +x pre-commit.sh && ln -s ../../pre-commit.sh .git/hooks/pre-commit
set -ex
terraform validate && terraform fmt -check=true ./
