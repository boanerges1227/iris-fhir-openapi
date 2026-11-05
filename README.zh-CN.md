# IRIS FHIR OpenAPI

[English](README.md) | 简体中文

安装在 InterSystems IRIS / IRIS for Health 内的 ObjectScript 原生模块。读取 FHIR R4 CapabilityStatement，生成供企业 API Gateway 导入的 OpenAPI 3.0.3 JSON。

当前开发版本：**0.1.0**。支持本地 FHIR 端点、已登记 HTTP(S) 来源和上传 JSON；提供英文管理页、REST 与终端入口。运行时不需要 Python、Node、外部 Web 服务或 AI。

## 输出范围

- 根据声明生成读取、版本读取、创建、更新、删除、补丁、搜索、历史和系统 batch/transaction。
- 支持资源/交互筛选、公开网关地址、条件交互开关、认证声明、strict/report 策略。
- GET 查询与 POST 表单保留 FHIR 字符串语法；不擅自补齐未声明的搜索参数。
- 单文件内部 Schema 引用、固定键排序、来源哈希、覆盖统计和具体未覆盖项报告。
- **gateway 简化 Schema** 允许资源扩展字段，用于路由与文档；不是完整 FHIR/Profile 校验器。
- 自定义操作只报告名称、canonical 和位置；未解析 imports、未知 modifierExtension、错误输入会阻断。

此前已用本地 R4 端点生成规范并导入 Kong 3.9；不代表兼容所有网关或产品版本。

## 使用流程

1. 在目标命名空间安装模块并给使用者授权。
2. 准备当前命名空间的 FHIR 端点、已登记的 HTTP(S) 来源，或一份 CapabilityStatement JSON。
3. 在管理页面预览能力，选择要公开的资源和交互，填写网关对外地址及安全声明。
4. 生成并审阅规范和诊断报告，再将规范交给网关团队。生成过程只读取元数据，不调用患者数据接口。

## 安装

在目标命名空间安装。安装者需要 IRIS 安全管理权限，以及该命名空间的代码/数据访问权限。包不会创建 FHIR Server、修改现有端点或自动给用户赋角色。

### IPM

本项目还没有发布到公共 registry。推荐使用当前源码；本地曾生成的 `dist` 离线包不包含在仓库中，且为较早构建，未包含后续英文界面更改：

```objectscript
zpm "load /path/to/iris-fhir-openapi"
// 或从已经生成的离线包安装
zpm "load /path/to/iris-fhir-openapi-0.1.0.tgz"
```

默认登录地址为 `/fhir-openapi-<命名空间小写>_login/index.html`，例如 USER 为 `/fhir-openapi-user_login/index.html`；登录后进入 `/fhir-openapi-user/`。安装前检查应用路径与静态文件所有权，拒绝覆盖其他项目文件。

### 手工导入

没有 IPM 时，在目标命名空间执行：

```objectscript
set sc=$SYSTEM.OBJ.LoadDir("/path/to/iris-fhir-openapi/src","ck",,1)
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc)
set sc=##class(FHIR.OpenAPI.Install).Setup($namespace,"/fhir-openapi","/path/to/iris-fhir-openapi/web")
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc)
```

安装只在上述状态成功时完成。浏览器打开 `/fhir-openapi_login/index.html`，使用 IRIS 账号登录后进入受保护的 `/fhir-openapi/`。

### 给实际用户授权

在安装命名空间取得角色名：

```objectscript
write ##class(FHIR.OpenAPI.Access).Resource()_"_Admin",!
```

由管理员在 Management Portal 将这个角色赋给实际用户，并保留用户已有的命名空间/数据库访问权限。本地读取还受端点原有权限约束。角色名含命名空间摘要，避免名称字符规范化碰撞。

独立登录应用只允许匿名读取固定静态登录文件，禁止 CSP/REST 执行；它不提供任何元数据功能。管理应用要求密码认证，每个页面/API/Service 入口再次检查模块 USE 权限。不会给应用配置 `%All` 或自动给用户赋角色。Web Gateway 的 HTTPS 和企业现有登录策略由部署环境配置。

## 页面使用

