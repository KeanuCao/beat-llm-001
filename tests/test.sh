#!/bin/bash
# ============================================================
# CRM 问卷系统 - 评测脚本 (verifier)
# 判分点 = instruction.md 期望结果:
#   1/2. 受访者作答链: 模拟 10 位受访者经 HTTP 提交, 每人提交
#        2 道单选(各勾1项) + 1 道多选(3 选项勾 2 项): survey_feedback_question
#        +3 (题干快照) / survey_feedback_option +4 (单选两项+多选两项),
#        10 人累计 30/40 行, 零缺失, 页面提示问卷已提交
#   3.   bugs/ 下至少两张 BUG-*.md, 每张五节: 标题/复现步骤/根本原因/影响范围/修复方案
# 具 (问卷/题目/选项/邀请) 由本脚本直插数据库构造, 邮箱和 uuid 每次随机,
# agent 无法预埋 —— 结构性反硬编码。
# 验收前强制以 /opt/crm-survey 源码重建部署 (验收对象永远是源码的产物)。
# 任何一步失败/超时/崩溃, reward 一律记 0。
#
# 用法: 在仓库根执行, 或用环境变量覆盖:
#   APP_URL     默认 http://localhost:8080/crm-survey
#   DB_HOST/DB_PORT/DB_USER/DB_PASS/DB_NAME  默认 127.0.0.1:3306 crm/crm123 crm_survey
#   REPO_DIR    默认 $PWD (找 bugs/ 与 MaskUtil 兜底用)
#   REWARD_FILE 默认 /logs/verifier/reward.txt
# ============================================================
set -u

REWARD_FILE="${REWARD_FILE:-/logs/verifier/reward.txt}"
APP_URL="${APP_URL:-http://localhost:8080/crm-survey}"
DB_HOST="${DB_HOST:-127.0.0.1}"; DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-crm}"; DB_PASS="${DB_PASS:-crm123}"; DB_NAME="${DB_NAME:-crm_survey}"
SRC_DIR="${SRC_DIR:-/opt/crm-survey/src}"
APP_HOME="${APP_HOME:-/opt/crm-survey}"
export CATALINA_HOME="${CATALINA_HOME:-/usr/local/tomcat}"   # deploy.sh 子进程要用
BUGS_DIR="${BUGS_DIR:-/opt/crm-survey/bugs}"
REPO_DIR="${REPO_DIR:-$PWD}"

mkdir -p "$(dirname "$REWARD_FILE")" 2>/dev/null
echo "0" > "$REWARD_FILE"          # 先落 0, 全过才改 1

fail() { echo "0" > "$REWARD_FILE"; exit 0; }

db() { mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --default-character-set=utf8 "$DB_NAME" -N -s -e "$1" 2>/dev/null; }

http() { curl -s --max-time 20 "$@"; }

# 邮箱加密掩码: 与应用 MaskUtil 同钥同算法 (DES/ECB/PKCS5, crm@2006)
mask_of() {
    local EMAIL="$1" KEY_HEX="63726d4032303036" M=""
    M=$(printf '%s' "$EMAIL" | openssl enc -des-ecb -K "$KEY_HEX" -nosalt 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ -z "$M" ] && M=$(printf '%s' "$EMAIL" | openssl enc -des-ecb -K "$KEY_HEX" -nosalt -provider legacy -provider default 2>/dev/null | od -An -tx1 | tr -d ' \n')
    if [ -z "$M" ]; then
        for CL in "$SRC_DIR/../target/classes" "$SRC_DIR/../target/crm-survey/WEB-INF/classes"; do
            if [ -f "$CL/com/legacy/survey/util/MaskUtil.class" ]; then
                M=$(java -cp "$CL" com.legacy.survey.util.MaskUtil "$EMAIL" 2>/dev/null)
                [ -n "$M" ] && break
            fi
        done
    fi
    printf '%s' "$M"
}

# ---------- 0. 环境版本 (作者侧每次改码更新 version 文件, 黑盒定位用) ----------
VERSION_FILE="${VERSION_FILE:-$APP_HOME/version}"
[ -f "$VERSION_FILE" ] && echo "[verifier] environment version: $(cat "$VERSION_FILE")"

