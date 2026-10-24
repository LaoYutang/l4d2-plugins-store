# 肉鸽插件维护与代码保密

本文件适用于本目录及其子目录中的肉鸽插件（Rogue / rogue-next），同时遵守仓库根 `AGENTS.md`。

- **不要公开肉鸽插件代码。** 源码仅保存在私有开发仓库，不得上传到插件商店、公开仓库、Release、交付 ZIP、公开文档、评论或其他公开渠道。
- 禁止添加 `.sp`、`.inc`、`scripting/`、源码压缩包或含实现代码的开发文档、测试和构建脚本；不得通过改名、压缩或嵌入说明变相公开源码。本插件不适用根规范中“建议附带源码”的一般建议。
- 分发内容仅限 `README.md`、`left4dead2/addons/sourcemod/plugins/rogue_next.smx`、`left4dead2/cfg/sourcemod/rogue_next.cfg` 和 `left4dead2/addons/sourcemod/gamedata/rogue_next.shotguns.txt`。本 `AGENTS.md` 仅作为商店仓库维护规则，不放入 `left4dead2/`、dist 或交付 ZIP。
- 更新前确认私有开发仓库的最新版本，核对 SMX、配置、Gamedata 和 README；发布前检查暂存文件及压缩包的精确清单，确认不含源码。
- 升级插件或修改版本目录名时，保留本文件及其保密要求。README 面向服主，配置细节以随包 cfg 注释为准，不粘贴实现代码。
