# CLIProxy Menu Bar Monitor (Swift)

极简菜单栏版本（macOS），按你的场景只做两件事：

1. 按 `sk-key` 分组展示模型调用次数
2. 一键「开启监控 / 关闭监控」

## 功能

- 菜单栏显示总请求数（关闭监控时显示 `OFF`）
- 弹窗按 `sk-key -> 模型` 列出调用次数（优先显示 `antigravity/*`）
- 监控开关（开启/关闭）
- 仅保留 `退出` 按钮
- 自动读取 CLIProxyAPI 配置（不要求用户手动填写）

兼容说明：
- 如果 `usage` 数据里没有 `antigravity/` 前缀（旧版统计格式），会自动回退展示实际上游模型名，避免空列表。
- `sk-key` 在 UI 中会做脱敏显示（如 `sk-xxxx...yyyy`）。

## 运行

```bash
cd macos-menubar/CLIProxyMenuBar
swift run CLIProxyMenuBar
```

## 自动配置来源

应用会按顺序自动查找 `config.yaml`：

1. `CLIPROXY_CONFIG_PATH`（环境变量）
2. 当前目录 `config.yaml`
3. 当前目录上级 `../CLIProxyAPI/config.yaml`
4. `~/05-api-代理/CLIProxyAPI/config.yaml`
5. `~/CLIProxyAPI/config.yaml`
6. `~/.cliproxyapi/config.yaml`

并自动读取：

- `port`
- `remote-management.secret-key`

## 使用的接口

- `/v0/management/usage`

鉴权：

- Query: `?key=<MANAGEMENT_KEY>`
- Header: `Authorization: Bearer <MANAGEMENT_KEY>`
