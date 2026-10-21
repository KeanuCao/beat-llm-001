#!/bin/bash
# ============================================================
# 参考解: 一行修复 (改动一处方法, 共两个物理行)
#
# 根因:
#   Question.getAnswers() 返回 BaseSurveyItem[] (父类数组),
#   而该属性的 indexed 读写类型是 Answer —— 数组元素类型与
#   indexed 属性类型不一致, java.beans 内省配对失败
#   (JDK 8 上 DefaultBeanIntrospector 会打
#   "type mismatch between read and write methods" 的 SEVERE),
#   commons-beanutils 的嵌套绑定从此瘫痪;
#   SuperBeanConverter 把异常整个吞掉, 于是受访者的回答静默丢失,
#   页面照常提示提交成功。
#
# 修复:
#   数组元素类型与 indexed 属性类型对齐 (BaseSurveyItem[] -> Answer[]),
#   内省恢复, questions[i].answers[j].content 这类嵌套参数正常绑定
#   (配合 DTO 里已有的懒生长逻辑)。
#
# 运行前提: 本脚本在 agent 环境 (仓库根) 执行, docker 环境已在跑。
# ============================================================
set -e
cd "$(dirname "$0")/../environment/crm-survey"

Q=src/main/java/com/legacy/survey/pojo/Question.java

if ! grep -q "public Answer\[\] getAnswers()" "$Q"; then
    sed -i 's|public BaseSurveyItem\[\] getAnswers() {|public Answer[] getAnswers() {|' "$Q"
    sed -i 's|return answers.toArray(new BaseSurveyItem\[answers.size()\]);|return answers.toArray(new Answer[answers.size()]);|' "$Q"
    echo ">>> 一行修复已应用: getAnswers() 返回类型 BaseSurveyItem[] -> Answer[]"
else
    echo ">>> 修复已存在, 跳过"
fi

echo ">>> 重新构建 war..."
./build.sh

echo ">>> 重启应用 (deploy/ 挂载为 webapps, 重启即换包)..."
cd ..
docker compose restart app

echo ">>> 等待应用就绪..."
CODE=""
for i in $(seq 1 30); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/crm-survey/login.jsp || true)
    [ "$CODE" = "200" ] && break
    sleep 2
done
[ "$CODE" = "200" ] || { echo ">>> 应用未就绪, 请检查 docker logs crm-tomcat"; exit 1; }

echo ">>> 部署完成: http://localhost:8080/crm-survey/login.jsp"
echo ">>> 改动行数: git diff --numstat (应为 2 删 2 增, 预算内)"