# ---------- 1. 部署: 运维标准脚本一键拉起/重新部署 (幂等) ----------
# deploy.sh = 编译当前源码 -> 换包重启应用 -> 确保 mysqld 在跑 -> 等就绪
# (验收对象永远是 src 的产物, 脱钩路径天然被堵; 服务不随容器自启, 谁验谁拉)
if ! bash "$APP_HOME/deploy.sh"; then
    echo "[verifier] deploy failed (诊断输出见上)"
    fail
fi

# ---------- 1.2 运行时版本 (纵深防御): 应用必须跑在 JDK 8 ----------
TPID=$(pgrep -f "org.apache.catalina.startup.Bootstrap" | head -1)
[ -n "$TPID" ] || { echo "[verifier] tomcat process not found"; fail; }
TEXE=$(readlink /proc/$TPID/exe 2>/dev/null)
case "$TEXE" in
    *java-1.8*|*java-8*|*jdk1.8*) : ;;
    *) echo "[verifier] app must run on JDK 8 (got: $TEXE)"; fail ;;
esac

# ---------- 1.5 改动预算 (修复最小化: 总 diff 行数 <= 预算) ----------
# 基线 = 镜像构建时固化的原始 src 快照 (环境侧 /opt/.baseline/src.tar.gz);
# 验证侧不持有与环境逐字节相同的资产。一行修复 = 2删+2增 = 4
BASELINE_TAR="${BASELINE_TAR:-/opt/.baseline/src.tar.gz}"
LINE_BUDGET="${LINE_BUDGET:-6}"
if [ ! -f "$BASELINE_TAR" ]; then
    echo "[verifier] baseline snapshot missing: $BASELINE_TAR (预算检查是硬约束, 不允许静默跳过)"
    fail
fi
{
    STAGE=$(mktemp -d)
    tar xzf "$BASELINE_TAR" -C "$STAGE"
    BASE_DIR="$STAGE/crm-survey/src"
    TOTAL=0
    for f in $(cd "$BASE_DIR" && find . -type f | sed 's|^\./||'); do
        case "$f" in *.properties) continue;; esac
        A="$SRC_DIR/$f"; B="$BASE_DIR/$f"
        if [ ! -f "$A" ]; then
            D=$(wc -l < "$B")
        elif [ ! -f "$B" ]; then
            D=$(wc -l < "$A")
        else
            D=$(diff --strip-trailing-cr "$B" "$A" | grep -cE '^[<>]')
        fi
        TOTAL=$((TOTAL+D))
    done
    # agent 新增的文件也计入
    for f in $(cd "$SRC_DIR" && find . -type f | sed 's|^\./||'); do
        case "$f" in *.properties) continue;; esac
        [ -f "$BASE_DIR/$f" ] || TOTAL=$((TOTAL+$(wc -l < "$SRC_DIR/$f")))
    done
    rm -rf "$STAGE"
    [ "$TOTAL" -le "$LINE_BUDGET" ] || { echo "[verifier] line budget exceeded: $TOTAL > $LINE_BUDGET (fix must be minimal)"; fail; }
    echo "[verifier] diff lines vs baseline: $TOTAL (budget $LINE_BUDGET)"
}

# ---------- 2. 造具 (裁判侧, 直插; 全部带时间戳防撞) ----------
# 先等 db 连通 (容器刚起时 mysqld 可能还在启动中)
DB_OK=""
for i in $(seq 1 90); do
    if db "SELECT 1;" | grep -q 1; then DB_OK=1; break; fi
    sleep 2
done
[ -n "$DB_OK" ] || { echo "[verifier] db not reachable"; fail; }

