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

file_name="minecraft_server.jar"  # file name to store JAR as
screen_name="uhc_minecraft"       # screen name to run under

#=== FUNCTION =========================================================================
# NAME: usage
# DESCRIPTION: Display usage information for this script.
#======================================================================================
usage()
{
  cat <<-EOT
  usage: $(basename "$0") [-hdsp] [-n screen_name] [-j jar_name] [-v version]

    -h show this help message
    -n choose the screen name to use (default '${screen_name}')
    -j choose the name of the server jar to create (default '${file_name}'
    -v version to download (will be prompted if not provided)
    -d skips screen/java install
    -s skips JAR download
    -p skips server.properties write
EOT
}

#=== FUNCTION =========================================================================
# NAME: download_jar
# DESCRIPTION: Downloads the JAR of version $version (parameter 2) to the file name
# $file_name (parameter 1) from the URL
# https://s3.amazonaws.com/Minecraft.Download/versions/${version}/minecraft_server.${version}.jar.
# Sets $jar_downloaded when downloaded.
# PARAMETER 1: File name to write to
# PARAMETER 2: Version # to download
# RETURNS: 0 on success and 1 on failure to download
#======================================================================================
download_jar()
{
  # fetch the jar with the given version
  if wget --no-check-certificate -O "$1" "https://s3.amazonaws.com/Minecraft.Download/versions/$2/minecraft_server.$2.jar"
  then
    echo "Downloaded server version $2"
    jar_downloaded=true
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
  until [ "$jar_downloaded" = true ]
  do
    read_version
    download_jar "$1" "$version"
  done
}

#=== FUNCTION =========================================================================
# NAME: read_version
# DESCRIPTION: Asks the user for a version number and reads it into $version
#======================================================================================
read_version()
{
  read -p "What version do you like to install? " version
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
  n) screen_name="${OPTARG}";;
  j) file_name="${OPTARG}";;
  v) version="${OPTARG}";;
  d) skip_install=true;;
  s) skip_download=true;;
  p) skip_properties=true;;
  [?h])
    usage
    exit 1
    ;;
  esac
done

# update packages and install our dependencies
if [ "${skip_install:-false}" = true ]
then
  echo "Skipping dependency install..."
else
  install_dependencies
fi

if [ "${skip_download:-false}" = true ]
then
  echo "Skipping JAR download..."
  jar_downloaded=true
else
  # if user provided only attempt to download that one
  if [ ! -z "$version" ]
  then
    if ! download_jar "$file_name" "$version"
    then
      echo "Failed to download chosen version. Cancelling" >&2
      exit 1
    fi
  # otherwise we loop and ask the user until we find one
  else
    download_jar_prompts "$file_name"
  fi
fi

# set the eula=true file nonsense
echo "Setting up eula.txt..."
write_eula_file

# setup properties file
if [ "${skip_properties:-false}" = true ]
then
  echo "Skipping writing default properties..."
else
  write_default_properties
fi

# start a screen with the server in it
echo "Starting up server..."
if screen -dmS "${screen_name}" sh -c "java -jar ${file_name} nogui"
then
  echo "Server started, you can open the console via screen by using the command: 'screen -r ${screen_name}'"
else
  echo "Failed to start the server on screen named ${screen_name}, server may need to be started manually" >&2
fi