#!/bin/bash
# ============================================================
# 构造一个合法的邀请链接 (QC/联调用)
# 用法: ./make_invite.sh <email> [surveyId]
# 输出: 一条合法的调查链接 (uuid 已入库, email_mask 与邮箱匹配,
#       受访者打开后填同一个邮箱即可通过 4.4 的校验)
#
# 说明:
# 1. 掩码算法和 com.legacy.survey.util.MaskUtil 完全一致:
#    DES/ECB/PKCS5Padding, 密钥 crm@2006 (hex: 63726d4032303036)
# 2. 默认 surveyId=2 (种子数据里的已发布问卷)
# 3. 邮箱只放行常见字符, 防止把 SQL 拼坏
# ============================================================
set -e

EMAIL="${1:-}"
SURVEY_ID="${2:-2}"
KEY_HEX="63726d4032303036"

if [ -z "$EMAIL" ]; then
    echo "用法: $0 <email> [surveyId]" >&2
    exit 1
fi

# 只放行邮箱常见字符
if ! printf '%s' "$EMAIL" | grep -qE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$'; then
    echo "邮箱格式不合法: $EMAIL" >&2
    exit 1
fi

# 邀请码
UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' || true)
if [ -z "$UUID" ]; then
    UUID=$(uuidgen 2>/dev/null | tr -d '-' || true)
fi
if [ -z "$UUID" ]; then
    echo "生成 uuid 失败 (没有 /proc/sys/kernel/random/uuid 也没有 uuidgen)" >&2
    exit 1
fi

# ---------- 算掩码: 优先本机 openssl, 不行借 db 容器里的 openssl ----------
mask_by_openssl() {
    printf '%s' "$EMAIL" | openssl enc -des-ecb -K "$KEY_HEX" -nosalt 2>/dev/null | od -An -tx1 | tr -d ' \n'
}
mask_by_docker() {
    docker exec crm-mysql sh -c \
        "printf '%s' '$EMAIL' | openssl enc -des-ecb -K $KEY_HEX -nosalt | od -An -tx1 | tr -d ' \n'" 2>/dev/null
}

MASK=$(mask_by_openssl || true)
if [ -z "$MASK" ] && command -v docker >/dev/null 2>&1; then
    MASK=$(mask_by_docker || true)
fi
if [ -z "$MASK" ]; then
    echo "算掩码失败: 本机没有可用的 openssl (DES 在 openssl 3 里进了 legacy), 且没有 docker 可借 db 容器" >&2
    exit 1
fi

SQL="INSERT INTO survey_invite (uuid, survey_id, email, email_mask, status, create_time, send_time, update_time) VALUES ('$UUID', $SURVEY_ID, '$EMAIL', '$MASK', 1, NOW(), NOW(), NOW());"

# ---------- 入库: 优先宿主机 docker exec, 其次本机 mysql 客户端 ----------
insert_by_docker() {
    docker exec crm-mysql mysql -uroot -proot123 crm_survey -e "$SQL"
}
insert_by_mysql() {
    mysql -h"${DB_HOST:-db}" -uroot -proot123 crm_survey -e "$SQL"
}

if command -v docker >/dev/null 2>&1 && docker ps 2>/dev/null | grep -q crm-mysql; then
    insert_by_docker
elif command -v mysql >/dev/null 2>&1; then
    insert_by_mysql
else
    echo "入库失败: 没有在跑的 crm-mysql 容器 (docker), 本机也没有 mysql 客户端" >&2
    exit 1
fi

# ---------- 输出链接 ----------
echo "${MAIL_BASE_URL:-http://localhost:8080}/surveyAnswer.do?t=$UUID"
