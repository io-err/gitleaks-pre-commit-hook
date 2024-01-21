#!/bin/sh

# This script will automatically:
# 1) install gitleaks
# 2) configure hooks.gitleaks.enable setting
# 3) create pre-commit script that will execute gitleaks before commit

# check that run directory contain .git folder
if [ ! -d ".git" ]; then
 echo ".git directory not found, you should run install script in the project's local git repo folder"
 exit 1
fi

# Install gitleaks
# Check if gitleaks already installed - exit.
GITLEAKS_PATH=$(whereis gitleaks|cut -d: -f2)

if [ -n "$GITLEAKS_PATH" ]; then
    echo "gitleaks already installed, exiting."
    exit 0
fi

# Check on what OS script executed
OS=$(uname -s)

if [ "$OS" = "Linux" ] || [ "$OS" = "Darwin" ]; then
    echo "The OS is supported."
else
    echo "The OS isn't supported."
    exit 1
fi

# For some reason gitleaks devs specify x86_64 as x64 in their releases, so we need to update target arch def
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="x64"
# If for some reason you still have x32 OS :D
elif [ "$ARCH" = "i386" ]; then
    ARCH="x32"
fi

echo "You will be prompted for password because sudo is required to install gitleaks to /usr/local/bin"
sleep 2

LATEST_RELEASE_ASSET_URL=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep browser_download_url| grep -i "$OS"| grep "$ARCH" | cut -d '"' -f 4) 
curl -s -L "${LATEST_RELEASE_ASSET_URL}" | sudo tar xzvf - -C /usr/local/bin gitleaks > /dev/null

# enable gitleaks for the currect repo
echo "Enabling gitleaks by default. In order to disable it, use 'git config hooks.gitleaks.enable false'"
git config hooks.gitleaks.enable true

# Configuring pre-commit hook
cat > .git/hooks/pre-commit << EOF
#!/bin/sh

# Check that gitleaks enabled
GITLEAKS_STATUS=\$(git config --bool hooks.gitleaks.enable)

if [ "\$GITLEAKS_STATUS" = "false" ]; then
    echo "gitleaks disabled with 'git config', to enable it use 'git config hooks.gitleaks.enable true'"
    exit 0
fi

# Run gitleaks
gitleaks protect -v --redact

if [ \$? -gt 0 ]; then
    echo "Leak(s) found, commit cancelled, check gitleaks output log higher"
    exit 1
fi

EOF

# Ensure that pre-commit scipt can be executed
chmod +x .git/hooks/pre-commit

echo "gitleaks and pre-commit hook sucessfully installed, gitleaks will be executed by pre-commit hook during 'git commit'"
