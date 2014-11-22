#!/bin/sh
#======================================================================================
#
# FILE: setup.sh
#
# USAGE: setup.sh [-hdsp] [-n screen_name] [-j jar_name] [-v version]
#
# DESCRIPTION: Sets up a base server
#
# OPTIONS: see function ’usage’ below
# REQUIREMENTS: screen, jdk (installable via script)
# BUGS: ---
# NOTES: ---
# AUTHOR: Graham Howden, graham_howden1@yahoo.co.uk
#======================================================================================

FILE_NAME="minecraft_server.jar"  # file name to store JAR as
SCREEN_NAME="uhc_minecraft"       # screen name to run under

# all false by default
SKIP_INSTALL=false
SKIP_DOWNLOAD=false
SKIP_PROPERTIES=false
JAR_DOWNLOADED=false

#=== FUNCTION =========================================================================
# NAME: usage
# DESCRIPTION: Display usage information for this script.
#======================================================================================
usage()
{
  cat <<-EOT
  usage: $(basename "$0") [-hdsp] [-n screen_name] [-j jar_name] [-v version]

    -h show this help message
    -n choose the screen name to use (default '${SCREEN_NAME}')
    -j choose the name of the server jar to create (default '${FILE_NAME}'
    -v version to download (will be prompted if not provided)
    -d skips screen/java install
    -s skips JAR download
    -p skips server.properties write
EOT
}

#=== FUNCTION =========================================================================
# NAME: download_jar
# DESCRIPTION: Downloads the JAR of version $VERSION (parameter 2) to the file name
# $FILE_NAME (parameter 1) from the URL
# https://s3.amazonaws.com/Minecraft.Download/versions/${VERSION}/minecraft_server.${VERSION}.jar.
# Sets $JAR_DOWNLOADED when downloaded.
# PARAMETER 1: File name to write to
# PARAMETER 2: Version # to download
# RETURNS: 0 on success and 1 on failure to download
#======================================================================================
download_jar()
{
  # fetch the jar with the given version
  wget --no-check-certificate -O "$1" "https://s3.amazonaws.com/Minecraft.Download/versions/$2/minecraft_server.$2.jar"

  if [ $? -eq 0 ]
  then
    echo "Downloaded server version $2"
    JAR_DOWNLOADED=true
    return 0
  else
    echo "ERROR: Couldn't fetch server version $2" >&2
    return 1
  fi
}

#=== FUNCTION =========================================================================
# NAME: download_jar_prompts
# DESCRIPTION: Asks the user for a version # and attempts to download that version.
# Reasks for the version number after every failed download
# PARAMETER 1: Name of the file to save into
#======================================================================================
download_jar_prompts()
{
  until [ "$JAR_DOWNLOADED" = true ]
  do
    read_version
    download_jar "$1" "$VERSION"
  done
}

#=== FUNCTION =========================================================================
# NAME: read_version
# DESCRIPTION: Asks the user for a version number and reads it into $VERSION
#======================================================================================
read_version()
{
  read -p "What version do you like to install? " VERSION
}

#=== FUNCTION =========================================================================
# NAME: install_dependencies
# DESCRIPTION: Installs the required dependencies for the script (screen and a JDK)
# NOTES: Only works on systems with apt-get
#======================================================================================
install_dependencies()
{
  echo "Installing dependencies"
  apt-get update
  apt-get install -y screen default-jdk
}

#=== FUNCTION =========================================================================
# NAME: write_default_properties
# DESCRIPTION: Writes a simple server.properties file
#======================================================================================
write_default_properties()
{
  cat <<-EOT > server.properties
op-permission-level=4
allow-nether=true
level-name=world
allow-flight=true
announce-player-achievements=false
server-port=25565
white-list=true
spawn-animals=true
hardcore=false
snooper-enabled=true
online-mode=true
pvp=true
difficulty=3
enable-command-block=true
gamemode=0
spawn-monsters=true
generate-structures=true
view-distance=8
motd=Insorum UHC
EOT
}

#=== FUNCTION =========================================================================
# NAME: write_eula_file
# DESCRIPTION: Writes a valid eula.txt
#======================================================================================
write_eula_file()
{
  echo "eula=true" > eula.txt
}

# parse all the options
while getopts "n:j:v:hsdp" opt
do
  case "$opt" in
  n) SCREEN_NAME="${OPTARG}";;
  j) FILE_NAME="${OPTARG}";;
  v) VERSION="${OPTARG}";;
  d) SKIP_INSTALL=true;;
  s) SKIP_DOWNLOAD=true;;
  p) SKIP_PROPERTIES=true;;
  [?h])
    usage
    exit 1
    ;;
  esac
done

# update packages and install our dependencies
if [ "$SKIP_INSTALL" = true ]
then
  echo "Skipping dependency install..."
else
  install_dependencies
fi

if [ "$SKIP_DOWNLOAD" = true ]
then
  echo "Skipping JAR download..."
  JAR_DOWNLOADED=true
else
  # if user provided only attempt to download that one
  if [ ! -z "$VERSION" ]
  then
    if [ ! download_jar "$FILE_NAME" "$VERSION" ]
    then
      echo "Failed to download chosen version. Cancelling" >&2
      exit 1
    fi
  # otherwise we loop and ask the user until we find one
  else
    download_jar_prompts "$FILE_NAME"
  fi
fi

# set the eula=true file nonsense
echo "Setting up eula.txt..."
write_eula_file

# setup properties file
if [ "$SKIP_PROPERTIES" = true ]
then
  echo "Skipping writing default properties..."
else
  write_default_properties
fi

# start a screen with the server in it
echo "Starting up server..."
if screen -dmS "${SCREEN_NAME}" sh -c "java -jar ${FILE_NAME} nogui"
then
  echo "Server started, you can open the console via screen by using the command: 'screen -r ${SCREEN_NAME}'"
else
  echo "Failed to start the server on screen named ${SCREEN_NAME}, server may need to be started manually" >&2
fi