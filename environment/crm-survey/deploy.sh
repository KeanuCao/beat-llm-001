#!/bin/bash
# ============================================================
# crm-survey 一键部署脚本 (运维组标准脚本, 幂等, 重复执行安全)
# 用法: bash /opt/crm-survey/deploy.sh
#   1) 编译当前源码并打包 war
#   2) 部署到 Tomcat 并重启应用 (重复执行 = 重新部署当前源码)
#   3) 确保本机数据库 mysqld 在运行 (部署不动库, 数据不丢)
#   4) 应用与数据库都就绪才退出, 任何一步失败非 0 退出
# ============================================================
set -e

export JAVA_HOME=${JAVA_HOME_8:-/usr/lib/jvm/java-1.8.0-openjdk}
export PATH="$JAVA_HOME/bin:$PATH"

# 1) 打包当前源码
cd /opt/crm-survey
mvn -B -q -DskipTests clean package

# 2) 换包 + 重启应用
$CATALINA_HOME/bin/catalina.sh stop >/dev/null 2>&1 || true
sleep 2
rm -rf $CATALINA_HOME/webapps/crm-survey
cp -f target/crm-survey.war $CATALINA_HOME/webapps/
$CATALINA_HOME/bin/catalina.sh start >/dev/null 2>&1

# 3) 数据库: 没在跑就拉起 (部署不动库)
if ! mysqladmin --silent ping >/dev/null 2>&1; then
    ( mysqld_safe --user=mysql >/dev/null 2>&1 & )
fi
DB_OK=""
for i in $(seq 1 90); do
    if mysqladmin --silent ping >/dev/null 2>&1; then DB_OK=1; break; fi
    sleep 2
done
[ -n "$DB_OK" ] || { echo ">>> 数据库起不来, 看 /var/log/mariadb/mariadb.log"; exit 1; }
mysql -h127.0.0.1 -ucrm -pcrm123 crm_survey -N -s -e "SELECT 1;" >/dev/null 2>&1 \
    || { echo ">>> crm 账号连不上 (数据目录异常?), 考虑重建容器"; exit 1; }

# 4) 应用就绪轮询
CODE=""
for i in $(seq 1 45); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/crm-survey/login.jsp || true)
    [ "$CODE" = "200" ] && break
    sleep 2
done
[ "$CODE" = "200" ] || { echo ">>> 应用未就绪, 看日志: $CATALINA_HOME/logs/catalina.out"; exit 1; }

echo ">>> 部署完成: 应用 8080 / 数据库 3306 均就绪"
exit 0
