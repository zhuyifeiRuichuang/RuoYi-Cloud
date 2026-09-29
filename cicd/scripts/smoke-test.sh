#!/usr/bin/env bash
# RuoYi-Cloud Docker Compose 冒烟测试：等待依赖就绪并验证网关/前端可访问
set -uo pipefail

MAX=60
FAILED=0
wait_for() {
  local desc="$1"; shift
  local i
  for i in $(seq 1 "$MAX"); do
    if eval "$@" >/dev/null 2>&1; then
      echo "[OK] ${desc}"
      return 0
    fi
    echo "[..] waiting for ${desc} (${i}/${MAX})"
    sleep 5
  done
  echo "[FAIL] timeout waiting for ${desc}"
  FAILED=1
  return 1
}

echo "==> RuoYi-Cloud smoke test"

wait_for "mysql (3306)" "docker exec ruoyi-mysql mysqladmin ping -h 127.0.0.1 -ppassword"
wait_for "redis (6379)" "docker exec ruoyi-redis redis-cli ping"
# Nacos 3.x：8848 仅提供 OpenAPI（控制台已独立到 8080），GET / 不再是健康页；
# 先探 v3 readiness 端点，失败则退化为 TCP 连通性判断。
wait_for "nacos (8848)" "curl -fsS --max-time 5 -o /dev/null http://127.0.0.1:8848/nacos/v3/admin/core/state/readiness || timeout 3 bash -c '</dev/tcp/127.0.0.1/8848'"
wait_for "gateway (8080)" "curl -fsS http://127.0.0.1:8080/"
wait_for "web (80)" "curl -fsS http://127.0.0.1:80/"

echo "==> web index (first 200 bytes):"
curl -fsS http://127.0.0.1:80/ | head -c 200 || true
echo

# 汇总容器状态
docker compose -f cicd/docker-compose.yml ps || true

if [ "$FAILED" -ne 0 ]; then
  echo "smoke test done: FAILED"
  exit 1
fi
echo "smoke test done: PASSED"