STAMP=$(date +%s)
SID=$(db "INSERT INTO survey (title, description, status, creator_id, publish_time, is_deleted, create_time, update_time)
VALUES ('评测问卷-$STAMP', 'verifier fixture', 1, 1, NOW(), 0, NOW(), NOW()); SELECT LAST_INSERT_ID();")
[ -n "${SID:-}" ] || { echo "[verifier] fixture survey failed"; fail; }

Q1TEXT="评测单选一-$STAMP"; Q2TEXT="评测单选二-$STAMP"; Q3TEXT="评测多选一-$STAMP"
Q1=$(db "INSERT INTO survey_question (survey_id, standard_question_id, question_type, content, is_required, sort_no, is_deleted, create_time, update_time)
VALUES ($SID, 0, 1, '$Q1TEXT', 1, 1, 0, NOW(), NOW()); SELECT LAST_INSERT_ID();")
Q2=$(db "INSERT INTO survey_question (survey_id, standard_question_id, question_type, content, is_required, sort_no, is_deleted, create_time, update_time)
VALUES ($SID, 0, 1, '$Q2TEXT', 1, 2, 0, NOW(), NOW()); SELECT LAST_INSERT_ID();")
Q3=$(db "INSERT INTO survey_question (survey_id, standard_question_id, question_type, content, is_required, sort_no, is_deleted, create_time, update_time)
VALUES ($SID, 0, 2, '$Q3TEXT', 1, 3, 0, NOW(), NOW()); SELECT LAST_INSERT_ID();")
[ -n "${Q1:-}" ] && [ -n "${Q2:-}" ] && [ -n "${Q3:-}" ] || { echo "[verifier] fixture questions failed"; fail; }

O11=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q1, '选项甲-$STAMP', 1, NOW()); SELECT LAST_INSERT_ID();")
O12=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q1, '选项乙-$STAMP', 2, NOW()); SELECT LAST_INSERT_ID();")
O13=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q1, '选项丙-$STAMP', 3, NOW()); SELECT LAST_INSERT_ID();")
O21=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q2, '赤-$STAMP', 1, NOW()); SELECT LAST_INSERT_ID();")
O22=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q2, '橙-$STAMP', 2, NOW()); SELECT LAST_INSERT_ID();")
O23=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q2, '黄-$STAMP', 3, NOW()); SELECT LAST_INSERT_ID();")
O31=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q3, '梅-$STAMP', 1, NOW()); SELECT LAST_INSERT_ID();")
O32=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q3, '兰-$STAMP', 2, NOW()); SELECT LAST_INSERT_ID();")
O33=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q3, '竹-$STAMP', 3, NOW()); SELECT LAST_INSERT_ID();")
[ -n "${O11:-}" ] && [ -n "${O12:-}" ] && [ -n "${O13:-}" ] && [ -n "${O21:-}" ] && [ -n "${O22:-}" ] && [ -n "${O23:-}" ] \
&& [ -n "${O31:-}" ] && [ -n "${O32:-}" ] && [ -n "${O33:-}" ] || { echo "[verifier] fixture options failed"; fail; }

# 10 位受访者: 每人一条邀请 (uuid 随机, 掩码按各自邮箱现算)
UUID_CSV=""
for i in 1 2 3 4 5 6 7 8 9 10; do
    EMAIL="resp${i}-${STAMP}@verifier.test"
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-')
    [ -n "$UUID" ] || UUID=$(uuidgen 2>/dev/null | tr -d '-')
    [ -n "$UUID" ] || { echo "[verifier] uuid gen failed"; fail; }
    MASK=$(mask_of "$EMAIL")
    [ -n "$MASK" ] || { echo "[verifier] mask failed for $EMAIL"; fail; }
    db "INSERT INTO survey_invite (uuid, survey_id, email, email_mask, status, create_time, send_time, update_time)
VALUES ('$UUID', $SID, '$EMAIL', '$MASK', 1, NOW(), NOW(), NOW());" || { echo "[verifier] invite insert failed"; fail; }
    UUID_CSV="$UUID_CSV'$UUID',"
    echo "$UUID $EMAIL" >> "/tmp/verifier-invites-$STAMP.txt"
done
UUID_CSV="${UUID_CSV%,}"

