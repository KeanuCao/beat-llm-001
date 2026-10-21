#!/bin/bash
# ============================================================
# CRM 问卷系统 - 评测脚本 (verifier)
# 判分点 = instruction.md 期望结果:
#   1/2. 受访者作答链: 模拟 10 位受访者经 HTTP 提交, 每人
#        survey_feedback_question +2 (题干快照) / survey_feedback_option +2
#        (单选一题一项), 10 次累计各 20 行, 零缺失, 页面提示问卷已提交
#   3.   仓库根 bugs/BUG-*.md, 五节: 标题/复现步骤/根本原因/影响范围/修复方案
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
CATALINA_HOME="${CATALINA_HOME:-/usr/local/tomcat}"
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

# ---------- 1. 环境健康 (等应用就绪, 最多约两分钟) ----------
CODE=""
for i in $(seq 1 60); do
    CODE=$(http -o /dev/null -w "%{http_code}" "$APP_URL/login.jsp")
    [ "$CODE" = "200" ] && break
    sleep 2
done
[ "$CODE" = "200" ] || { echo "[verifier] env down: login.jsp=$CODE"; fail; }

# ---------- 1.2 运行时版本: 修复必须落在应用代码, 不许靠降级 JDK 蒙混 ----------
# (JDK 7 的内省对读写类型配对宽容, 降回 1.7 未修复的代码也能落库 —— 必须拦)
TPID=$(pgrep -f "org.apache.catalina.startup.Bootstrap" | head -1)
[ -n "$TPID" ] || { echo "[verifier] tomcat process not found"; fail; }
TEXE=$(readlink /proc/$TPID/exe 2>/dev/null)
case "$TEXE" in
    *java-1.8*|*java-8*|*jdk1.8*) : ;;
    *) echo "[verifier] app must run on JDK 8 (got: $TEXE)"; fail ;;
esac

# ---------- 1.3 强制以源码重建部署: 验收对象永远是 src 编译出来的产物 ----------
# (堵"改 war 不改源码"的脱钩路径; 交付不可构建也在此拦下)
echo "[verifier] rebuilding from $APP_HOME ..."
if ! ( cd "$APP_HOME" && mvn -B -q -o -DskipTests clean package > /tmp/verifier-build.log 2>&1 ); then
    echo "[verifier] build from src failed, log tail:"
    tail -30 /tmp/verifier-build.log
    fail
fi
$CATALINA_HOME/bin/catalina.sh stop >/dev/null 2>&1 || true
sleep 3
rm -rf "$CATALINA_HOME/webapps/crm-survey"
cp -f "$APP_HOME/target/crm-survey.war" "$CATALINA_HOME/webapps/"
$CATALINA_HOME/bin/catalina.sh start >/dev/null 2>&1
CODE=""
for i in $(seq 1 45); do
    CODE=$(http -o /dev/null -w "%{http_code}" "$APP_URL/login.jsp")
    [ "$CODE" = "200" ] && break
    sleep 2
done
[ "$CODE" = "200" ] || { echo "[verifier] app not ready after rebuild: $CODE"; fail; }

# ---------- 1.5 改动预算 (修复最小化: 总 diff 行数 <= 预算) ----------
# 基线 = 镜像构建时固化的原始 src 快照 (环境侧 /opt/.baseline/src.tar.gz);
# 验证侧不持有与环境逐字节相同的资产。一行修复 = 2删+2增 = 4
BASELINE_TAR="${BASELINE_TAR:-/opt/.baseline/src.tar.gz}"
LINE_BUDGET="${LINE_BUDGET:-4}"
if [ -f "$BASELINE_TAR" ]; then
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
fi

# ---------- 2. 造具 (裁判侧, 直插; 全部带时间戳防撞) ----------
STAMP=$(date +%s)
SID=$(db "INSERT INTO survey (title, description, status, creator_id, publish_time, is_deleted, create_time, update_time)
VALUES ('评测问卷-$STAMP', 'verifier fixture', 1, 1, NOW(), 0, NOW(), NOW()); SELECT LAST_INSERT_ID();")
[ -n "${SID:-}" ] || { echo "[verifier] fixture survey failed"; fail; }

Q1TEXT="评测单选一-$STAMP"; Q2TEXT="评测单选二-$STAMP"
Q1=$(db "INSERT INTO survey_question (survey_id, standard_question_id, question_type, content, is_required, sort_no, is_deleted, create_time, update_time)
VALUES ($SID, 0, 1, '$Q1TEXT', 1, 1, 0, NOW(), NOW()); SELECT LAST_INSERT_ID();")
Q2=$(db "INSERT INTO survey_question (survey_id, standard_question_id, question_type, content, is_required, sort_no, is_deleted, create_time, update_time)
VALUES ($SID, 0, 1, '$Q2TEXT', 1, 2, 0, NOW(), NOW()); SELECT LAST_INSERT_ID();")
[ -n "${Q1:-}" ] && [ -n "${Q2:-}" ] || { echo "[verifier] fixture questions failed"; fail; }

O11=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q1, '选项甲-$STAMP', 1, NOW()); SELECT LAST_INSERT_ID();")
O12=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q1, '选项乙-$STAMP', 2, NOW()); SELECT LAST_INSERT_ID();")
O13=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q1, '选项丙-$STAMP', 3, NOW()); SELECT LAST_INSERT_ID();")
O21=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q2, '赤-$STAMP', 1, NOW()); SELECT LAST_INSERT_ID();")
O22=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q2, '橙-$STAMP', 2, NOW()); SELECT LAST_INSERT_ID();")
O23=$(db "INSERT INTO survey_question_option (survey_question_id, option_content, sort_no, create_time) VALUES ($Q2, '黄-$STAMP', 3, NOW()); SELECT LAST_INSERT_ID();")
[ -n "${O11:-}" ] && [ -n "${O12:-}" ] && [ -n "${O13:-}" ] && [ -n "${O21:-}" ] && [ -n "${O22:-}" ] && [ -n "${O23:-}" ] || { echo "[verifier] fixture options failed"; fail; }

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
        --data-urlencode "questions[1].answers[2].content=橙-$STAMP")
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
[ "$FQ" = "20" ] || { echo "[verifier] feedback_question rows=$FQ want 20"; fail; }
[ "$FO" = "20" ] || { echo "[verifier] feedback_option rows=$FO want 20"; fail; }

