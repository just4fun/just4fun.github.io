#!/bin/bash

# enable error reporting to the console
set -e

echo "Starting deployment process..."

# Check if we're in the right branch
if [ "$GITHUB_REF" != "refs/heads/src" ]; then
    echo "Not on src branch, skipping deployment"
    exit 0
fi

# Build the site
echo "Building Jekyll site..."
bundle exec jekyll build

# The actual deployment is handled by the peaceiris/actions-gh-pages action
# This script is mainly for any custom deployment logic you might need

echo "Deployment process completed successfully!"