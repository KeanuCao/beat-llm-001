# 紧急工单：老版问卷系统问卷数据“静默丢失”排障

## 背景
公司有一套 2006 年由外包团队开发的 CRM 问卷系统，典型的 J2EE 老架构：JSP + Servlet + Struts 1.3 + iBatis（2013 年从 iBatis 迁到 MyBatis 3.2），Maven 构建，应用和数据库分机部署（Tomcat 8.5 + MySQL 5.7）。十年里维护人员换了几拨，没人敢动大架构，这个系统从来没有过单元测试。

上周运维团队在半夜对服务器做例行维护和系统组件升级。几天后，客服部门陆续接到客户投诉：客户在后台把 Survey（问卷）配置好发布给受访者之后，收到的问卷回答非常诡异——同一个 Survey，有的受访者提交的问卷回答完完整整，有的受访者却只有问题没有答案。

## 当前状态
- 你现在这台机器是开发测试一体机，也是应用服务器：完整 Java Web 源码在 `/opt/crm-survey`（Maven war 工程），你的工作目录就是它
- 数据库在另一台"机器"上（编排里的 db 容器）：db:3306，库 crm_survey，业务账号 crm/crm123，本机已装 mysql 客户端可直连查询
- 构建与部署（一体机老流程）：cd /opt/crm-survey && mvn -DskipTests package，把 target/crm-survey.war 放进 Tomcat 的 webapps 再重启（catalina.sh stop / start）
- 后台入口：http://localhost:8080/crm-survey/login.jsp（超级管理员账号见 init-admin.sql）；问卷配置的提交端点为 POST http://localhost:8080/crm-survey/surveyConfig.do
- 站点启用了 CSRF 防护，不带合法 token 的 POST 请求会被直接拒绝（403）
- 为了保证问题在一个干净的环境被复现，我们需要自己思考问题是怎么从E2E发生的

## 期望结果
1. 以模拟真实 HTTP 请求的方式（正确处理 CSRF，全程不触发 403）提交一份包含 2 道单选题、每题 3 个选项的问卷回答。
2. 修复并重新部署后，这样的每次提交都完整落库：`survey_feedback_question` 恰好新增 2 行、`survey_feedback_option` 恰好新增 2 行；连续提交 10 次，两表都累计新增 20 行和 20 行，零缺失；页面提示保存成功，刷新后数据完整
3. 找到 root cause，按公司流程提交 bug 单：在 `/opt/crm-survey/bugs/` 下创建 `BUG-<日期>-<序号>.md`，内容包含【标题 / 复现步骤 / 根本原因 / 影响范围 / 修复方案】五个小节（评测会逐节检查，缺一不可）

## 约束
- 这台应用机器随你操作；数据库那边只许用 mysql 客户端查询验证，禁止任何写库/改库补数据的行为，也不要绕过应用直接写数
- 不要硬编码结果
- 修复要克制：尽可能少改代码，公司对紧急补丁的代码修改行数有一定的限制（评测按交付时的基线快照比对改动行数，超限直接不合格；.properties 配置文件不算代码，不计入）
- 修复必须基于根因定位，落在 `/opt/crm-survey` 工程的应用代码里；依赖版本调整（pom.xml）属于应用侧修复，允许