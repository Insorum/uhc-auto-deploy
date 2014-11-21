#!/bin/sh

URL_BASE="https://s3.amazonaws.com/Minecraft.Download/versions/"
FILE_NAME="minecraft_server.jar"
SCREEN_NAME="uhc_minecraft"

# all false by default
SKIP_INSTALL=1
SKIP_DOWNLOAD=1
SKIP_PROPERTIES=1
JAR_DOWNLOADED=1

USAGE="$(basename "$0") [-hdsp] [-n screen_name] [-j jar_name] [-v version]

where:
    -h show this help message
    -n choose the screen name to use (default '${SCREEN_NAME}')
    -j choose the name of the server jar to create (default '${FILE_NAME}'
    -v version to download (will be prompted if not provided)
    -d skips screen/java install
    -s skips JAR download
    -p skips server.properties write"

DEFAULT_PROPERTIES="op-permission-level=4
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
motd=Insorum UHC"

# Downloads the version set in $VERSION (prompts for input if wasnt able to fetch it
# Returns 0 on success and 1 on failure
download_jar_version()
{
  # if version isnt set then prompt for it
  if [ ! -z "$VERSION" ]
  then
    read_version
  fi

  # fetch the jar with the given version
  wget --no-check-certificate -O ${FILE_NAME} ${URL_BASE}${VERSION}/minecraft_server.${VERSION}.jar

  if [ $? -eq 0 ]
  then
    echo "Downloaded server version ${VERSION}"
    JAR_DOWNLOADED=0
    return 0
  else
    echo "ERROR: Couldn't fetch server version ${VERSION}" >&2
    return 1
  fi
}


download_jar_prompts()
{
  until [ ${JAR_DOWNLOADED} ]
  do
    read_version
    download_jar
  done
}

# read the version # to use
read_version()
{
  read -e -p "What version do you like to install? " VERSION
}

# installs the required dependencies we need to run
install_dependencies()
{
  echo "Installing dependencies"
  apt-get update
  apt-get install -y screen default-jdk
}

# parse all the options
while getopts "n:j:v:hsp" opt
do
  case "$opt" in
  n) SCREEN_NAME="${OPTARG}";;
  j) FILE_NAME="${OPTARG}";;
  v) VERSION="${OPTARG}";;
  d) SKIP_INSTALL=0;;
  s) SKIP_DOWNLOAD=0;;
  p) SKIP_PROPERTIES=0;;
  [?h])
    echo "${USAGE}"
    exit 1
    ;;
  esac
done

# update packages and install our dependencies
if [ ${SKIP_INSTALL} ]
then
  echo "Skipping dependency install..."
else
  install_dependencies
fi

if [ ${SKIP_DOWNLOAD} ]
then
  echo "Skipping JAR download..."
  JAR_DOWNLOADED=0
else
  # if user provided only attempt to download that one
  if [ ! -z "$VERSION" ]
  then
    if [ ! download_jar_version ]
    then
      echo "Failed to download chosen version. Cancelling" >&2
      exit 1
    fi
  # otherwise we loop and ask the user until we find one
  else
    download_jar_prompts
  fi
fi

# set the eula=true file nonsense
echo "Setting up eula.txt..."
echo "eula=true" > eula.txt

# setup properties file
if ! ${SKIP_PROPERTIES}
then
  echo "${DEFAULT_PROPERTIES}" > server.properties
else
  echo "Skipping writing default properties..."
fi

# start a screen with the server in it
echo "Starting up server..."
if screen -dmS ${SCREEN_NAME} -c bash "java -jar ${FILE_NAME} nogui"
then
  echo "Server started, you can open the console via screen by using the command: 'screen -r ${SCREEN_NAME}'"
else
  echo "Failed to start the server on screen named ${SCREEN_NAME}, server may need to be started manually" >&2
fi