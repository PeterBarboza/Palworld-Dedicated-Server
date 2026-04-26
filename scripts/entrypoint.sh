#!/bin/bash
set -e

PALSERVER_DIR="/home/steam/palserver"
STEAMCMD="/home/steam/steamcmd/steamcmd.sh"
PALSERVER_APP_ID=2394010

# --- Install / Update the server ---
echo "==> Installing/updating Palworld Dedicated Server (AppID: ${PALSERVER_APP_ID})..."
${STEAMCMD} \
    +force_install_dir "${PALSERVER_DIR}" \
    +login anonymous \
    +app_update ${PALSERVER_APP_ID} validate \
    +quit

# Steamcmd fix: link steamclient.so so the server finds it
mkdir -p /home/steam/.steam/sdk64
ln -sf "${PALSERVER_DIR}/linux64/steamclient.so" /home/steam/.steam/sdk64/steamclient.so 2>/dev/null || true

# --- Apply settings from env vars ---
SETTINGS_DIR="${PALSERVER_DIR}/Pal/Saved/Config/LinuxServer"
SETTINGS_FILE="${SETTINGS_DIR}/PalWorldSettings.ini"

# Generate default config if first run
if [ ! -f "${SETTINGS_FILE}" ]; then
    echo "==> First run detected. Starting server briefly to generate default config..."
    mkdir -p "${SETTINGS_DIR}"

    # Copy the default settings template if it exists
    DEFAULT_SETTINGS="${PALSERVER_DIR}/DefaultPalWorldSettings.ini"
    if [ -f "${DEFAULT_SETTINGS}" ]; then
        cp "${DEFAULT_SETTINGS}" "${SETTINGS_FILE}"
        echo "==> Default settings copied."
    fi
fi

# Apply env-based overrides (any env var starting with PAL_ maps to a setting)
# Example: PAL_ServerName="My Server" -> ServerName="My Server"
#
# Palworld stores all settings on a single OptionSettings=(K=V,K=V,...) line.
# String fields are quoted in the default file (e.g. AdminPassword=""), and
# the parser silently drops unquoted strings — so we MUST preserve quotes when
# the original entry has them. Numbers/bools/enums stay unquoted.
#
# Anchor each replacement with the leading `(` or `,` so a key that is a
# substring of another (e.g. AdditionalDropItem... vs bAdditionalDropItem...)
# only matches the right occurrence. Use `|` as sed delimiter so values
# containing `/` (URLs) don't break the expression.
if [ -f "${SETTINGS_FILE}" ]; then
    while IFS='=' read -r key value; do
        if [[ "${key}" == PAL_* ]]; then
            setting_name="${key#PAL_}"
            # Escape sed replacement metacharacters in the value (& and |).
            esc_value=$(printf '%s' "${value}" | sed -e 's/[&|]/\\&/g')
            if grep -qE "[(,]${setting_name}=\"" "${SETTINGS_FILE}"; then
                echo "==> Applying setting: ${setting_name}=\"${value}\""
                sed -i -E "s|([(,])${setting_name}=\"[^\"]*\"|\1${setting_name}=\"${esc_value}\"|" "${SETTINGS_FILE}"
            elif grep -qE "[(,]${setting_name}=" "${SETTINGS_FILE}"; then
                echo "==> Applying setting: ${setting_name}=${value}"
                sed -i -E "s|([(,])${setting_name}=[^,)]*|\1${setting_name}=${esc_value}|" "${SETTINGS_FILE}"
            else
                echo "==> Skipping unknown setting: ${setting_name}"
            fi
        fi
    done < <(env)
fi

# --- Build launch args ---
LAUNCH_ARGS=""

if [ -n "${COMMUNITY_SERVER}" ] && [ "${COMMUNITY_SERVER}" = "true" ]; then
    LAUNCH_ARGS="${LAUNCH_ARGS} EpicApp=PalServer"
fi

if [ -n "${MULTITHREAD}" ] && [ "${MULTITHREAD}" = "true" ]; then
    LAUNCH_ARGS="${LAUNCH_ARGS} -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS"
fi

if [ -n "${EXTRA_ARGS}" ]; then
    LAUNCH_ARGS="${LAUNCH_ARGS} ${EXTRA_ARGS}"
fi

echo "==> Starting Palworld Dedicated Server..."
echo "    Launch args: ${LAUNCH_ARGS}"
cd "${PALSERVER_DIR}"
exec ./PalServer.sh ${LAUNCH_ARGS}
