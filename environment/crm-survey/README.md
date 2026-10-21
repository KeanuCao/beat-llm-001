# CRM 问卷系统 (crm-survey)

老 Java Web 工程: JDK 1.8 + Struts 1.3 + MyBatis 3.2 + MySQL 5.7 + Tomcat 8.5。

## 入口

- 后台: `/crm-survey/login.jsp` (账号见 init-admin.sql)
- 受访者: 邮件里的邀请链接 `/crm-survey/surveyAnswer.do?t=<uuid>`

## 邮件配置

真值不入库: 复制 `src/main/resources/mail.properties.template` 为同目录的
`mail.properties` 并填写 SMTP 账号; 没有这个文件时应用走默认配置,
发信会失败, 但邀请记录照常生成, 作答链路不受影响。

## 日志位置

应用日志跟随 WEB 容器: `$CATALINA_HOME/logs/catalina.out`
(另有按天的 `catalina.<日期>.log` / `localhost.<日期>.log`)。

常用关键字过滤:

```bash
# 业务与定时任务的失败
grep '\[ERROR\]' $CATALINA_HOME/logs/catalina.out
```

## 一分钟自检

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/crm-survey/login.jsp   # 200
mysql -hdb -ucrm -pcrm123 crm_survey -e "SELECT COUNT(*) FROM survey_question;"
ls /opt/crm/mail/   # 已发送邀请的 .eml 留档
```
