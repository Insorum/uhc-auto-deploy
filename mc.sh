#!/bin/sh
#======================================================================================
#
# FILE: mc.sh
#
# USAGE: see function 'usage' below
#
# DESCRIPTION: Sets up a base server
#
# OPTIONS: see function 'usage' below
# REQUIREMENTS: screen, jdk (both installable via script)
# NOTES: ---
# AUTHOR: Graham Howden, graham_howden1@yahoo.co.uk
#======================================================================================

file_name="minecraft_server.jar"  # file name to store JAR as
screen_name="uhc_minecraft"       # screen name to run under

# ERROR CODES
E_FAILED_DEPENDENCIES=100
E_FAILED_JAR_DOWNLOAD=101
E_UNKNOWN_OPTION=102

#=== FUNCTION =========================================================================
# NAME: usage
# DESCRIPTION: Display usage information for this script.
#======================================================================================
usage()
{
  cat <<-EOT
  usage:
    $0 install [-o] [-s] [-v version]
    $0 console
    $0 download
    $0 stop
    $0 start
    $0 help

  subcommands:

    install   - downloads the .jar, sets up server.properties + eula.txt and starts the server
      options:
        -o    - overwrite any existing files instead of skipping them (server JAR, server.properties and eula.txt)
        -v    - version to download (if provided will download over existing file, if not supplied and no file exists
                  user will be prompted for a version number)
        -s    - Skip startup of the server after install

    console   - attemtps to attach to the current console

    download  - download a server jar

    start     - attempts to start the server, if the server is already running loads the console instead
      options:
        -M    - set the max amount of RAM for the server to use, defaults to 2048M

    stop      - attempts to stop a running server

    help      - this help message

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
# RETURNS: 0 on success and E_FAILED_JAR_DOWNLOAD on failure to download
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
    return ${E_FAILED_JAR_DOWNLOAD}
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
  apt-get install -y screen default-jdk
  return 0
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

#=== FUNCTION =========================================================================
# NAME: start_server
# DESCRIPTION: Attempts to start the server via screen
# PARAMETER 1: Max amount of ram to use
#======================================================================================
start_server()
{
  screen -dmS "$screen_name" sh -c "java -jar -Xmx$1 ${file_name} nogui"  # command to use to start the server
  return $?
}

#=== FUNCTION =========================================================================
# NAME: start_server
# DESCRIPTION: Attempts to reattach to the screen
#======================================================================================
reattach_console()
{
  screen -r "$screen_name"
  return $?
}

subcommand="$1"

# shift to remove subcommand arg
shift

# check command ran
case "$subcommand" in
  install)
    echo 'Starting install...'

    # check if overwrite was set
    overwrite=false;
    while getopts "v:os" opt
    do
      case "$opt" in
      o) overwrite=true;;
      v) version="$OPTARG";;
      s) skip_start=true;;
      *) exit ${E_UNKNOWN_OPTION};;
      esac
    done

    # Handle dependencies first
    if ! install_dependencies
    then
      echo 'Failed to install required dependencies'
      exit ${E_FAILED_DEPENDENCIES}
    fi

    # if $version is supplied attempt to download the specific JAR
    if [ ! -z "$version" ]
    then
      if ! download_jar "$file_name" "$version"
      then
        exit ${E_FAILED_JAR_DOWNLOAD}
      fi
    # else if the JAR file doesn't exist or we're in overwrite mode
    elif [[ "$overwrite" = true ]] || [[ ! -e "${file_name}" ]]
    then
      download_jar_prompts "$file_name"
    else
      echo 'Skipping JAR download...'
    fi

    # set the eula=true file nonsense
    if [[ "$overwrite" = true ]] || [[ ! -e 'eula.txt' ]]
    then
      echo 'Setting up eula.txt...'
      write_eula_file
    else
      echo 'Skipping eula.txt file...'
    fi

    # setup properties file
    if [[ "$overwrite" = true ]] || [[ ! -e 'server.properties' ]]
    then
      echo 'Setting up server.properties...'
      write_default_properties
    else
      echo 'Skipping writing default properties...'
    fi

    # handle starting the server up
    if [[ "$skip_start" = true ]]
    then
      echo 'Skipping server startup...'
    elif start_server
    then
      echo "Server started, you can open the console via screen by using the command: '$0 console'"
    else
      echo "Failed to start the server on screen named ${screen_name}, server may need to be started manually" >&2
    fi

    # All completed :)
    echo 'Install complete!'
    ;;
  console)
    # attempt to reattach to the screen instance
    reattach_console

    if [[ $? -ne 0 ]]
    then
      echo 'Failed to connect to the console, is the server running?'
    fi

    # exit with screen exit code
    exit $?
    ;;
  start)
    while getopts "M" opt
    do
      case "$opt" in
      M) max_ram="$OPTARG";;
      *) exit ${E_UNKNOWN_OPTION};;
      esac
    done

    # reattach to console if we can, if not start the server
    if ! reattach_console
    then
      if start_server ${max_ram:-2048M}
      then
        echo "Server started, you can open the console via screen by using the command: '$0 console'"
      else
        echo "Failed to start the server on screen named ${screen_name}, server may need to be started manually" >&2
      fi
    fi
    ;;
  download)
    while getopts "v:" opt
    do
      case "$opt" in
      v) version="$OPTARG";;
      *) exit ${E_UNKNOWN_OPTION};;
      esac
    done

    # if $version is supplied attempt to download the specific JAR
    if [ ! -z "$version" ]
    then
      if ! download_jar "$file_name" "$version"
      then
        exit ${E_FAILED_JAR_DOWNLOAD}
      fi
    # else loop until supplied version is correct
    else
      download_jar_prompts "$file_name"
    fi
    ;;
  stop)
    # force the screen to quit
    screen -r -S "$screen_name" -X quit 2>/dev/null
    exit $?
    ;;
  *)
    usage
    exit 1
    ;;
esac

exit 0