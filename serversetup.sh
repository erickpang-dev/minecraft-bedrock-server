#!/bin/bash
cd $(dirname $(realpath $0))
shopt -s extglob

# ----------preparation----------

# execute as many arguments as received exiting on error without proceeding
pipeline() {
    for i in "$@"; do
        $i || break
    done
}

# set variables
set_variables() {
    DOWNLOAD_URL=$(wget -qO- https://www.minecraft.net/en-us/download/server/bedrock | grep -Eoi 'https://minecraft.azureedge.net/bin-linux/.*.zip')
    LATEST_VERSION=$(echo $DOWNLOAD_URL | grep -o -P '(?<=server-).*(?=[.])')
    DOWNLOADED_FILE="bedrock-server-$LATEST_VERSION.zip"
    if [ -f version ]; then
        LOCAL_VERSION=$(cat version)
    else
        if [-f bedrock_server]; then
            echo "[version] file not found, running server to retrieve it."
            LOCAL_VERSION=$(timeout 3 ./bedrock_server | grep -oP '(?<=INFO] Version ).*')
        else
            LOCAL_VERSION="Not found"
        fi
    fi
}

# run server
run_server() {
    echo "Starting server."
    LD_LIBRARY_PATH=. ./bedrock_server
}

# print done
success() {
    echo "Done."
}

# remind user to configure server
remind() {
    echo "Don't forget to edit server.properties, permissions.json and whitelist.json."
    echo "Use 'LD_LIBRARY_PATH=. ./bedrock_server' to start server."
}

# check if the necessary packagage is installed and install if it is not
pkg_check() {
    for i in "$@"; do
        echo "Verifying if [$i] is installed."
        PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
        if [ "" = "$PKG_OK" ]; then
            echo "[$i] is not installed. Would you like to install it? (y/n)"
            read INSTALL_ANSWER
            case $INSTALL_ANSWER in
            y)
                echo "Installing [$i]."
                sudo apt-get --force-yes --yes install $i
                ;;
            n)
                echo "[$i] is required to proceed, exiting script."
                exit
                ;;
            esac
        else
            echo "[$i] is already installed, proceeding."
        fi
    done
}

# download server files
download() {
    echo "Downloading."
    wget -nc $DOWNLOAD_URL
}

# extract downloaded files
extract() {
    echo "Extracting."
    unzip -oq $DOWNLOADED_FILE
}

# create or update version file
update_version_file() {
    echo "Creating [version] file."
    echo $LATEST_VERSION >version
}

# backup server files
backup() {
    echo "Backing up files."
    mkdir -p backup
    rsync -apr --exclude='*vanilla*' --exclude='*chemistry*' --exclude='*backup*' {behavior_packs,resource_packs} backup
    rsync -apr --ignore-missing-args {permissions.json,server.properties,whitelist.json} backup
}

# restore server files
restore() {
    echo "Restoring previous configurations."
    rsync -ar backup/ ./
}

# compare local version with the one from internet
update() {
    echo "Checking for updates."
    if [ "${LOCAL_VERSION}" == "${LATEST_VERSION}" ]; then
        echo "Server is up to date. Server version: $LOCAL_VERSION"
        echo "Run server? (y/n)"
        read RUN_SERVER_ANSWER
        case $RUN_SERVER_ANSWER in
        y)
            run_server
            ;;
        n)
            echo "Exiting script."
            exit
            ;;
        esac
    else
        echo "Different version found."
        echo "Installed version: $LOCAL_VERSION"
        echo "Latest version: $LATEST_VERSION"
        echo "Would you like to update? (y/n)"
        read UPDATE_SERVER_ANSWER
        case $UPDATE_SERVER_ANSWER in
        y)
            pipeline backup download extract update_version_file restore success
            ;;
        n)
            echo "Exiting script."
            exit
            ;;
        esac
    fi
}

# complete workflow
main() {
    # check if current folder contains server files
    if [ -f bedrock_server ] && [ -f bedrock_server_realms.debug ] && [ -d behavior_packs ] && [ -d resource_packs ]; then
        update
    else
        # prompt user to install server
        echo "Server files not fount. Would you like to download and install? (y/n)"
        read INSTALL_SERVER_ANSWER
        case $INSTALL_SERVER_ANSWER in
        y)
            pipeline download extract update_version_file success remind
            ;;
        n)
            echo "Exiting script."
            exit
            ;;
        esac
    fi
}

# echo every variable
print_variables() {
    echo "DOWNLOAD_URL = $DOWNLOAD_URL"
    echo "LATEST_VERSION = $LATEST_VERSION"
    echo "LOCAL_VERSION = $LOCAL_VERSION"
    echo "DOWNLOADED_FILE = $DOWNLOADED_FILE"
}

# ----------start----------

echo "Be sure to manually back up any behavior or resource pack that contains the word 'vanilla' or 'chemistry' as the script will ignore those packs considering it's part of the server installation content."

pipeline set_variables "pkg_check unzip rsync curl" main
