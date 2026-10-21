#!/bin/bash
# ============================================================
# 参考解 (harbor 把 solution/ 拷到容器 /solution/ 下执行):
#   一行修复: Question.getAnswers() 的数组元素类型与 indexed 属性类型
#   对齐 (BaseSurveyItem[] -> Answer[]), java.beans 内省配对恢复,
#   嵌套绑定就通了; SuperBeanConverter 吞异常才会静默丢数据, 修好即愈。
#   纯 sed 实现 —— CentOS 7 没有 python3, 别依赖它。
# ============================================================
set -e

if [ ! -d /opt/crm-survey ]; then
    echo ">>> 宿主机模式: 把 solution 丢进 crm-main 再执行..."
    docker cp "$(cd "$(dirname "$0")/.." && pwd)/solution" crm-main:/opt/solution
    exec docker exec crm-main bash /opt/solution/solve.sh
fi

cd /opt/crm-survey
Q=src/main/java/com/legacy/survey/pojo/Question.java

if grep -q "public Answer\[\] getAnswers()" "$Q"; then
    echo ">>> 修复已存在, 跳过"
else
    sed -i 's|public BaseSurveyItem\[\] getAnswers() {|public Answer[] getAnswers() {|' "$Q"
    sed -i 's|return answers.toArray(new BaseSurveyItem\[answers.size()\]);|return answers.toArray(new Answer[answers.size()]);|' "$Q"
    echo ">>> 一行修复已应用"
fi

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

echo ">>> 部署完成, 可以跑评测了"
echo ">>> 改动行数: git diff --numstat (应为 2 删 2 增, 预算内)"
