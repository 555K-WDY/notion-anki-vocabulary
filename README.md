# Notion → Anki Vocabulary Skill

一个可复用的 Codex Skill：把 Notion 里零散记录的单词和表达整理成带中文提示、情景、独立联想图、单独词语读音和逐句音频的 Anki 卡片，并在同步后回写 Notion、核对两边是否一致。

它支持从零开始：没有 Notion 页面时创建学习主页和词汇库；没有 Anki 时可通过 Windows Package Manager 安装；没有牌组或卡片模型时自动创建。

## 支持范围

| 项目 | 支持情况 |
|---|---|
| Codex Desktop / CLI | 支持 |
| Windows 10/11 本地运行 | 完整支持 |
| Notion 首次建页建库 | 支持，需要先连接 Notion |
| 自动安装 Anki | 支持，通过 `winget` |
| 安装 AnkiConnect | 半自动：打开 Anki并复制官方插件码，用户在 Anki 中确认安装 |
| macOS / Linux | Skill 指令可用；本地启动和 SAPI 音频脚本暂不支持 |
| Codex Cloud | 可整理 Notion；不能连接用户电脑上的 `127.0.0.1:8765` |

AnkiConnect 是 Anki 内运行的第三方插件，Anki 官方界面要求用户确认安装，因此这里不会绕过确认或把未知插件文件直接写入 Anki 配置目录。

## 最快安装方式

在 Codex 中调用系统自带的 `$skill-installer`：

```text
$skill-installer install from 555K-WDY/notion-anki-vocabulary, path skills/notion-anki-vocabulary
```

Skill 会在下一轮对话可用。然后说：

```text
$notion-anki-vocabulary 初始化我的词汇系统
```

也可以下载或克隆仓库后运行：

```powershell
.\install.ps1
```

## 首次运行会做什么

1. 检查运行环境和本地配置。
2. 如果 Notion 尚未连接，明确提示连接；不会索要或保存 Notion 密钥。
3. 如果没有学习页面，在用户指定的父页面下创建；未指定时创建私人顶层页面。
4. 创建“新增内容”“同步概览”和独立的“词汇整理库”。
5. 如果没有 Anki，在用户明确要求完整初始化或同意安装后执行：

   ```powershell
   .\scripts\install-prerequisites.ps1 -InstallAnki -PrepareAnkiConnect
   ```

6. Anki 打开后，进入 `工具 → 插件 → 获取插件`，粘贴剪贴板中的 `2055492159`，安装并重启 Anki。
7. 验证 AnkiConnect 后，自动创建 `Vocabulary::Active` 牌组和 `Notion Anki Vocabulary` 卡片模型。
8. 把页面 ID、数据库 ID和本机 Anki 路径写入 `%LOCALAPPDATA%\NotionAnkiVocabulary\profile.json`。

Anki 可从[官方网站](https://apps.ankiweb.net/)下载；AnkiConnect 的官方 AnkiWeb 插件码为 [`2055492159`](https://ankiweb.net/shared/info/2055492159)。

## 日常使用

```text
$notion-anki-vocabulary 检查新增内容并同步到 Anki
```

每一条新增词汇都会进入 Anki，学习分类不会取消同步资格。表达不自然时，Skill 会保留原记录、推测原意并用修正后的自然英文制卡。

卡片正面固定包含常用中文和中文情景；背面包含英文答案、每个目标词的独立读音、每条例句的独立音频和该词条专属图片。

如果当前 Codex 没有图像生成能力，Skill 会生成含有词义情景和独立视觉符号的 SVG 后备联想图，不会让多张卡片共用同一张图片。

## 诊断

```powershell
.\skills\notion-anki-vocabulary\scripts\doctor.ps1
```

常见问题及处理方法见 [`references/troubleshooting.md`](skills/notion-anki-vocabulary/references/troubleshooting.md)。

## 测试

测试使用临时目录和模拟 AnkiConnect 服务，不接触真实牌组：

```powershell
.\tests\test-skill.ps1
```

GitHub Actions 会在每次推送后重复执行同一套测试。

## 隐私与安全

- 仓库不包含任何个人 Notion 页面 ID、访问令牌、Anki 数据或媒体。
- 本地 profile 不包含密码，只保存对象 ID、路径和牌组设置。
- 如启用了 AnkiConnect API Key，只通过当前进程的 `ANKI_CONNECT_API_KEY` 环境变量提供，不能写进 profile。
- 不会自动删除重复卡片或未迁移的 Notion 内容。
- 只有 Anki 写入和媒体核验成功后，才会把 Notion 标记为“已同步”。

## English summary

This is a Windows-first Codex skill that bootstraps and runs a Notion-to-Anki vocabulary workflow. It creates missing Notion and Anki structures, corrects natural English, builds multimodal cards, deduplicates notes, verifies media, and writes results back to Notion. Personal IDs and credentials are never committed.

## License

MIT
