# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库定位

这是一个 LLM 评测题的题目包（Harbor 风格），不是普通业务仓库。各目录的角色：

- `instruction.md`：交给解题模型的题面，改它等于改题，措辞会被逐项质检。
- `environment/`：解题模型能看到的**全部**内容（源码 + `docker-compose.yml`）。任何提示、根因、参考解片段都不能写进这里，包括注释和文件名（二轮质检有专门检查项）。
- `solution/solve.sh`：参考解，在解题环境中执行，必须能把题做对。
- `tests/test.sh`：评测脚本，独立于 agent 环境执行，必须把 `1`/`0` 写到 `/logs/verifier/reward.txt`（崩溃、异常、超时也要落 `0`）。
- `task.toml`：超时与资源（agent 900s / environment 900s / build 600s / verifier 300s，1 CPU / 4GB）。
- `review/`：一轮（题面/环境/测试/参考解）和二轮（构建、端到端、反硬编码、注释泄露）质检报告模板。

## 常用命令

从仓库根执行；Windows 上用 Git Bash 跑 shell 脚本（脚本必须保持 LF）。

```bash
# 启动/重建整套环境；db 容器首次初始化时自动执行 schema.sql
cd environment && docker compose up -d --build

# 编译 war：builder 容器内 mvn package，产物复制到 crm-survey/deploy/
cd environment/crm-survey && ./build.sh

# 重新部署（deploy/ 被挂载为 Tomcat webapps，app 只重启、不可 exec）
cd environment && docker compose restart app
docker logs -f crm-tomcat

# 重置数据库：compose 故意没有数据卷，down 后重建会重跑 schema.sql
cd environment && docker compose down && docker compose up -d --build

# 查库核对行数（题目只禁止进入 app 容器，db 容器可以查）
docker exec crm-mysql mysql -ucrm -pcrm123 crm_survey -e "SELECT COUNT(*) FROM survey_question;"

# 模拟一次带 CSRF 的提交：GET 响应里已含 token，保存 cookie 后 POST
curl -s -c /tmp/cj http://localhost:8080/crm-survey/survey_config.jsp -o /tmp/page.html
TOKEN=$(sed -n 's/.*name="csrfToken" value="\([^"]*\)".*/\1/p' /tmp/page.html)
curl -s -b /tmp/cj -X POST http://localhost:8080/crm-survey/surveyConfig.do \
  --data-urlencode "csrfToken=$TOKEN" --data-urlencode "surveyName=demo" --data-urlencode "id=0" \
  --data-urlencode "questions[0].type=1" --data-urlencode "questions[0].sort=1" \
  --data-urlencode "questions[0].text=Q1" \
  --data-urlencode "questions[0].answers[0].content=A1" \
  --data-urlencode "questions[0].answers[1].content=A2" \
  --data-urlencode "questions[0].answers[2].content=A3"
```

构建依赖外网：CentOS vault 源、archive.apache.org（Tomcat 8.5.9 / Maven 3.3.9）、aliyun Maven 镜像；首次构建较慢，`build_timeout_sec = 600`。

## 运行架构

三台"机器"模拟 2006 年的部署方式：

- **builder**（`crm-builder` 镜像）：CentOS 7 + JDK 8 + Maven 3.3.9，仅由 `build.sh` 拉起；源码挂到 `/build`，产出 `target/crm-survey.war` 并复制到 `crm-survey/deploy/`。app 镜像里没有 Maven。
- **app**（容器 `crm-tomcat`）：CentOS 7 + JDK 8 + Tomcat 8.5.9；`deploy/` 挂载为 `webapps`；`start.sh` 先用 `/dev/tcp` 等 db 端口再启动 Tomcat。
- **db**（容器 `crm-mysql`）：MySQL 5.7 + utf8，`schema.sql` 只在容器首次初始化时执行；不映射端口、不挂数据卷（重建即重置，故意的）。连接信息固定为 `db:3306`，账号 `crm/crm123`（见 `jdbc.properties`）。

请求链路：