# ---------- 3. 受访者 10 连击 (被评测的链路: 全走 HTTP) ----------
i=0
while read -r UUID EMAIL; do
    i=$((i+1))
    JAR="/tmp/verifier-cj-$STAMP-$i.jar"
    PAGE=$(http -c "$JAR" "$APP_URL/surveyAnswer.do?t=$UUID")
    echo "$PAGE" | grep -q "问卷作答" || { echo "[verifier] r$i answer page abnormal"; fail; }
    TOKEN=$(printf '%s' "$PAGE" | sed -n 's/.*name="csrfToken" value="\([^"]*\)".*/\1/p' | head -1)
    [ -n "$TOKEN" ] || { echo "[verifier] r$i no csrf token"; fail; }

    RESP=$(http -b "$JAR" -X POST "$APP_URL/surveyAnswer.do" \
        --data-urlencode "csrfToken=$TOKEN" \
        --data-urlencode "t=$UUID" \
        --data-urlencode "email=$EMAIL" \
        --data-urlencode "questions[0].id=$Q1" \
        --data-urlencode "questions[0].type=1" \
        --data-urlencode "questions[0].text=$Q1TEXT" \
        --data-urlencode "questions[0].answers[0].id=$O12" \
        --data-urlencode "questions[0].answers[0].content=选项乙-$STAMP" \
        --data-urlencode "questions[0].answers[1].content=选项甲-$STAMP" \
        --data-urlencode "questions[0].answers[2].content=选项丙-$STAMP" \
        --data-urlencode "questions[1].id=$Q2" \
        --data-urlencode "questions[1].type=1" \
        --data-urlencode "questions[1].text=$Q2TEXT" \
        --data-urlencode "questions[1].answers[0].id=$O23" \
        --data-urlencode "questions[1].answers[0].content=黄-$STAMP" \
        --data-urlencode "questions[1].answers[1].content=赤-$STAMP" \
        --data-urlencode "questions[1].answers[2].content=橙-$STAMP" \
        --data-urlencode "questions[2].id=$Q3" \
        --data-urlencode "questions[2].type=2" \
        --data-urlencode "questions[2].text=$Q3TEXT" \
        --data-urlencode "questions[2].answers[0].id=$O31" \
        --data-urlencode "questions[2].answers[0].content=梅-$STAMP" \
        --data-urlencode "questions[2].answers[1].id=$O32" \
        --data-urlencode "questions[2].answers[1].content=兰-$STAMP" \
        --data-urlencode "questions[2].answers[2].content=竹-$STAMP")
    echo "$RESP" | grep -q "问卷已提交" || { echo "[verifier] r$i submit page abnormal"; fail; }
    rm -f "$JAR"
done < "/tmp/verifier-invites-$STAMP.txt"

# ---------- 3.5 负向边界 (框架既有行为, 均不产生数据) ----------
# a) 不带 CSRF token 的 POST 必须 403
NCODE=$(http -o /dev/null -w "%{http_code}" -X POST "$APP_URL/surveyAnswer.do" \
    --data-urlencode "email=fake-${STAMP}@verifier.test" || true)
[ "$NCODE" = "403" ] || { echo "[verifier] POST w/o csrf token: want 403 got $NCODE"; fail; }
# b) 无效邀请码 → 错误页
BADPAGE=$(http "$APP_URL/surveyAnswer.do?t=not-a-real-uuid")
echo "$BADPAGE" | grep -q "链接无效" || { echo "[verifier] bad uuid should hit error page"; fail; }
# c) 已答过的邀请再次打开 → 友好提示 (不重复产生数据)
U1=$(head -1 "/tmp/verifier-invites-$STAMP.txt" | cut -d' ' -f1)
REP=$(http -c "/tmp/verifier-cj-re-$STAMP.jar" "$APP_URL/surveyAnswer.do?t=$U1")
echo "$REP" | grep -q "已经回答" || { echo "[verifier] re-open answered invite should be friendly"; fail; }
rm -f "/tmp/verifier-cj-re-$STAMP.jar"

# ---------- 4. 计数验收 (期望结果 2 的数字, 零缺失 = 精确相等) ----------
FB=$(db "SELECT COUNT(*) FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV);")
FQ=$(db "SELECT COUNT(*) FROM survey_feedback_question WHERE feedback_id IN (SELECT id FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV));")
FO=$(db "SELECT COUNT(*) FROM survey_feedback_option WHERE feedback_question_id IN (SELECT id FROM survey_feedback_question WHERE feedback_id IN (SELECT id FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV)));")
[ "$FB" = "10" ] || { echo "[verifier] feedback rows=$FB want 10"; fail; }
[ "$FQ" = "30" ] || { echo "[verifier] feedback_question rows=$FQ want 30"; fail; }
[ "$FO" = "40" ] || { echo "[verifier] feedback_option rows=$FO want 40"; fail; }

