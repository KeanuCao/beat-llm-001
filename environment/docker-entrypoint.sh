#!/bin/bash
# 一体机启动: 选 JDK -> 等 db -> 编译 -> 部署 -> Tomcat
# Tomcat 用 start + tail 守着的路数, 方便之后 stop/start 换包不动机器

export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

JDK_VERSION=${JDK_VERSION:-8}
if [ "$JDK_VERSION" = "8" ]; then
    export JAVA_HOME=${JAVA_HOME_8:-/usr/lib/jvm/java-1.8.0-openjdk}
else
    export JAVA_HOME=${JAVA_HOME_7:-/usr/local/jdk1.7.0_80}
fi
export PATH="$JAVA_HOME/bin:$PATH"
echo ">>> 使用 JDK $JDK_VERSION: $JAVA_HOME"
"$JAVA_HOME/bin/java" -version 2>&1 | head -1

DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}
echo ">>> 等待数据库 $DB_HOST:$DB_PORT ..."
until (echo > /dev/tcp/$DB_HOST/$DB_PORT) 2>/dev/null; do
    echo "    数据库还没起来, 再等等..."
    sleep 2
done

cd /opt/crm-survey
echo ">>> 编译 war..."
mvn -B -q -DskipTests clean package

mkdir -p deploy
cp -f target/crm-survey.war $CATALINA_HOME/webapps/

echo ">>> 启动 Tomcat 8.5, 端口 8080"
$CATALINA_HOME/bin/catalina.sh start
echo ">>> 守着日志 (Ctrl-C 不会带走 Tomcat)"
tail -F $CATALINA_HOME/logs/catalina.out
