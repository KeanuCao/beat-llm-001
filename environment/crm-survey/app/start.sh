#!/bin/bash
# 应用启动脚本: 先等数据库通, 再拉起 Tomcat
# 2016 年容器里没有 healthcheck, 探活就靠 bash 的 /dev/tcp 小把戏

# 日志里中文别打问号
export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

set -e

# 选择 JDK: JDK_VERSION=7|8 (默认 7), 切换只需重建容器, 不用重建镜像
JDK_VERSION=${JDK_VERSION:-7}
if [ "$JDK_VERSION" = "8" ]; then
    export JAVA_HOME=${JAVA_HOME_8:-/usr/lib/jvm/java-1.8.0-openjdk}
else
    export JAVA_HOME=${JAVA_HOME_7:-/usr/local/jdk1.7.0_80}
fi
export PATH="$JAVA_HOME/bin:$PATH"
echo ">>> 使用 JDK $JDK_VERSION: $JAVA_HOME"
"$JAVA_HOME/bin/java" -version 2>&1 || true

DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}

echo ">>> 等待数据库 $DB_HOST:$DB_PORT ..."
until (echo > /dev/tcp/$DB_HOST/$DB_PORT) 2>/dev/null; do
    echo "    数据库还没起来, 再等等..."
    sleep 2
done
echo ">>> 数据库已就绪"

echo ">>> 启动 Tomcat 8.5, 端口 8080 (war 包从 webapps 挂载目录自动部署)"
exec $CATALINA_HOME/bin/catalina.sh run
