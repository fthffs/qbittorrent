#!/usr/bin/env bash

qbittorrent() {
  qbittorrent_url="https://api.github.com/repos/qbittorrent/qBittorrent/tags"
  local new_version="$(curl -SsL ${qbittorrent_url} | jq -r -c '.[] | .name' | grep -iv 'rc\|beta\|alpha' | head -n 1 | sed 's/release-//')"

  if [ "${new_version}" ]; then
    sed -i "s/QBT_VERSION=.*/QBT_VERSION=${new_version}/" qbittorrent/Dockerfile
  fi

  if output=$(git status --porcelain) && [ -z "$output" ]; then
    # working directory clean
    echo "no new qbittorrent version available!"
  else
    # uncommitted changes
    git commit -a -m "updated qbittorrent to version: ${new_version}"
    git push
  fi
}

qbittorrent