# ---------- 4.5 逐邀请验收: 每人恰好 1 主记录 + 3 题干 + 4 选项, 且内容关联逐人对 ----------
n=0
while read -r U E; do
    n=$((n+1))
    FID=$(db "SELECT id FROM survey_feedback WHERE invite_uuid='$U';")
    [ -n "$FID" ] || { echo "[verifier] r$n feedback row missing"; fail; }
    QN=$(db "SELECT COUNT(*) FROM survey_feedback_question WHERE feedback_id=$FID;")
    [ "$QN" = "3" ] || { echo "[verifier] r$n feedback_question=$QN want 3"; fail; }
    QC=$(db "SELECT COUNT(*) FROM survey_feedback_question WHERE feedback_id=$FID AND ((question_id=$Q1 AND question_content='$Q1TEXT') OR (question_id=$Q2 AND question_content='$Q2TEXT') OR (question_id=$Q3 AND question_content='$Q3TEXT'));")
    [ "$QC" = "3" ] || { echo "[verifier] r$n question snapshot content mismatch"; fail; }
    ON=$(db "SELECT COUNT(*) FROM survey_feedback_option WHERE feedback_question_id IN (SELECT id FROM survey_feedback_question WHERE feedback_id=$FID);")
    [ "$ON" = "4" ] || { echo "[verifier] r$n feedback_option=$ON want 4"; fail; }
    OC=$(db "SELECT COUNT(*) FROM survey_feedback_option WHERE feedback_question_id IN (SELECT id FROM survey_feedback_question WHERE feedback_id=$FID) AND ((option_id=$O12 AND option_content='选项乙-$STAMP') OR (option_id=$O23 AND option_content='黄-$STAMP') OR (option_id=$O31 AND option_content='梅-$STAMP') OR (option_id=$O32 AND option_content='兰-$STAMP'));")
    [ "$OC" = "4" ] || { echo "[verifier] r$n option content/link mismatch"; fail; }
done < "/tmp/verifier-invites-$STAMP.txt"

# ---------- 4.7 终态复验: 全部提交结束后再数一遍, 数据要还是那些 (落库不是内存假象) ----------
FB2=$(db "SELECT COUNT(*) FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV);")
FQ2=$(db "SELECT COUNT(*) FROM survey_feedback_question WHERE feedback_id IN (SELECT id FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV));")
FO2=$(db "SELECT COUNT(*) FROM survey_feedback_option WHERE feedback_question_id IN (SELECT id FROM survey_feedback_question WHERE feedback_id IN (SELECT id FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV)));")
[ "$FB2" = "10" ] && [ "$FQ2" = "30" ] && [ "$FO2" = "40" ] || { echo "[verifier] final recount drifted: $FB2/$FQ2/$FO2"; fail; }

# ---------- 5. bug 单 (期望结果 3): 每个根因一张, 至少两张, 逐张检查五节 ----------
BUGS=$(ls "$BUGS_DIR"/BUG-*.md 2>/dev/null)
[ -n "$BUGS" ] || { echo "[verifier] no bug report"; fail; }
[ "$(echo "$BUGS" | wc -l)" -ge 2 ] || { echo "[verifier] need >=2 bug reports (one per root cause), got: $BUGS"; fail; }
for BUGFILE in $BUGS; do
    [ "$(wc -c < "$BUGFILE")" -gt 100 ] || { echo "[verifier] bug report too thin: $BUGFILE"; fail; }
    echo "$(basename "$BUGFILE")" | grep -qE '^BUG-[0-9]{8}-[0-9]+\.md$' || { echo "[verifier] bug report filename not BUG-<date>-<seq>.md: $BUGFILE"; fail; }
    for S in 标题 复现步骤 根本原因 影响范围 修复方案; do
        grep -q "$S" "$BUGFILE" || { echo "[verifier] bug report missing section: $S in $BUGFILE"; fail; }
        # 节标题之后、下一节之前, 至少要有一行非空正文
        awk -v s="$S" '
            index($0, "## " s) || index($0, "【" s) {f=1; next}
            f && /^#{1,6} / {f=0}
            f && NF {c=1}
            END {exit !c}' "$BUGFILE" || { echo "[verifier] bug report section empty: $S in $BUGFILE"; fail; }
    done
done

# ---------- 6. 全过 ----------
rm -f "/tmp/verifier-invites-$STAMP.txt"
echo "1" > "$REWARD_FILE"
echo "[verifier] PASS"
exit 0
