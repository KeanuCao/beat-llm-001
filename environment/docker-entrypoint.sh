#!/bin/bash
# 一体机启动: 初始化/拉起本机 db -> 选 JDK -> 编译(如缺) -> 部署 -> Tomcat -> 就绪轮询 -> 退出
# 本脚本是纯启动脚本, 正常终止不留常驻进程 (平台对脚本的静态检查);
# 容器保活由 CMD 的 sleep 接管, 容器内照旧可 stop/start 换包不动机器

export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

JDK_VERSION=${JDK_VERSION:-8}
# 机器上只有 1.8 (运维上周把 1.7 升掉了), 别想着在运行时上打主意
export JAVA_HOME=${JAVA_HOME_8:-/usr/lib/jvm/java-1.8.0-openjdk}
export PATH="$JAVA_HOME/bin:$PATH"
echo ">>> 使用 JDK $JDK_VERSION: $JAVA_HOME"
"$JAVA_HOME/bin/java" -version 2>&1 | head -1

# ---------- 本机数据库: 首启初始化 + 建库 + 账号 + 种子 (当年是独立一台, 现在一体机) ----------
if [ ! -d /var/lib/mysql/mysql ]; then
    echo ">>> 首次启动: 初始化数据库 (mysqld 首启不快, 属正常)..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || true
fi

echo ">>> 启动本机 mysqld..."
( mysqld_safe --user=mysql >/dev/null 2>&1 & )

DB_OK=""
for i in $(seq 1 90); do
    if mysqladmin --silent ping >/dev/null 2>&1; then DB_OK=1; break; fi
    sleep 2
done
[ -n "$DB_OK" ] || { echo ">>> mysqld 没起来, 放弃 (看 /var/lib/mysql 与系统日志)"; exit 1; }
echo ">>> 数据库就绪"

if [ ! -d /var/lib/mysql/crm_survey ]; then
    echo ">>> 建库 / 账号 / 种子数据..."
    # mysql_install_db 会留匿名用户; 账号匹配 host 优先于 user,
    # ''@localhost 会先吃掉本机 TCP 连接, 把 crm@'%' 顶成 Access denied —— 先清掉
    mysql -e "DELETE FROM mysql.user WHERE user=''; FLUSH PRIVILEGES;" \
        || { echo ">>> 清理匿名用户失败"; exit 1; }
    mysql -e "CREATE DATABASE IF NOT EXISTS crm_survey DEFAULT CHARACTER SET utf8; \
              CREATE USER IF NOT EXISTS 'crm'@'%' IDENTIFIED BY 'crm123'; \
              GRANT ALL PRIVILEGES ON crm_survey.* TO 'crm'@'%'; \
              FLUSH PRIVILEGES;" || { echo ">>> 建库/建号失败"; exit 1; }
    mysql < /opt/crm-survey/schema.sql || { echo ">>> schema 导入失败"; exit 1; }
    mysql < /opt/crm-survey/init-admin.sql || { echo ">>> 管理员种子导入失败"; exit 1; }
    # 自检: 用验收侧同款连接方式 (TCP + crm) 验一遍, 不通不算就绪
    mysql -h127.0.0.1 -ucrm -pcrm123 crm_survey -N -s -e "SELECT 1;" >/dev/null 2>&1 \
        || { echo ">>> crm 账号 TCP 自检失败 (匿名用户残留/监听问题)"; exit 1; }
    echo ">>> 种子导入完成"
fi

cd /opt/crm-survey
if [ ! -f target/crm-survey.war ]; then
    echo ">>> 镜像里没带 war, 现场编译..."
    mvn -B -q -DskipTests clean package
fi

cp -f target/crm-survey.war $CATALINA_HOME/webapps/

echo ">>> 启动 Tomcat 8.5, 端口 8080"
$CATALINA_HOME/bin/catalina.sh start

# 就绪轮询: 应用应答 200 才算环境起好
CODE=""
for i in $(seq 1 30); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/crm-survey/login.jsp || true)
    [ "$CODE" = "200" ] && break
    sleep 2
done
[ "$CODE" = "200" ] || { echo ">>> 应用未就绪, 看日志: $CATALINA_HOME/logs/catalina.out"; exit 1; }

# 到此正常退出, 不留常驻进程; PID1 由 CMD 的 sleep 接管
echo ">>> 环境就绪, 启动脚本退出"
exit 0
