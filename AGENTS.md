# AGENTS.md — obs-zoom-to-mouse

本仓库会由 **Codex** 与 **Grok Bot（Codex总控 / 项目专线）** 共同改代码。线程之间不共享聊天上下文，只认本仓库文件与 git。

## 开工前（强制）

1. 阅读本仓库的 docs/HANDOFF.md（若无则根目录 HANDOFF.md）。
2. 若有 git：执行 git status 与 git log -5 --oneline。
3. 发现与交接冲突或未提交改动时：先向用户说明，再继续。

## 收工前（强制）

1. 更新同一份 HANDOFF：时间（Asia/Shanghai）、改动摘要、涉及路径、原因、未完成点、如何验证。
2. 尽量 git add + git commit（勿提交密钥、cookies、.venv、.env、本地秘密配置）。
3. 在回复里用一两句话说明「已写进 HANDOFF / 是否已提交」。

## 环境

- 默认 Windows 11；Python 优先用项目 .venv（未激活时用 .venv\Scripts\python.exe）。
- 默认中文回复与中文文档。
