# 紧急工单：老版问卷系统问卷数据“静默丢失”排障

## 背景
公司有一套 2006 年由外包团队开发的 CRM 问卷系统，典型的 J2EE 老架构：JSP + Servlet + Struts 1.3 + iBatis（2013 年从 iBatis 迁到 MyBatis 3.2），Maven 构建，应用和数据库分机部署（Tomcat 8.5 + MySQL 5.7）。十年里维护人员换了几拨，没人敢动大架构，这个系统从来没有过单元测试。

上周运维团队在半夜对服务器做例行维护和系统组件升级。几天后，客服部门陆续接到客户投诉：客户在后台把 Survey（问卷）配置好发布给受访者之后，收到的问卷回答非常诡异——同一个 Survey，有的受访者提交的问卷回答完完整整，有的受访者却只有问题没有答案。

## 当前状态
- 完整 Java Web 源码在 `environment/crm-survey/`（Maven war 工程）
- 运行环境由 `environment/docker-compose.yml` 编排：app（Tomcat）+ db（MySQL 5.7）两个容器，数据库已按 `crm-survey/schema.sql` 自动初始化
- 构建与部署：在 `environment/crm-survey/` 下执行 `./build.sh` 编译，war 会放到 `crm-survey/deploy/` 并被 Tomcat 自动部署；修改代码后重跑 `./build.sh` 并重启 app 容器即可生效
- 访问入口：http://localhost:8080/survey_config.jsp
- 站点启用了 CSRF 防护，不带合法 token 的 POST 请求会被直接拒绝（403）
- 为了保证问题在一个干净的环境被复现，我们需要自己思考问题是怎么从E2E发生的

## 期望结果
1. 以模拟真实 HTTP 请求的方式（正确处理 CSRF，全程不触发 403）提交一份包含 2 道单选题、每题 3 个选项的问卷数据
2. 修复并重新部署后，这样的每次提交都完整落库：`survey_question` 恰好新增 2 行、`survey_question_option` 恰好新增 6 行；连续提交 10 次，两表分别累计新增 20 行和 60 行，零缺失；页面提示保存成功，刷新后数据完整
3. 找到 root cause，按公司流程提交 bug 单：在仓库根目录 `bugs/` 下创建 `BUG-<日期>-<序号>.md`，内容包含【标题 / 复现步骤 / 根本原因 / 影响范围 / 修复方案】五个小节

## 约束
- app 容器可以重启，但不允许进入 app 容器执行任何操作，请通过 HTTP 请求或浏览器来验证
- 不要硬编码结果
- 修复必须基于根因定位，落在 `environment/crm-survey/` 工程的应用代码里：禁止直接改数据库补数据、禁止绕过应用写数、禁止用修改运行环境的方式回避问题；依赖版本调整（pom.xml）属于应用侧修复，允许