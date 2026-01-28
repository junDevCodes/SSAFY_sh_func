#!/bin/bash
# =============================================================================
# 릴리즈 태그와 VERSION 파일 일치 검증 스크립트
# - 태그명(예: V8.1.2)과 루트 VERSION 파일 값이 동일해야 함
# - CI에서 사용하기 위한 최소 기능 스크립트
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"

if [ ! -f "$VERSION_FILE" ]; then
  echo "❌ VERSION 파일을 찾을 수 없습니다: $VERSION_FILE" >&2
  exit 1
fi

read -r VERSION_VALUE < "$VERSION_FILE" || true
VERSION_VALUE="${VERSION_VALUE//$'\r'/}"
VERSION_VALUE="${VERSION_VALUE//[[:space:]]/}"

if [ -z "${VERSION_VALUE:-}" ]; then
  echo "❌ VERSION 파일이 비어 있습니다: $VERSION_FILE" >&2
  exit 1
fi

TAG_NAME="${1:-}"
if [ -z "${TAG_NAME:-}" ]; then
  echo "❌ 태그명을 인자로 전달해야 합니다. 예) ./ci/check_tag_matches_version.sh V8.1.2" >&2
  exit 1
fi

if [ "$TAG_NAME" != "$VERSION_VALUE" ]; then
  echo "❌ 릴리즈 태그와 VERSION이 일치하지 않습니다. (TAG: $TAG_NAME, VERSION: $VERSION_VALUE)" >&2
  exit 1
fi

echo "✅ 릴리즈 태그와 VERSION이 일치합니다. ($TAG_NAME)"
