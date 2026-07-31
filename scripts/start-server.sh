#!/bin/bash
if [ ! -f ${STEAMCMD_DIR}/steamcmd.sh ]; then
    echo "SteamCMD not found!"
    wget -q -O ${STEAMCMD_DIR}/steamcmd_linux.tar.gz http://media.steampowered.com/client/steamcmd_linux.tar.gz 
    tar --directory ${STEAMCMD_DIR} -xvzf /serverdata/steamcmd/steamcmd_linux.tar.gz
    rm ${STEAMCMD_DIR}/steamcmd_linux.tar.gz
fi

echo "---Update SteamCMD---"
if [ "${USERNAME}" == "" ]; then
    ${STEAMCMD_DIR}/steamcmd.sh \
    +login anonymous \
    +quit
else
    ${STEAMCMD_DIR}/steamcmd.sh \
    +login ${USERNAME} ${PASSWRD} \
    +quit
fi

echo "---Update Server---"
if [ "${USERNAME}" == "" ]; then
    if [ "${VALIDATE}" == "true" ]; then
    	echo "---Validating installation---"
        ${STEAMCMD_DIR}/steamcmd.sh \
        +force_install_dir ${SERVER_DIR} \
        +login anonymous \
        +app_update ${GAME_ID} validate \
        +quit
    else
        ${STEAMCMD_DIR}/steamcmd.sh \
        +force_install_dir ${SERVER_DIR} \
        +login anonymous \
        +app_update ${GAME_ID} \
        +quit
    fi
else
    if [ "${VALIDATE}" == "true" ]; then
    	echo "---Validating installation---"
        ${STEAMCMD_DIR}/steamcmd.sh \
        +force_install_dir ${SERVER_DIR} \
        +login ${USERNAME} ${PASSWRD} \
        +app_update ${GAME_ID} validate \
        +quit
    else
        ${STEAMCMD_DIR}/steamcmd.sh \
        +force_install_dir ${SERVER_DIR} \
        +login ${USERNAME} ${PASSWRD} \
        +app_update ${GAME_ID} \
        +quit
    fi
fi

echo "---Prepare Server---"
echo "---Setting up Environment---"
export PATH="${SERVER_DIR}/jre64/bin:$PATH"
export LD_LIBRARY_PATH="${SERVER_DIR}/linux64:${SERVER_DIR}/natives:${SERVER_DIR}:${SERVER_DIR}/jre64/lib/amd64:${LD_LIBRARY_PATH}"
export JSIG="libjsig.so"
export JARPATH="java/:java/lwjgl.jar:java/lwjgl_util.jar:java/sqlite-jdbc-3.8.10.1.jar:java/uncommons-maths-1.2.3.jar"
echo "---Looking for server configuration file---"
if [ ! -d ${SERVER_DIR}/Zomboid ]; then
	echo "---No server configuration found---"
	echo "---The server will generate a current one on this first start---"
	echo "---Settings will appear in Zomboid/Server/servertest.ini shortly---"
else
	echo "---Server configuration files found!---"
fi

if [ "${ADMIN_PWD}" == "adminDocker" ]; then
	echo "---------------------------------------------------------------"
	echo "ADMIN_PWD is still the default value, which is published in this"
	echo "image's documentation and is therefore public knowledge. Set"
	echo "ADMIN_PWD to something else before exposing this server."
	echo "---------------------------------------------------------------"
fi

# Optional: force the join password from the environment on every boot.
# Unset means "leave the ini alone" so manual edits survive; set-but-empty
# (SERVER_PASSWORD=) explicitly clears the password. These are different, which
# is why this tests for definedness rather than for a non-empty value.
if [ -n "${SERVER_PASSWORD+defined}" ]; then
	PZ_INI="${SERVER_DIR}/Zomboid/Server/servertest.ini"
	if [ -f "${PZ_INI}" ]; then
		if grep -q '^Password=' "${PZ_INI}"; then
			sed -i "s|^Password=.*|Password=${SERVER_PASSWORD}|" "${PZ_INI}"
		else
			echo "Password=${SERVER_PASSWORD}" >> "${PZ_INI}"
		fi
		if [ -z "${SERVER_PASSWORD}" ]; then
			echo "---Join password cleared, server is open---"
		else
			echo "---Join password set from SERVER_PASSWORD---"
		fi
	else
		echo "---Can't find ${PZ_INI}, skipping password override---"
	fi
fi

echo "---Checking for old logs---"
find ${SERVER_DIR} -name "masterLog.0" -exec rm -f {} \; > /dev/null 2>&1
chmod -R ${DATA_PERM} ${DATA_DIR}
echo "---Server ready---"

echo "---Start Server---"
cd ${SERVER_DIR}
# ProjectZomboid64 is a launcher, not the server. Everything before `--` is
# handed to the JVM, everything after goes to the game. Without the separator
# the JVM sees -adminpassword, refuses the option, and dies with
# "Failed to create Java VM". JVM args (-Xmx, -Xms) therefore go in
# GAME_PARAMS ahead of the separator; game args go after it.
screen -S PZ -L -Logfile ${SERVER_DIR}/masterLog.0 -d -m ${SERVER_DIR}/ProjectZomboid64 ${GAME_PARAMS} -- -adminpassword ${ADMIN_PWD}
sleep 2
screen -S watchdog -d -m /opt/scripts/start-watchdog.sh
tail -f ${SERVER_DIR}/masterLog.0