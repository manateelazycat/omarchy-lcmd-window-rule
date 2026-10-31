# Omarchy LCMD Window Rule

[English](README.md) | 简体中文

统一管理懒猫微服客户端（LCMD）和远程微信的 Omarchy 后台插件。整合了[《Omarchy 安装手册》](https://manateelazycat.github.io/2026/09/20/omarchy-installation-manual/)最后两个章节，以及 Remote WeChat 启动页排除、微信自动选择空白显示器的逻辑。

- 懒猫微服主窗口和每个 App 自动进入下一个空工作区（`emptyn`）。
- 临时的 `Remote WeChat` / `Remote WeChat-…` 连接页面不触发独占工作区规则，避免它关闭后其他显示器留在新切换的空工作区。
- 远程微信不抢初始焦点，也不因激活请求跳到正在使用的工作区。
- 多显示器时，微信优先放到**当前正显示空白工作区**的屏幕，保留其他屏幕的工作区和焦点。微信所在屏幕已经空白时保持原位；存在多块其他空白屏时按显示器 ID 选择。
- 单屏或没有空白屏时保留默认位置。镜像屏、熄屏、显示特殊工作区的屏幕不参与选择。置顶到所有工作区的窗口算作占用；即将关闭的连接页面不算。

仅匹配窗口类名 `wechat`、初始标题 `微信 on cloud.lazycat.catlink.wechat-cde` 的远程微信，不影响本地微信。启用插件时不会重新排列已经打开的窗口。

## 本地安装

需要带 Quickshell 插件系统的 Omarchy，以及支持 Lua 配置的 Hyprland 0.56+。无需额外安装软件包或运行常驻辅助进程。

```bash
cd ~/omarchy-lcmd-window-rule
bash install.sh
```

插件会复制到 `~/.config/omarchy/plugins/io.github.manateelazycat.lcmd-window-rule` 并启用。加 `--no-enable` 只安装，不改变启用状态。配置和状态目录遵循 `XDG_CONFIG_HOME`、`XDG_STATE_HOME`。

更新已安装的副本时会重启 Omarchy 桌面栏服务，清除 Qt 的组件缓存，应用窗口会保留。

## 迁移已有规则

启用前需要移除文章最后两节的手写规则，以及此前的 `require("hypr.remote-wechat")`。也可以使用内置迁移：

```bash
python3 migrate.py                 # 预览能够识别的规则
bash install.sh --migrate          # 备份、迁移、重载并启用
```

迁移只移除文章和此前交互配置中的已知代码，不改写自定义 Lua；自行修改过内容或格式的规则请手动检查。备份位于 `~/.local/state/omarchy/lcmd-window-rule/backups/`，只有识别到旧模块引用和对应文件标记时才会移除旧辅助文件。停用或卸载插件后不会重新启用旧的手写规则。

## 管理

```bash
omarchy plugin disable io.github.manateelazycat.lcmd-window-rule
omarchy plugin enable io.github.manateelazycat.lcmd-window-rule
omarchy-shell io.github.manateelazycat.lcmd-window-rule status
omarchy plugin remove io.github.manateelazycat.lcmd-window-rule
```

插件通过两条带名称的运行时窗口规则和一个 Lua 窗口打开事件订阅工作。停用或卸载会停用规则、取消订阅，重载 Hyprland 配置后自动重新应用。每个服务实例使用独立标记，避免旧实例退出时清掉新实例的规则。不向 `hyprland.lua` 添加永久加载代码。

## 验证

```bash
omarchy plugin validate .
lua tests/rules.lua
python3 -m unittest discover -s tests -p 'test_*.py'
bash -n install.sh
```

## 许可证

Copyright © 2026 Andy Stewart (ManateeLazyCat)。

全部源代码采用 GNU 通用公共许可证第 3 版（`GPL-3.0-only`）开源，完整许可证见 [LICENSE](LICENSE)。
