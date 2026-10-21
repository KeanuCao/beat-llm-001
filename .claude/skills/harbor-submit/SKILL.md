---
name: harbor-submit
description: 题包推送平台送审前的自检清单 —— task.toml 格式、单 Dockerfile 编排形态、脚本可终止、反作弊三查、题面与验收逐字对齐、沙箱双态回归。改完 environment/、tests/、instruction.md、solution/ 准备 push 送审时必跑。
---

# 平台送审自检（一次过清单）

三轮送审三轮翻车的坑全沉淀在这里。**任何涉及 environment/、tests/、
instruction.md、solution/ 的改动，push 前把五节全部过一遍。**

**version 纪律**：每次改代码（尤其 environment/）必须更新
`environment/crm-survey/version`（内容 = `date +%Y%m%d%H%M%S` 输出，14 位）并随
提交一并 push —— test.sh 开头会打出它，黑盒 trial 靠这个定位"跑的是哪个版本"。

## 1. 结构门禁：task.toml 格式 + compose 键白名单（launch 硬门禁，一键违规整个评测起不来）

**task.toml 格式校验**（第一道门）：`schema_version` 必须 ≥ **"1.3"**（平台校验要求，
早期缺这一行被整份打回）。以仓库当前 task.toml 为基准模板 —— 已通过平台校验：

```toml
schema_version = "1.3"

[task]          # name / authors / version
[metadata]      # category = "debugging" / difficulty_explanation = "hard"
[verifier]      # timeout_sec = 600.0
[agent]         # timeout_sec = 1200.0
[environment]   # cpus / memory_mb / storage_mb / allow_internet / build_timeout_sec
```

改 task.toml 只在这个骨架上动字段值，不删节不降版本号；超时数值要与 test.sh
实际耗时匹配（verifier 含强制重建部署，平台跑完一次"正常完成但 0"后把
verifier 1200s / agent 2400s 翻倍给了余量 —— 平台机器比本地慢，超时宁大勿小）。

**编排形态：单 Dockerfile，无 compose**（第 1/3 轮各栽一次 compose 禁键后彻底弃用）。
environment/ 只有 `Dockerfile` + `crm-survey/`；base = **ubuntu 22.04 + 清华 apt 源**
（实测三方对比：清华 update 4.4s / 原生 archive 7.9s / **aliyun ubuntu 镜像 101.8s**
—— aliyun 的 ubuntu archive 对谁都慢，用户侧 install 层曾 488s，清华 15.9s；
apt 的 maven 包会强拉 openjdk-11-jre-headless 42MB 浪费，maven 用 tarball 3.6.3）。
MariaDB 10.6 与沙箱同构、5.5 语法坑消失（`CREATE USER IF NOT EXISTS` 是 10.1.3 才有）。
镜像=静态包（构建期 db 初始化+war 部署），ubuntu 镜像**不带 curl 必须显式 apt 装**
（agent 联调要用）；mariadb 配置 include 目录在 /etc/mysql/conf.d（debian 系）。
**冷构建实测 59.8s**（--no-cache 全冷，对比 centos 时代 9m21s = 9.4 倍）。
`jdbc.properties` 连 `localhost:3306`；容器保活在 CMD（见第 2 节）。本地测试/调试
命令见 crm-deploy skill。
task.toml 的坑史：早期 `schema_version` 缺失/低于 1.3 被打回，`[metadata]` 还残留过
物理题元数据（category=physics）。

**如果将来要恢复 compose**（先掂量值不值）：平台只允许这些键 ——
`build, command, depends_on, entrypoint, environment, expose, healthcheck, hostname,
image, init, labels, platform, restart, stdin_open, stop_grace_period, stop_signal,
tty, user, working_dir`；禁止 `ports`、`container_name`、`volumes`、`network_mode`、
`pid`、`privileged`。**每次送审前全量校验，不是只查上轮报错的键**（坑史：db 的
`container_name`+`ports`；之后 main 的 `container_name` 又因本地调试习惯复发）；
服务调试一律用服务名（`docker compose logs main` / `docker compose exec main bash`）。

## 2. 脚本可终止（non_terminating_process 门禁）

- environment/ 下所有 `.sh` 不得以常驻命令收尾：`tail -F/-f`、`sleep infinity`、
  `while true`、无界 `until` 循环都算。
- **铁律：一切初始化放构建期（RUN）+ 服务"谁需要谁拉起"** —— harbor 起容器是
  `run -d` 即返，**没有人等启动逻辑跑完**，oracle/verifier 几秒后就冲进容器（竞态实测撞过车）。
  - 构建期 RUN：db 的 datadir/建库/种子（临时实例导完即 shutdown；重建容器 = datadir
    回镜像层 = 数据重置）、war 构建并部署进 webapps —— 镜像里全是**静态包**
  - `CMD ["sleep", "100000000"]` 纯保活 —— **不依赖 CMD 做任何事**，harbor 是否
    override 它都无所谓
  - 服务拉起收敛到**一个幂等脚本**（`deploy.sh`：编译→打 war→部署重启→确保 mysqld
    在跑→等就绪，重复执行=重新部署）；solve.sh 和 test.sh 开头都调它
  - 题面把脚本指给 agent："服务不随机自启，用标准脚本拉起"—— agent 不在环境管理上花时间