1. 登录英文界面，选择当前命名空间端点、已登记 HTTP(S) 地址，或上传 CapabilityStatement JSON。
2. 点击 “Read & Preview”，检查来源范围、资源、交互和警告。
3. 筛选公开资源和交互，填写网关对外地址、标题、版本和公开 API 认证。
4. 点击 “Generate OpenAPI”，检查报告后下载 `openapi.json` 与 `generation-report.json`。

源内容改变会返回 409，需重新预览。修改筛选或导出配置会使旧规范失效。HTTP 源凭据每次请求后清空；生成前需重新输入。凭据不写入浏览器持久存储、报告或规范。

## 本地 FHIR 来源

只接受当前命名空间的明确端点路径，例如 `/fhir/r4`。使用产品的端点策略与 LoadMetadata 接口动态读取，不静态依赖 Health 类。

普通 IRIS 安装核心后可使用文件与 HTTP 来源；本地来源需要产品与许可支持，并已在当前命名空间配置 FHIR 服务。不会跨命名空间切换取数。配置能力不等于某调用者通过网关之后的授权视图。

## HTTP(S) 来源登记

登记精确的 FHIR 基础 URL、固定 IP 和 SSL 配置，必须由已有安全管理权限的管理员操作：

```objectscript
set sc=##class(FHIR.OpenAPI.Config).RegisterSource("https://fhir.example.org/r4","192.0.2.10","CustomerFHIRClientTLS")
```

示例地址为占位符，需替换为实际登记目标。取数连接登记 IP，保留逻辑 Host/SNI，并验证可信证书链和证书主机名；不会在请求阶段重新解析 DNS、跟随重定向或转发当前 IRIS 会话凭据。

**HTTPS 采集的调用者还需要已有 `%Admin_Secure:USE` 及系统命名空间读取权限。** IRIS 对 SSL 配置的访问有安全边界，模块每次采集检查配置是否启用客户端模式、要求可信证书链，防止已登记配置被调低；模块不绕过边界或自动提权。无此权限可使用本地或上传文件来源。查询只读取策略列，不调用会返回私钥口令的配置 Get API。

本地开发可明确登记 HTTP 例外：

```objectscript
set sc=##class(FHIR.OpenAPI.Config).RegisterSource("http://127.0.0.1:8091/fhir","127.0.0.1","",1)
```

源认证支持 anonymous、Basic、Bearer，单次请求提供；公开规范的 `security` 是另一套独立配置。OAuth flows 中的可申请 scopes 不自动变成全部接口必需 scopes；可在 API 配置中显式提供 `security.requiredScopes`。

## 生成选项与诊断

请求示例见 [examples/file-request.json](examples/file-request.json)。`publicBaseUrl` 是网关对外提供给消费者的 FHIR 基础地址；`info` 填写规范标题和版本。`resources.include` 与 `interactions.include` 限制公开范围，`searchMethods` 可选择 GET 和 POST；`includeMetadata` 控制 `/metadata`，`includeConditionalInteractions` 控制支持的集合条件交互。`schemaMode` 当前为 `gateway`。

`security` 描述网关对外认证，与采集元数据时使用的源认证分开配置。`failurePolicy` 为 `report` 时允许有警告的结果；`strict` 在出现警告时阻断生成。报告包含来源哈希、统计和诊断，交付前应检查遗漏项；被阻断的结果不包含可下载规范。

## REST

管理应用下提供：

| 方法与路径 | 用途 |
|---|---|
| `GET /api/v1/health` | 已认证管理员的模块状态与会话 CSRF token |
| `POST /api/v1/inspect` | 校验并预览来源，返回 `sourceHash` |
| `POST /api/v1/generate` | 带 `expectedSourceHash` 生成规范与报告 |

使用 IRIS 密码认证/同源会话。POST 必须带 health 返回的 `X-CSRF-Token`，有 Origin 时必须同源。请求 JSON 参考 [文件来源示例](examples/file-request.json)。不要把实际密码写进可提交的配置文件。

生成返回 `httpStatus`、`status`、`openapi` 与 `report`。失败时 `openapi` 为 null；report 模式允许 warning，strict 模式阻断 warning。错误码包括配置400、权限403、变化409、输入过大413、语义/生成422、上游502、超时504、并发429。

## 终端