```
survey_config.jsp
  → CsrfFilter (/*)：GET 在 session 里生成 CSRF_TOKEN；POST 必须带同名 csrfToken 参数，否则 403
  → ActionServlet (*.do) → SurveyConfigAction
  → LegacyBeanConverter → commons-beanutils 按 questions[0].answers[1].content 这类嵌套路径灌入 SurveyDTO
  → SurveyQuestionMapper (MyBatis 3.2.8 接口 + mapper XML)
  → MySQL
```

要点：

- Struts 1.3 配置里**没有 form-bean**，参数绑定完全靠 `LegacyBeanConverter`（commons-beanutils），这是理解本工程的关键。
- 数据模型分配置态与发布态：`standard_question` / `standard_question_option` 是草稿配置；`survey_question` / `survey_question_option` 是发布/提交时复制出来的快照。表之间不建物理外键，关联由应用层保证，主键全部自增。
- `mapUnderscoreToCamelCase=true` 只在 MyBatis 的查询映射里生效；本工程目前没有结果映射，只有 insert。
- Java 8 源码级别，Struts 1.3 / MyBatis 3.2.8 / MySQL 5.7 / Tomcat 8.5.9 都是刻意锁定的老版本，不要顺手升级无关依赖。

## 当前进度与已知不一致（写测试/参考解前必看）

1. **`solution/solve.sh`、`tests/test.sh` 和 `task.toml` 的 `[metadata]` 还是最初物理题的残留**：solve.sh 在改 `/app/simulation.py`，test.sh 在跑 `python3 /app/simulation.py` 并 grep `13.6|121.567`，metadata 是 `physics-coding`/`quantum-mechanics`。与 CRM 题完全不符，验收逻辑需要按题面重写（HTTP 提交后行数 2/6、连续 10 次 20/60、页面 `saved=1`、`bugs/` 下五节 bug 单）。
2. 题面称数据库里有 **`Patient Experience & Satisfaction Survey (OPD/IPD)-201608`**，但 `schema.sql` 只有两份中文问卷，没有这条数据。
3. 题面给的入口是 `http://localhost:8080/survey_config.jsp`，但 war 的 `finalName` 是 `crm-survey`，实际上下文路径为 `http://localhost:8080/crm-survey/survey_config.jsp`（JSP 表单用 `contextPath` 拼 action，所以页面本身能跑）。两者需对齐（改入口说明或改成 ROOT 部署）。
4. 当前应用只插入 `survey_question`：`SurveyQuestionMapper` 只有一个 insert，`saveQuestions` 只遍历题目；JSP 提交的选项 `questions[i].answers[j].content` 没有落库路径。按题面"2 题 × 3 选项"验证，现状必然失败。且 JSP 第 2 题写死为问答（type=3），题面要求两道单选题。
5. 关键代码可疑点（疑似故意埋点，参考解和测试前先确认）：
   - `SurveyDTO.getQuestions()` 是 `(Question[]) questions.toArray()`，`toArray()` 返回 `Object[]`，运行期会 `ClassCastException`；同时与 `getQuestions(int)` 重载影响 JavaBean 内省。
   - `LegacyBeanConverter.populate` 捕获所有异常后只打一条 WARN，参数绑定失败会静默丢数据。
   - `saveQuestions` 只捕获 `IndexOutOfBoundsException` 作为循环终止条件。
6. JUnit 依赖已在 `pom.xml`，但 `src/test/java` 不存在；本仓库没有单测。`tests/` 是评测脚本目录，不是 JUnit 目录。
7. `bugs/` 是解题模型的交付目录（`BUG-<日期>-<序号>.md`，含标题/复现步骤/根本原因/影响范围/修复方案五节），当前仓库中没有。

## 修改约束

- 修复必须落在 `environment/crm-survey/` 的应用代码里；`pom.xml` 依赖调整允许。禁止改库补数据、绕过应用写数、修改运行环境来掩盖问题。
- 不能进入 app 容器执行任何操作（`docker exec crm-tomcat` 禁止）；验证走 HTTP/浏览器，查数据走 db 容器。
- 修改 `schema.sql` 后必须重建 db 容器才会生效（initdb 只在首次启动执行）。
- 素材和题库文件（`instruction.md`、`review/`、测试/参考解）用中文，和现有风格保持一致。
