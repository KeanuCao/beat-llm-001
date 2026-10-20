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

# ---------- 算掩码: 本机 openssl (兼容 1.x/3.x) -> 借 db 容器 -> 应用自带 MaskUtil ----------
mask_by_openssl() {
    printf '%s' "$EMAIL" | openssl enc -des-ecb -K "$KEY_HEX" -nosalt 2>/dev/null | od -An -tx1 | tr -d ' \n'
}
mask_by_openssl3() {
    printf '%s' "$EMAIL" | openssl enc -des-ecb -K "$KEY_HEX" -nosalt -provider legacy -provider default 2>/dev/null | od -An -tx1 | tr -d ' \n'
}
mask_by_docker() {
    docker exec crm-mysql sh -c \
        "printf '%s' '$EMAIL' | openssl enc -des-ecb -K $KEY_HEX -nosalt | od -An -tx1 | tr -d ' \n'" 2>/dev/null
}
mask_by_java() {
    # 用应用自己编译出来的 MaskUtil, 保证逐字节一致
    for CL in "${CLASSES_DIR:-}" \
              "$(dirname "$0")/../environment/crm-survey/target/classes" \
              "$(dirname "$0")/../environment/crm-survey/target/crm-survey/WEB-INF/classes"; do
        if [ -n "$CL" ] && [ -f "$CL/com/legacy/survey/util/MaskUtil.class" ]; then
            java -cp "$CL" com.legacy.survey.util.MaskUtil "$EMAIL" 2>/dev/null && return
        fi
    done
    return 1
}

MASK=$(mask_by_openssl || true)
[ -z "$MASK" ] && MASK=$(mask_by_openssl3 || true)
if [ -z "$MASK" ] && command -v docker >/dev/null 2>&1; then
    MASK=$(mask_by_docker || true)
fi
[ -z "$MASK" ] && MASK=$(mask_by_java || true)
if [ -z "$MASK" ]; then
    echo "算掩码失败: openssl (含 legacy provider)、db 容器、应用 classes 三条路都不通" >&2
    exit 1
fi

SQL="INSERT INTO survey_invite (uuid, survey_id, email, email_mask, status, create_time, send_time, update_time) VALUES ('$UUID', $SURVEY_ID, '$EMAIL', '$MASK', 1, NOW(), NOW(), NOW());"

# ---------- 入库: 优先宿主机 docker exec, 其次本机 mysql 客户端 ----------
insert_by_docker() {
    docker exec crm-mysql mysql -uroot -proot123 crm_survey -e "$SQL"
}
insert_by_mysql() {
    # 用应用账号, 别拿 root (Ubuntu 的 MariaDB root 也不认 TCP 密码)
    mysql -ucrm -pcrm123 crm_survey -e "$SQL" 2>/dev/null \
        || mysql -h"${DB_HOST:-db}" -ucrm -pcrm123 crm_survey -e "$SQL"
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
