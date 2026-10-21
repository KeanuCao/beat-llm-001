#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
oracle 转换器: 把题目源码转换成已解状态。

根因: Question.getAnswers() 返回 BaseSurveyItem[](父类数组), 与该属性
indexed 读写的 Answer 类型不一致, java.beans 内省配对失败, 嵌套绑定瘫痪;
SuperBeanConverter 吞掉异常, 受访者回答静默丢失。

转换: 数组元素类型与 indexed 属性类型对齐 (BaseSurveyItem[] -> Answer[]),
一行修复。
"""
import io
import sys

DEFAULT = "src/main/java/com/legacy/survey/pojo/Question.java"

OLD_SIG = "public BaseSurveyItem[] getAnswers() {"
NEW_SIG = "public Answer[] getAnswers() {"
OLD_RET = "return answers.toArray(new BaseSurveyItem[answers.size()]);"
NEW_RET = "return answers.toArray(new Answer[answers.size()]);"


def convert(path):
    with io.open(path, encoding="utf-8") as f:
        s = f.read()
    if NEW_SIG in s:
        print("already converted:", path)
        return 0
    s2 = s.replace(OLD_SIG, NEW_SIG).replace(OLD_RET, NEW_RET)
    if s2 == s:
        print("nothing to convert:", path)
        return 1
    with io.open(path, "w", encoding="utf-8") as f:
        f.write(s2)
    print("converted:", path)
    return 0


if __name__ == "__main__":
    sys.exit(convert(sys.argv[1] if len(sys.argv) > 1 else DEFAULT))
