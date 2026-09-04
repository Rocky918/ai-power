# AI Power

AI Power 是一款原生 macOS 菜单栏工具。当 ChatGPT 或 Codex 桌面应用运行时，它会显示当前最长用量周期的剩余百分比，并在弹窗中列出 Codex 实际返回的全部用量周期。

> AI Power 是非官方独立项目，与 OpenAI 无隶属、授权或背书关系。

## 功能

- 菜单栏 OpenAI 标志、彩色余量环和剩余百分比
- 动态显示服务端返回的 5 小时、每周及其他独立额度池
- 自动识别 ChatGPT/Codex 运行状态，关闭后隐藏
- 启动、每 60 秒及打开弹窗时刷新；失败时保留上次数据
- 剩余量低于 20% 显示橙色，低于 10% 显示红色并按周期通知一次
- 中文/英文跟随系统，也可手动切换
- 登录时启动（首次运行默认开启，可在设置中关闭）
- 所有数据均通过本机 Codex 登录状态读取，不获取密码或浏览器 Cookie

## 下载与安装

从 [Releases](https://github.com/Rocky918/ai-power/releases) 下载最新的 `AI-Power-*-macOS.zip`。

1. 解压 ZIP。
2. 将 `AI Power.app` 拖入“应用程序”文件夹。
3. 首次启动时右键应用并选择“打开”，再确认一次“打开”。
4. 启动并登录 ChatGPT 或 Codex 桌面应用。

由于公开版本采用 ad-hoc 临时签名且未经过 Apple 公证，macOS 首次运行时会显示开发者验证提示。若右键打开仍被阻止，请前往“系统设置 → 隐私与安全性”选择“仍要打开”。

## 兼容性

- macOS 13 或更高版本
- Universal 2：同时支持 Apple Silicon（M 系列，`arm64`）与 Intel（`x86_64`）
- 需要已安装并登录 ChatGPT/Codex 桌面应用

## 隐私

AI Power 只调用本机 Codex app-server 的用量读取接口。应用不会收集、上传或保存密码、浏览器 Cookie、访问令牌或聊天内容。

## 从源码构建

项目是标准 Swift Package，可直接在 Xcode 中打开 `Package.swift`。

命令行构建 Universal 2 安装包：

```shell
zsh Scripts/package.sh
```

产物会生成在 `dist/`。打包脚本分别构建 `arm64` 和 `x86_64`，再使用 `lipo` 合并成 Universal 2 应用。

运行核心自测：

```shell
swift run AIPowerCoreSelfTest
```

## 许可证与商标

源代码采用 [MIT License](LICENSE)。`OpenAILogo.svg` 及 OpenAI 名称和标志不包含在 MIT 授权中；相关商标归 OpenAI 所有，仅用于标识本工具所连接的服务。
