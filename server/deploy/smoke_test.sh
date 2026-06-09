#!/usr/bin/env bash
# 远程代理服务冒烟测试（本机执行，无需 SSH / Docker）
#
# 用法：
#   bash server/deploy/smoke_test.sh
#   SMOKE_BASE_URL=http://127.0.0.1:8000 bash server/deploy/smoke_test.sh
#   SMOKE_SKIP_PROPHECY=1 bash server/deploy/smoke_test.sh   # 不消耗预言配额
#   SMOKE_SKIP_DAILY_PAGE=1 bash server/deploy/smoke_test.sh # 跳过书摘（需 DeepSeek）
#
# 环境变量：
#   SMOKE_BASE_URL      默认 https://tanmystudio.site
#   SMOKE_DEVICE_ID     默认 auto-smoke-<时间戳>（每次新设备，避免耗尽配额）
#   SMOKE_SKIP_PROPHECY     设为 1 时跳过 POST /v1/prophecy（不扣配额）
#   SMOKE_SKIP_DAILY_PAGE   设为 1 时跳过 POST /v1/daily-page
#   SMOKE_TIMEOUT       curl 超时秒数，默认 30

set -euo pipefail

BASE_URL="${SMOKE_BASE_URL:-https://tanmystudio.site}"
BASE_URL="${BASE_URL%/}"
DEVICE_ID="${SMOKE_DEVICE_ID:-auto-smoke-$(date +%s)}"
TIMEOUT="${SMOKE_TIMEOUT:-30}"

PASS=0
FAIL=0
SKIP=0

green() { printf '\033[32m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

pass() {
  PASS=$((PASS + 1))
  green "  ✓ $1"
}

fail() {
  FAIL=$((FAIL + 1))
  red "  ✗ $1"
  if [[ -n "${2:-}" ]]; then
    red "    $2"
  fi
}

skip() {
  SKIP=$((SKIP + 1))
  yellow "  − $1"
}

json_get() {
  local key="$1"
  python3 -c "import json,sys; d=json.load(sys.stdin); v=d.get('${key}',''); print(v if v is not None else '')" 2>/dev/null || true
}

# 输出两行：HTTP 状态码、响应体
run_request() {
  local method="$1" path="$2"
  shift 2
  local url="${BASE_URL}${path}"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(
    curl -sS -m "${TIMEOUT}" -o "${tmp}" -w '%{http_code}' -X "${method}" "$@" "${url}" \
      || echo "000"
  )"
  echo "${code}"
  cat "${tmp}"
  rm -f "${tmp}"
}

split_response() {
  local raw="$1"
  RESPONSE_CODE="$(echo "${raw}" | head -1)"
  RESPONSE_BODY="$(echo "${raw}" | tail -n +2)"
}

assert_status() {
  local name="$1" expect="$2" actual="$3" body="$4"
  if [[ "${actual}" == "${expect}" ]]; then
    pass "${name} → HTTP ${actual}"
  else
    fail "${name} → 期望 HTTP ${expect}，实际 ${actual}" "${body}"
  fi
}

echo "冒烟测试: ${BASE_URL}"
echo "device_id: ${DEVICE_ID}"
echo ""

# --- 1. health ---
split_response "$(run_request GET "/health")"
assert_status "GET /health" "200" "${RESPONSE_CODE}" "${RESPONSE_BODY}"
if [[ "${RESPONSE_CODE}" == "200" ]] && [[ "$(echo "${RESPONSE_BODY}" | json_get status)" == "ok" ]]; then
  pass "health status=ok"
elif [[ "${RESPONSE_CODE}" == "200" ]]; then
  fail "health 响应 status 非 ok" "${RESPONSE_BODY}"
fi

# --- 2. quota (valid device_id) ---
split_response "$(run_request GET "/v1/quota?device_id=${DEVICE_ID}")"
assert_status "GET /v1/quota (合法 device_id)" "200" "${RESPONSE_CODE}" "${RESPONSE_BODY}"

# --- 3. quota (invalid: too short) ---
split_response "$(run_request GET "/v1/quota?device_id=test")"
assert_status "GET /v1/quota (device_id 过短)" "422" "${RESPONSE_CODE}" "${RESPONSE_BODY}"

# --- 4. prophecy GET → 405 ---
split_response "$(run_request GET "/v1/prophecy")"
assert_status "GET /v1/prophecy (应拒绝)" "405" "${RESPONSE_CODE}" "${RESPONSE_BODY}"

# --- 5. prophecy POST bad body → 422 ---
split_response "$(
  run_request POST "/v1/prophecy" \
    -H "Content-Type: application/json" \
    -d '{"device_id":"short"}'
)"
assert_status "POST /v1/prophecy (非法 body)" "422" "${RESPONSE_CODE}" "${RESPONSE_BODY}"

