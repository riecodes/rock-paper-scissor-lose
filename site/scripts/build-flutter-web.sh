#!/usr/bin/env bash

set -euo pipefail

# Keep this revision aligned with app/.metadata. Fetching the exact revision
# makes Vercel builds reproducible without committing generated web assets.
FLUTTER_VERSION="3.41.6"
FLUTTER_REVISION="db50e20168db8fee486b9abf32fc912de3bc5b6a"

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIRECTORY="${REPOSITORY_ROOT}/app"
SITE_DIRECTORY="${REPOSITORY_ROOT}/site"
PUBLIC_DIRECTORY="${SITE_DIRECTORY}/public"
OUTPUT_DIRECTORY="${PUBLIC_DIRECTORY}/play"
TEMPORARY_ROOT="${TMPDIR:-/tmp}"
FLUTTER_DIRECTORY="${FLUTTER_ROOT:-${TEMPORARY_ROOT}/flutter-${FLUTTER_REVISION}}"

if [[ ! -f "${APP_DIRECTORY}/pubspec.yaml" ]]; then
  echo "Flutter source not found at ${APP_DIRECTORY}."
  echo "Enable 'Include source files outside of the Root Directory' in Vercel."
  exit 1
fi

if ! grep -Fq "revision: \"${FLUTTER_REVISION}\"" "${APP_DIRECTORY}/.metadata"; then
  echo "FLUTTER_REVISION does not match app/.metadata."
  exit 1
fi

if [[ ! -f "${FLUTTER_DIRECTORY}/bin/flutter" ]]; then
  for required_command in git unzip; do
    if ! command -v "${required_command}" >/dev/null 2>&1; then
      echo "Required build command not found: ${required_command}"
      exit 1
    fi
  done

  rm -rf "${FLUTTER_DIRECTORY}"
  mkdir -p "${FLUTTER_DIRECTORY}"

  git -C "${FLUTTER_DIRECTORY}" init --quiet
  git -C "${FLUTTER_DIRECTORY}" remote add origin https://github.com/flutter/flutter.git
  git -C "${FLUTTER_DIRECTORY}" -c protocol.version=2 fetch \
    --depth=1 \
    --filter=blob:none \
    origin "refs/tags/${FLUTTER_VERSION}:refs/tags/${FLUTTER_VERSION}"
  git -C "${FLUTTER_DIRECTORY}" checkout --quiet --detach "refs/tags/${FLUTTER_VERSION}"

  actual_revision="$(git -C "${FLUTTER_DIRECTORY}" rev-parse HEAD)"
  if [[ "${actual_revision}" != "${FLUTTER_REVISION}" ]]; then
    echo "Flutter ${FLUTTER_VERSION} resolved to unexpected revision ${actual_revision}."
    exit 1
  fi
fi

export CI=true
export PATH="${FLUTTER_DIRECTORY}/bin:${PATH}"
export PUB_CACHE="${PUB_CACHE:-${TEMPORARY_ROOT}/flutter-pub-cache}"

flutter config --no-analytics
flutter precache --web

cd "${APP_DIRECTORY}"
flutter pub get --enforce-lockfile

rm -rf "${PUBLIC_DIRECTORY}"
mkdir -p "${PUBLIC_DIRECTORY}"
cp "${SITE_DIRECTORY}/index.html" "${PUBLIC_DIRECTORY}/index.html"
for static_directory in ads img sfx; do
  cp -R "${SITE_DIRECTORY}/${static_directory}" "${PUBLIC_DIRECTORY}/${static_directory}"
done

flutter build web \
  --release \
  --no-pub \
  --no-wasm-dry-run \
  --base-href /play/ \
  --output "${OUTPUT_DIRECTORY}"

test -f "${PUBLIC_DIRECTORY}/index.html"
test -f "${OUTPUT_DIRECTORY}/index.html"
echo "Flutter web build created at ${OUTPUT_DIRECTORY}."
