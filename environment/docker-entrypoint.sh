#!/bin/bash
# 一体机启动: 选 JDK -> 等 db -> 编译 -> 部署 -> Tomcat -> 就绪轮询 -> 退出
# 本脚本是纯启动脚本, 正常终止不留常驻进程 (平台对脚本的静态检查);
# 容器保活由编排层负责 (compose command), 容器内照旧可 stop/start 换包不动机器

export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

JDK_VERSION=${JDK_VERSION:-8}
# 机器上只有 1.8 (运维上周把 1.7 升掉了), 别想着在运行时上打主意
export JAVA_HOME=${JAVA_HOME_8:-/usr/lib/jvm/java-1.8.0-openjdk}
export PATH="$JAVA_HOME/bin:$PATH"
echo ">>> 使用 JDK $JDK_VERSION: $JAVA_HOME"
"$JAVA_HOME/bin/java" -version 2>&1 | head -1

DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}
echo ">>> 等待数据库 $DB_HOST:$DB_PORT (最多 300s, mysql 5.7 首次初始化不快) ..."
DB_OK=""
for i in $(seq 1 150); do
    if (echo > /dev/tcp/$DB_HOST/$DB_PORT) 2>/dev/null; then DB_OK=1; break; fi
    sleep 2
done
[ -n "$DB_OK" ] || { echo ">>> 数据库一直没起来, 放弃"; exit 1; }
echo ">>> 数据库就绪"

cd /opt/crm-survey
if [ ! -f target/crm-survey.war ]; then
    echo ">>> 镜像里没带 war, 现场编译..."
    mvn -B -q -DskipTests clean package
fi

mkdir -p deploy
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

# 到此正常退出, 不留常驻进程; PID1 由编排层的 command 接管
echo ">>> 环境就绪, 启动脚本退出"
exit 0