# --- 6. daily-page POST bad body → 422 ---
split_response "$(
  run_request POST "/v1/daily-page" \
    -H "Content-Type: application/json" \
    -d '{"device_id":"short"}'
)"
assert_status "POST /v1/daily-page (device_id 过短)" "422" "${RESPONSE_CODE}" "${RESPONSE_BODY}"

# --- 7. daily-page discovery (换书 nonce>0，不扣配额) ---
if [[ "${SMOKE_SKIP_DAILY_PAGE:-}" == "1" ]]; then
  skip "POST /v1/daily-page (SMOKE_SKIP_DAILY_PAGE=1)"
else
  # 勿在 $(...) 内联 JSON：bash 会把 {"a", "b"} 当成 brace expansion 拆成两次请求
  daily_payload="$(cat <<EOF
{"device_id": "${DEVICE_ID}", "nonce": $(date +%s)}
EOF
)"
  split_response "$(
    run_request POST "/v1/daily-page" \
      -H "Content-Type: application/json" \
      -d "${daily_payload}"
  )"
  if [[ "${RESPONSE_CODE}" == "200" ]]; then
    pass "POST /v1/daily-page (随机探索) → HTTP 200"
    title="$(echo "${RESPONSE_BODY}" | json_get book_title)"
    content="$(echo "${RESPONSE_BODY}" | json_get content)"
    if [[ -n "${title}" && -n "${content}" ]]; then
      pass "书摘: 《${title}》 ${content:0:40}…"
    else
      fail "200 响应缺少 book_title 或 content" "${RESPONSE_BODY}"
    fi
  elif [[ "${RESPONSE_CODE}" == "404" ]]; then
    fail "POST /v1/daily-page 未部署（404），请运行 server/deploy/deploy_update.sh" "${RESPONSE_BODY}"
  elif [[ "${RESPONSE_CODE}" == "502" ]]; then
    fail "DeepSeek 书摘失败（502）" "${RESPONSE_BODY}"
  else
    fail "POST /v1/daily-page → 期望 HTTP 200，实际 ${RESPONSE_CODE}" "${RESPONSE_BODY}"
  fi
fi

# --- 8. prophecy POST success → 200 ---
if [[ "${SMOKE_SKIP_PROPHECY:-}" == "1" ]]; then
  skip "POST /v1/prophecy (SMOKE_SKIP_PROPHECY=1)"
else
  payload="$(cat <<EOF
{
  "device_id": "${DEVICE_ID}",
  "nonce": 1,
  "sensor": {
    "battery": 72,
    "brightness": 55,
    "volume": 30,
    "steps": 1234,
    "is_moving": false,
    "ambient_light": 120,
    "is_estimated_ambient_light": true,
    "day_phase": "下午",
    "time_hint": "冒烟测试"
  }
}
EOF
)"
  split_response "$(
    run_request POST "/v1/prophecy" \
      -H "Content-Type: application/json" \
      -d "${payload}"
  )"
  if [[ "${RESPONSE_CODE}" == "200" ]]; then
    pass "POST /v1/prophecy (生成预言) → HTTP 200"
    prophecy="$(echo "${RESPONSE_BODY}" | json_get prophecy)"
    if [[ -n "${prophecy}" ]]; then
      pass "返回预言: ${prophecy:0:60}…"
    else
      fail "200 响应缺少 prophecy 字段" "${RESPONSE_BODY}"
    fi
    remaining="$(echo "${RESPONSE_BODY}" | json_get quota_remaining)"
    if [[ -n "${remaining}" ]]; then
      pass "quota_remaining=${remaining}"
    fi
  elif [[ "${RESPONSE_CODE}" == "429" ]]; then
    yellow "  ! 配额已用尽（429），接口可达但今日无法继续生成"
    PASS=$((PASS + 1))
  elif [[ "${RESPONSE_CODE}" == "502" ]]; then
    fail "DeepSeek 调用失败（502）" "${RESPONSE_BODY}"
  else
    fail "POST /v1/prophecy (生成预言) → 期望 HTTP 200，实际 ${RESPONSE_CODE}" "${RESPONSE_BODY}"
  fi
fi

echo ""
echo "----------------------------------------"
if [[ "${FAIL}" -eq 0 ]]; then
  green "通过 ${PASS}，跳过 ${SKIP}，失败 ${FAIL}"
  exit 0
else
  red "通过 ${PASS}，跳过 ${SKIP}，失败 ${FAIL}"
  exit 1
fi
