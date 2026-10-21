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

echo ">>> 调用运维标准脚本: 打包 + 部署 + 拉服务 + 等就绪..."
bash /opt/crm-survey/deploy.sh

echo ">>> 部署完成, 可以跑评测了"
echo ">>> 改动行数: git diff --numstat (应为 2 删 2 增, 预算内)"

# ---------- 交付物 2: bug 单 (期望结果 3) ----------
mkdir -p /opt/crm-survey/bugs
BUG=/opt/crm-survey/bugs/BUG-$(date +%Y%m%d)-001.md
cat > "$BUG" <<'EOF'
# BUG-20261021-001 问卷系统受访者回答数据静默丢失

## 标题
受访者提交的问卷回答部分丢失, 页面无任何报错

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
echo ">>> bug 单已提交: $BUG"