- 容器保活在 Dockerfile CMD：`["/bin/bash","-c","/docker-entrypoint.sh && exec sleep 100000000"]`
  （CMD 内联不是 .sh 文件，不在本门禁打击面；纯数字秒数免老 coreutils 兼容问题）。
- 保活设计不能害死换包流程：PID1 不要设成 java（Tomcat），否则 solve.sh 里
  `catalina.sh stop` 会连容器一起带走。
- 连带门禁语义：动态执行视角也会查（脚本真的要能退出）。

## 3. 反作弊三查（扣分大头，每轮都在变着花样查）

1. **跨界复制**：验证侧（tests/）任何文件不得与环境侧文件逐字节相同。
   基线快照这类资产放镜像构建期（`RUN tar czf /opt/.baseline/...`），验证侧从
   tar 解包比对。新增任何"参照物"时先问：它是否是环境文件的副本？
2. **评审文档隔离**：整改意见、评审反馈、质检报告一律放 `.qc-sandbox/`（本地），
   **严禁进 tests/ 或仓库任何跟踪路径** —— 会被反作弊扫描判成"评审引导"扣分。
3. **判分点防预埋**：fixtures 全随机（uuid/邮箱/时间戳），掩码现算；验收含运行时
   版本检查、验收前强制源码重建部署（堵改产物不改源码）；行数预算逐文件比对。
4. **db 初始化的坑**：`mysql_install_db`（= centos 系首启行为）会留**匿名用户**
   （''@localhost 等）；账号匹配 **host 优先于 user**，匿名行会吃掉本机 TCP 连接、
   把具名账号顶成 `Access denied (using password: YES)` —— 建号前先
   `DELETE FROM mysql.user WHERE user=''`；entrypoint 建完库必须用**验收同款
   连接方式**（TCP + 业务账号）自检，不通 exit 1。

## 4. 题面 ↔ 验收逐字对齐（题面行为覆盖分）

验收脚本里的每一处断言，题面必须有对应表述；"agent 需从实现反向推导"就是扣分：
- 端点 URL 与提交报文字段形状（含嵌套 `questions[i].answers[j]` 路径）
- 成功/错误页面文案逐字对齐（"问卷已提交"、"链接无效"、"您已经回答问卷"）
- 数量要求写全（**含主表**）、行数上限写数值（4 行）、bug 单文件名格式给示例
- 异常路径语义（403/无效邀请/重复提交）与运行时版本（JDK 1.8）都在题面点明

**泄底红线**：以上都是"验收语义"，可以写；诱因、根因、修复方向一个字不能写。
注意措辞别反向暗示 —— 例：写"验收在 JDK 1.8 上进行"（中性事实），不写
"不许降级 JDK"（暗示降级有救）。environment/ 内注释不出现 oracle/评审/门禁/根因字样。

## 5. 沙箱双态回归（push 前最小验证集）

沙箱无 docker，原生等价环境（JDK8+Maven+MariaDB+Tomcat）常驻，验收：

```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64   # 沙箱默认是 11, 容器靠 Dockerfile ENV, 沙箱必须手动
APP_URL=http://127.0.0.1:8080/crm-survey DB_HOST=127.0.0.1 DB_PORT=3306 \
SRC_DIR=/home/workspace/project/environment/crm-survey/src \
APP_HOME=/home/workspace/project/environment/crm-survey \
BUGS_DIR=/home/workspace/project/.qc-sandbox/bugs \
BASELINE_TAR=/opt/.baseline/src.tar.gz bash tests/test.sh
```

双态都要跑：
- 未修复 → reward=0（功能行数拦）
- 修复态 → reward=1（diff 恰好在预算线）
- 顺带核对 runtime 检查没有误伤（沙箱残留 JDK11/7 进程会被拦 —— 这是检查在工作，
  先 `catalina.sh stop; JAVA_HOME=... start` 恢复再跑）

**还原纪律**：实验性修改 src 后必须 `git checkout -- <file>` 还原；war 必须与
src 同态（验收的强制重建段会自动把 war 重建回 src 的状态，跑哪态就停哪态）；
基线 tar（BASELINE_TAR）必须始终是未修复态。

**沙箱盲区**（血的教训：重写 Dockerfile 时丢了基线 tar 段，沙箱全绿、真容器 0 分）：
沙箱的等价环境是**手工预置**的 —— BASELINE_TAR 是手动打的 tar、数据库是 apt 独立
装的 —— 所以 **Dockerfile / entrypoint 里对应段的缺失或失败，沙箱测不出来**。
改动这两个文件后必须人工核对：基线 tar 段还在（`grep tar czf environment/Dockerfile`）、
entrypoint 的 db 初始化每一步都有失败检查（不允许静默继续）、预算检查是 fail-closed
（BASELINE_TAR 缺失 = fail，不是跳过）。
