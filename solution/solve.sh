#!/bin/bash
# ============================================================
# 参考解 (harbor 把 solution/ 拷到容器 /solution/ 下执行), 两处修复共 3 删 3 增:
#   修复一: Question.getAnswers() 数组元素类型与 indexed 属性类型对齐
#   (BaseSurveyItem[] -> Answer[]), java.beans 内省配对恢复, 嵌套绑定
#   就通了; SuperBeanConverter 吞异常才会静默丢数据, 修好即愈。
#   修复二: SurveyAnswerAction 落库分支补 type=2 (多选) —— 勾中的选项
#   按行落库, 不再掉进开放式分支。
#   纯 sed 实现, 别依赖任何脚本外的东西。
# ============================================================
set -e

if [ ! -d /opt/crm-survey ]; then
    echo ">>> 宿主机模式: 把 solution 丢进 crm-main 再执行..."
    docker cp "$(cd "$(dirname "$0")/.." && pwd)/solution" crm-main:/opt/solution
    exec docker exec crm-main bash /opt/solution/solve.sh
fi

cd /opt/crm-survey
Q=src/main/java/com/legacy/survey/pojo/Question.java
A=src/main/java/com/legacy/survey/web/action/SurveyAnswerAction.java

# 修复一: getAnswers() 数组元素类型与 indexed 属性类型对齐, java.beans 内省配对恢复
if grep -q "public Answer\[\] getAnswers()" "$Q"; then
    echo ">>> 修复一已存在, 跳过"
else
    sed -i 's|public BaseSurveyItem\[\] getAnswers() {|public Answer[] getAnswers() {|' "$Q"
    sed -i 's|return answers.toArray(new BaseSurveyItem\[answers.size()\]);|return answers.toArray(new Answer[answers.size()]);|' "$Q"
    echo ">>> 修复一已应用"
fi

# 修复二: 多选题型 (type=2) 落库走选择式分支 (勾中的选项按行落库), 不再掉进开放式分支
# (sed 分隔符用 , —— 替换文本里有 ||, 用 | 会炸)
if grep -q "if (q.getType() == 1 || q.getType() == 2) {" "$A"; then
    echo ">>> 修复二已存在, 跳过"
else
    sed -i 's,if (q.getType() == 1) {,if (q.getType() == 1 || q.getType() == 2) {,' "$A"
    echo ">>> 修复二已应用"
fi

echo ">>> 调用运维标准脚本: 打包 + 部署 + 拉服务 + 等就绪..."
bash /opt/crm-survey/deploy.sh

echo ">>> 部署完成, 可以跑评测了"
echo ">>> 改动行数: git diff --numstat (应为 3 删 3 增, 预算 6 行内)"

# ---------- 交付物 2: bug 单 (期望结果 3, 每个根因一张) ----------
mkdir -p /opt/crm-survey/bugs
BUG1=/opt/crm-survey/bugs/BUG-$(date +%Y%m%d)-001.md
cat > "$BUG1" <<'EOF'
# BUG-20261021-001 问卷系统受访者单选回答数据静默丢失

## 标题
受访者提交的单选问卷回答部分丢失, 页面无任何报错

## 复现步骤
1. 获得一条邀请链接 (survey_invite 中的 uuid)
2. 打开 /crm-survey/surveyAnswer.do?t=<uuid>
3. 填写与邀请匹配的邮箱, 逐题作答后提交
4. 页面提示"问卷已提交", 但查库发现 survey_feedback_question /
   survey_feedback_option 无对应记录 (survey_feedback 正常)

## 根本原因
Question.getAnswers() 声明返回 BaseSurveyItem[](父类数组), 与该属性
indexed 读写的 Answer 类型不一致。JDK 7 的 java.beans 内省对这种
读写配对宽容, 老环境上一直没事; 上周维护窗口 JDK 升到 1.8 后,
Introspector 严格校验读写类型配对, 抛 "type mismatch between read
and write methods", Question 的属性描述符构建不出来, 嵌套参数绑定
瘫痪; SuperBeanConverter.populate 捕获全部异常且不记日志, 绑定失败
被完全吞掉, 于是出现"提交成功但数据丢失"的静默失败。
配置链(surveyConfig.do)已改为手工解析, 不受影响, 这也是同系统只有
受访者数据出问题的原因。

## 影响范围
所有受访者的作答数据 (问卷回答/反馈统计全量失真); 配置链正常。

## 修复方案
将 getAnswers() 的数组元素类型与 indexed 属性类型对齐
(BaseSurveyItem[] -> Answer[]), 内省恢复正常, 嵌套参数绑定连通;
改动一处方法 (两个物理行), 满足紧急补丁的行数限制。
EOF

BUG2=/opt/crm-survey/bugs/BUG-$(date +%Y%m%d)-002.md
cat > "$BUG2" <<'EOF'
# BUG-20261021-002 多选题型的勾选项不落库

## 标题
多选题受访者勾选的选项没有被保存

## 复现步骤
1. 发布一份含多选题 (question_type=2) 的问卷, 邀请受访者作答
2. 受访者在多选题勾选 2 项, 提交, 页面提示"问卷已提交"
3. 查库: survey_feedback_question 有该题的题干行, 但
   survey_feedback_option 里勾选的选项一行都没有
   (answerContent 还被写成了第一个选项的内容, 语义错乱)

## 根本原因
SurveyAnswerAction 落库分支只写了 `if (q.getType() == 1)`, 多选题
(type=2) 掉进了开放式分支 (else), 被当成自由文本题处理: 勾中的
选项不落 survey_feedback_option, 第一个选项的内容还被当作
answerContent 写到题干行上。多选题型是上月"题型三分法"重构时
上线的新功能, 提交侧落库漏了 type=2 的分支。

## 影响范围
所有多选题型的受访者作答, 勾选项全量丢失 (新功能上线即坏);
单选与开放式题不受影响。

## 修复方案
将落库分支条件改为 `if (q.getType() == 1 || q.getType() == 2)`,
多选与单选同为选择式: 勾中的选项 (id>0) 按行落
survey_feedback_option, 多选自然支持多行; 改动一个条件 (一行)。
EOF
echo ">>> bug 单已提交: $BUG1 / $BUG2"