```objectscript
set input=##class(%Stream.FileCharacter).%New()
set input.Filename="/path/to/request.json"
set sc=##class(FHIR.OpenAPI.CLI).Generate(input,.specification,.report)
```

输入示例见 `examples/file-request.json`。调用者检查 `%Status` 并自行选择输出路径；模块不根据 REST 参数读取任意服务器文件，也不持久保存导出历史。

## 故障排查

- **登录后 403**：确认用户拥有安装命名空间的模块角色及数据库访问权限；本地 FHIR 来源还需端点本身的权限。
- **来源不允许或 HTTPS 策略错误**：由安全管理员检查来源登记的精确 URL、固定 IP、SSL 配置、证书链与调用者权限。HTTP 例外必须显式登记。
- **409**：来源快照已经变化，请重新预览后生成；HTTP 来源凭据需要重新输入。
- **422**：检查报告中 FHIR 版本、输入完整性及诊断；严格模式下 warning 也会阻断。
- **429 / 504**：分别表示命名空间任务槽已满或超出时间预算；稍后重试并检查来源响应。

## 限制与兼容性

- 首版只支持 FHIR R4 `4.0.1`、OpenAPI `3.0.3`、JSON。
- 输入元数据上限10 MiB、REST 请求12 MiB、规范 UTF-8 文件25 MiB；浏览器下载使用紧凑 JSON并再次检查字节数。
- 同一命名空间最多2个同步任务。使用进程锁自动释放，无后台队列。
- 总预算30秒，在生成遍历、序列化和受控 HTTP 读取中检查。网络空闲等待不超过15秒，连接等待不超过5秒；产品内部单次本地 LoadMetadata 调用不是可抢占任务，超时不代表能取消产品底层操作。
- HTTP 元数据读取支持 Content-Length、chunked 和连接关闭定界；不接收压缩响应，不作为通用 HTTP 代理。
- 简化 Schema、自定义操作遗漏、profile 未展开等边界在报告中显式披露。
- 不调用患者数据端点，不从患者数据构造样例，不自动发布网关配置。
- 每个安装使用独立代码数据库；共享Routines数据库不能独立升级/卸载代码。
- 已测试 IRIS for Health Community 2026.2 和 IRIS Community 2026.3 AI 预览版；没有测试的旧版本不承诺兼容。

## 开发验证

需 Docker、Python 3、OpenSSL；Python 包仅开发使用：

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
```

创建独立 IRIS 测试容器，将项目挂载到 `/workspace` 后：

```sh
IRIS_TEST_CONTAINER=iris-fhir-openapi-test scripts/run-tests.sh
python3 scripts/create-test-user.py --container iris-fhir-openapi-test
python3 scripts/test_rest.py --base http://127.0.0.1:53985/fhir-openapi-user
.venv/bin/python scripts/validate_openapi.py .local/openapi.json
```

单元脚本自动启动容器内合成元数据服务，并在 `.local` 生成测试证书；测试账号初始化脚本只在指定的专用容器创建随机账号和密码，凭据保存在权限为 0600 的 `.local/rest-test-auth.json`，不会覆盖已有文件。重复运行时可用 `--output` 指定新的文件。所有样例和 fixtures 均为合成数据。`.local`、虚拟环境、测试账号与私钥不进 IPM 包。

`docker compose up --build -d` 可构建独立开发实例（本机53985端口）；仍需管理员为实际用户授权，镜像不创建单独的演示账号，也不创建 FHIR Server。

Docker 开发镜像会将内置管理员账号重置为 `_SYSTEM` / `SYS`。打开 [http://127.0.0.1:53985/fhir-openapi-user_login/index.html](http://127.0.0.1:53985/fhir-openapi-user_login/index.html) 即可登录。该已知密码仅供隔离的本机 Docker 测试使用，不应将该镜像暴露到不可信网络或用于生产；IPM 和手工安装不会重置管理员密码。单独创建的其他测试容器端口可能不同。

## 卸载

```objectscript
zpm "uninstall iris-fhir-openapi"
// 手工部署仅清理入口与静态配置
set sc=##class(FHIR.OpenAPI.Install).Uninstall()
```

只删除模块拥有的入口、静态资源和代码。角色/权限资源与来源登记保留，供管理员确认没有引用后清理。不会删除 FHIR 服务、数据库、命名空间或客户 SSL 配置。
