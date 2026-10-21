#!/bin/bash
# ============================================================
# 参考解 (双模式: 容器里直接跑, 宿主机上也会自动进容器执行):
#   1. oracle_convert.py 应用一行修复 (getAnswers 的数组元素类型
#      与 indexed 属性类型对齐, 内省恢复, 嵌套绑定通)
#   2. 重编译 war
#   3. 换包 + 重启 Tomcat (一体机老流程, 全程不需要 docker)
#
# 根因: Question.getAnswers() 返回 BaseSurveyItem[](父类数组),
# 与 indexed 属性的 Answer 类型不一致, java.beans 内省配对失败
# (JDK 8 上 beanutils 会打 type mismatch 的 SEVERE), 嵌套绑定瘫痪;
# SuperBeanConverter 把异常吞掉, 受访者回答静默丢失。
# ============================================================
set -e

if [ ! -d /opt/crm-survey ]; then
    # 宿主机模式: 把 solution 丢进 main 容器里重跑自己
    echo ">>> 宿主机模式: 进入 crm-main 容器执行..."
    docker cp "$(cd "$(dirname "$0")/.." && pwd)/solution" crm-main:/opt/solution
    exec docker exec crm-main bash /opt/solution/solve.sh
fi

cd /opt/crm-survey

echo ">>> 应用 oracle 转换..."
python3 solution/oracle_convert.py 2>/dev/null || python3 /opt/solution/oracle_convert.py

echo ">>> 重新编译 war..."
mvn -B -q -DskipTests clean package

echo ">>> 换包 + 重启 Tomcat..."
$CATALINA_HOME/bin/catalina.sh stop >/dev/null 2>&1 || true
sleep 3
rm -rf $CATALINA_HOME/webapps/crm-survey
cp -f target/crm-survey.war $CATALINA_HOME/webapps/
$CATALINA_HOME/bin/startup.sh

echo ">>> 等待应用就绪..."
CODE=""
for i in $(seq 1 30); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/crm-survey/login.jsp || true)
    [ "$CODE" = "200" ] && break
    sleep 2
done
[ "$CODE" = "200" ] || { echo ">>> 应用未就绪, 看日志: $CATALINA_HOME/logs/catalina.out"; exit 1; }

echo ">>> 部署完成: http://localhost:8080/crm-survey/login.jsp"
echo ">>> 改动行数: git diff --numstat (应为 2 删 2 增, 预算内)"
