#!/bin/bash

# Function to create a PR
create_pr() {
  PACKAGE_NAME=$1
  BRANCH_NAME="update-${PACKAGE_NAME}"
  
  # Create a new branch for the package
  git checkout -b $BRANCH_NAME

  # Commit the changes
  git commit -am "${PACKAGE_NAME}: substitute --replace with --replace-fail"

  # Push the branch to the remote repository
  git push origin $BRANCH_NAME

  # Create a pull request using the GitHub CLI
  # gh pr create --title "Update ${PACKAGE_NAME} to use --replace-fail" --body "This PR updates ${PACKAGE_NAME} to use --replace-fail instead of --replace."
}

# Find all modified .nix files and group them by directory
MODIFIED_DIRS=$(git status --porcelain | grep -E "^\s*M\s+.*\.nix$" | awk '{print $2}' | xargs -n 1 dirname | sort | uniq)

for DIR in $MODIFIED_DIRS; do
  # Checkout the master branch and reset changes
  git checkout master
  git checkout -- .

  # Extract the package name from the directory
  PACKAGE_NAME=$(basename $DIR)
  BRANCH_NAME="update-${PACKAGE_NAME}"

  # Check if the branch already exists locally or remotely
  if git show-ref --quiet refs/heads/$BRANCH_NAME || git ls-remote --heads origin $BRANCH_NAME | grep -q $BRANCH_NAME; then
    echo "Branch ${BRANCH_NAME} already exists locally or remotely. Skipping..."
    continue
  fi

  # Perform the replacement in all .nix files within the directory
  find $DIR -type f -iname "*.nix" -exec sed -i 's/--replace\(\s\|$\)/--replace-fail\1/g' {} +

  # Build the package locally
  nix build .#${PACKAGE_NAME} -L

  # Check the build status
  if [ $? -eq 0 ]; then
    echo "Build succeeded for ${PACKAGE_NAME}. Creating PR..."

    # Create a PR for the package
    create_pr $PACKAGE_NAME
  else
    echo "Build failed for ${PACKAGE_NAME}. Skipping PR creation."
  fi
done

# Return to the master branch
git checkout master