# ---------- 4.5 逐邀请验收: 每人恰好 1 主记录 + 2 题干 + 2 选项, 且内容关联逐人对 ----------
n=0
while read -r U E; do
    n=$((n+1))
    FID=$(db "SELECT id FROM survey_feedback WHERE invite_uuid='$U';")
    [ -n "$FID" ] || { echo "[verifier] r$n feedback row missing"; fail; }
    QN=$(db "SELECT COUNT(*) FROM survey_feedback_question WHERE feedback_id=$FID;")
    [ "$QN" = "2" ] || { echo "[verifier] r$n feedback_question=$QN want 2"; fail; }
    QC=$(db "SELECT COUNT(*) FROM survey_feedback_question WHERE feedback_id=$FID AND ((question_id=$Q1 AND question_content='$Q1TEXT') OR (question_id=$Q2 AND question_content='$Q2TEXT'));")
    [ "$QC" = "2" ] || { echo "[verifier] r$n question snapshot content mismatch"; fail; }
    ON=$(db "SELECT COUNT(*) FROM survey_feedback_option WHERE feedback_question_id IN (SELECT id FROM survey_feedback_question WHERE feedback_id=$FID);")
    [ "$ON" = "2" ] || { echo "[verifier] r$n feedback_option=$ON want 2"; fail; }
    OC=$(db "SELECT COUNT(*) FROM survey_feedback_option WHERE feedback_question_id IN (SELECT id FROM survey_feedback_question WHERE feedback_id=$FID) AND ((option_id=$O12 AND option_content='选项乙-$STAMP') OR (option_id=$O23 AND option_content='黄-$STAMP'));")
    [ "$OC" = "2" ] || { echo "[verifier] r$n option content/link mismatch"; fail; }
done < "/tmp/verifier-invites-$STAMP.txt"

# ---------- 4.7 终态复验: 全部提交结束后再数一遍, 数据要还是那些 (落库不是内存假象) ----------
FB2=$(db "SELECT COUNT(*) FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV);")
FQ2=$(db "SELECT COUNT(*) FROM survey_feedback_question WHERE feedback_id IN (SELECT id FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV));")
FO2=$(db "SELECT COUNT(*) FROM survey_feedback_option WHERE feedback_question_id IN (SELECT id FROM survey_feedback_question WHERE feedback_id IN (SELECT id FROM survey_feedback WHERE invite_uuid IN ($UUID_CSV)));")
[ "$FB2" = "10" ] && [ "$FQ2" = "20" ] && [ "$FO2" = "20" ] || { echo "[verifier] final recount drifted: $FB2/$FQ2/$FO2"; fail; }

# ---------- 5. bug 单 (期望结果 3): 文件名格式 + 五节齐全且各有实质内容 ----------
BUGFILE=$(ls "$BUGS_DIR"/BUG-*.md 2>/dev/null | head -1)
[ -n "$BUGFILE" ] || { echo "[verifier] no bug report"; fail; }
[ "$(wc -c < "$BUGFILE")" -gt 100 ] || { echo "[verifier] bug report too thin"; fail; }
echo "$(basename "$BUGFILE")" | grep -qE '^BUG-[0-9]{8}-[0-9]+\.md$' || { echo "[verifier] bug report filename not BUG-<date>-<seq>.md"; fail; }
for S in 标题 复现步骤 根本原因 影响范围 修复方案; do
    grep -q "$S" "$BUGFILE" || { echo "[verifier] bug report missing section: $S"; fail; }
    # 节标题之后、下一节之前, 至少要有一行非空正文
    awk -v s="$S" '
        index($0, "## " s) || index($0, "【" s) {f=1; next}
        f && /^#{1,6} / {f=0}
        f && NF {c=1}
        END {exit !c}' "$BUGFILE" || { echo "[verifier] bug report section empty: $S"; fail; }
done

# ---------- 6. 全过 ----------
rm -f "/tmp/verifier-invites-$STAMP.txt"
echo "1" > "$REWARD_FILE"
echo "[verifier] PASS"
exit 0
