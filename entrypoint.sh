#!/bin/sh

downloadsPath="${QBT_DOWNLOADS_PATH:-/downloads}"
profilePath="${QBT_CONFIG_PATH:-/config}"
qbtConfigFile="$profilePath/qBittorrent.conf"

if [ -z "$QBT_WEBUI_PORT" ]; then
  QBT_WEBUI_PORT=8888
fi

if [ ! -f "$qbtConfigFile" ]; then
  mkdir -p "$(dirname $qbtConfigFile)"
  cat <<EOF >"$qbtConfigFile"
[BitTorrent]
Session\DefaultSavePath=$downloadsPath
Session\Port=6881
Session\TempPath=$downloadsPath/temp

[LegalNotice]
Accepted=true
EOF
fi

qbittorrent-nox --profile="$profilePath" --webui-port="$QBT_WEBUI_PORT" "$@"
