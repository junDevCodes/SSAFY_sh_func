#!/bin/bash
# tests/verify_v8_1.sh
# V8.1 Kill Switch 및 모듈 로딩 검증 스크립트

# 스크립트 내에서 별칭(alias) 사용 허용
shopt -s expand_aliases

echo "=================================================="
echo "🧪 V8.1 자동 검증을 시작합니다..."
echo "=================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# 1. Source Test (모듈 로딩)
echo ""
echo "test [1/4] 모듈 로딩 테스트..."
if source "algo_functions.sh"; then
    echo "✅ Source 성공"
else
    echo "❌ Source 실패"
    exit 1
fi

# 2. Kill Switch Test Setup
STATUS_FILE="status.json"
BACKUP_FILE="status.json.bak"
# [Fix] 로컬 테스트를 위해 환경변수 설정 (lib/utils.sh가 이를 우선 사용)
export ALGO_STATUS_URL="file://$(pwd)/$STATUS_FILE"

echo ""
echo "test [2/4] Kill Switch - Active (정상) 테스트"
# 백업
cp "$STATUS_FILE" "$BACKUP_FILE"

# Active 설정
cat > "$STATUS_FILE" <<EOF
{
  "status": "active",
  "message": "System Operational"
}
EOF

# ssafy_algo_doctor 실행 (정상이어야 함)
if ssafy_algo_doctor | grep -q "SSAFY Algo Tools Doctor"; then
    echo "✅ [Active] 정상 작동 확인"
else
    echo "❌ [Active] 작동 실패"
fi

echo ""
echo "test [3/4] Kill Switch - Maintenance (점검) 테스트"
# Maintenance 설정
cat > "$STATUS_FILE" <<EOF
{
  "status": "maintenance",
  "message": "Scheduled Maintenance"
}
EOF

# ssafy_algo_doctor 실행 (경고 메시지 확인)
OUTPUT=$(ssafy_algo_doctor)
if echo "$OUTPUT" | grep -q "⚠️  \[공지\] Scheduled Maintenance"; then
    echo "✅ [Maintenance] 경고 메시지 확인"
else
    echo "❌ [Maintenance] 경고 메시지 미출력"
    echo "출력값: $OUTPUT"
fi


echo ""
echo "test [4/4] Kill Switch - Outage (중단) 테스트"
# Outage 설정
cat > "$STATUS_FILE" <<EOF
{
  "status": "outage",
  "message": "Critical Security Issue"
}
EOF

# ssafy_algo_doctor 실행 (중단 및 실패 코드 확인)
# Outage시 return 1을 하므로 if ! 로 잡아야 함
if ! OUTPUT=$(ssafy_algo_doctor) || echo "$OUTPUT" | grep -q "❌ \[긴급\]"; then
    echo "✅ [Outage] 실행 차단 확인"
else
    echo "❌ [Outage] 차단되지 않았거나 메시지 오류"
    echo "출력값: $OUTPUT"
fi

# 3. Cleanup
echo ""
echo "🧹 테스트 정리 중..."
mv "$BACKUP_FILE" "$STATUS_FILE"

echo "=================================================="
echo "🎉 모든 검증이 완료되었습니다!"
echo "=================================================="
