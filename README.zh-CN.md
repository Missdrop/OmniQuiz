<p align="center">
  <img src="assets/branding/logo.png" alt="万物一点通" width="120">
</p>
<h1 align="center">万物一点通 · OmniQuiz</h1>
<p align="center"><strong>你的资料，你的 AI，刷不完的练习。</strong></p>
<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong><br>
  <a href="https://github.com/Missdrop/OmniQuiz/releases/latest">下载</a> ·
  <a href="#三步开始">开始使用</a> ·
  <a href="CONTRIBUTING.md">参与贡献</a> ·
  <a href="https://github.com/Missdrop/OmniQuiz/issues">反馈问题</a>
</p>

课件看完了，却不知道自己会了多少？把笔记、教材或课件交给万物一点通，让 AI 根据**你的学习资料**出题。一边作答，一边自动补题，直到你结束练习。

**导入资料 → 开始练习 → 自动补题 → 回看错题**

## 不只是“帮我出几道题”

- **一直练，不用反复点生成。** 待答题不足时自动补充；随时结束，已生成的题目离线也能做。
- **按你的方向出题。** 放入样题或样卷，写下“多考应用、少考记忆”等要求。修改要求保留现有题目，评价也会用于后续出题。
- **答案有出处。** 每题附解析和资料引用；PDF 可以直接查看原页，做错的题留到复习时再练。
- **自己选 AI。** 直接登录 ChatGPT，或连接 OpenAI 兼容 API（包括 CLIProxyAPI）。保存多个连接，明确选择当前用哪一个。

## 三步开始

1. **建资料库**：导入 TXT、Markdown 或可选中文字的 PDF。电脑可关联文件夹，手机可导入文件或 ZIP。
2. **连 AI**：在「设置 → 配置 AI」添加 ChatGPT 订阅或 OpenAI 兼容 API 连接。
3. **开始练习**：选择资料范围，点击「开始练习」。想贴近考试风格？先在「出题设置」里放入样卷。每次出题数量和自动补题阈值也在这里设置，默认均为 10。

目前支持四选一单选题，点击选项即作答。扫描版 PDF 需先做文字识别。生成需要联网，并使用所选服务的订阅额度或 API 用量。

## 下载

| 平台 | 选择这个 |
| --- | --- |
| Windows | [MSI 安装包](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-windows-x64.msi) · [免安装 ZIP](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-windows-x64.zip) |
| Android | [APK（多数手机）](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-android-arm64-v8a.apk) |
| macOS | [DMG 安装包](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-macos.dmg) |
| Linux | [tar.gz 归档](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-linux-x64.tar.gz) |

[全部文件与更新说明](https://github.com/Missdrop/OmniQuiz/releases/latest)中还有其他 Android 架构，以及需自行签名的 iOS 归档。Windows 尚未代码签名，macOS 尚未公证。Nightly 为预览版。

**升级由你决定。** 独立发行版可检查更新、稍后提醒或跳过版本；只有点击更新才下载，失败时可打开官方下载页。Microsoft Store 版本由商店更新；iOS 仅提供更新提醒和下载页。

## 资料跟着你走

每个资料库独立保存题目、错题和进度。样题、出题要求及学习数据库都在资料库的 `.omniquiz` 文件夹里；关掉软件后，可以一起迁移。也可以在设置中导出和恢复备份，恢复不会覆盖已有资料库。账号和密钥不包含在备份中。

中英文界面、出题语言及外观默认跟随系统，也可单独设置；支持白天和黑夜模式。

## 你的资料会去哪里？

资料和进度保存在本机。出题时，所需资料片段、样题、要求及近期评价直接发送到**你选择的 AI 服务**。账号凭据由系统安全存储保管；软件没有自建后端，也不收集使用分析。详见[隐私政策](assets/legal/privacy_zh.txt)。

AI 可能出错，请结合原文核对答案。

## 一起完善

欢迎提交问题、改进体验或贡献代码。环境搭建、测试与打包见 [CONTRIBUTING.md](CONTRIBUTING.md)。

Copyright © 2026 Missdrop · [GPL-3.0-only](LICENSE)

字体：[Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)，[SIL OFL 1.1](assets/fonts/OFL.txt)。
