# SHIYUN

SHIYUN 是一款 macOS 原生的动态古诗词应用：让诗句安静地出现、停留、淡去，并在短暂留白后自然续上下一句。

<p align="center">
  <img src="SHIYUN_logo.png" width="180" alt="SHIYUN">
</p>

<p align="center">一件安静地存在于 Mac 屏幕上的数字诗意作品。</p>

## 下载

从 [Releases](https://github.com/yf-official/SHIYUN/releases/latest) 下载通用 macOS 应用（Apple Silicon 与 Intel）。最低支持 macOS 14。应用内置完整离线诗库，首次启动不需要网络。

## 当前版本

- 原生 SwiftUI，最低支持 macOS 14
- 6942 条离线诗词片段，包含完整的 24 条初始精选，启动与播放均不需要网络
- Shuffle Bag 随机播放与最近 60 条避重
- 2–3 秒淡入淡出、随机停留与随机留白
- 横排与逐字排布的中文竖排
- 真正的 macOS 全屏、方向键/空格切换下一句
- 鼠标静止后自动隐藏的轻量控制层
- 本地收藏，以及“只播放我的收藏”个人诗选模式
- 收藏清单支持搜索，以及按朝代、作者筛选
- 诗词总库支持索引化全文搜索、朝代/作者筛选和直接收藏
- 个人诗选支持 JSON、CSV、TXT 多文件批量导入，按诗句正文自动查重
- 收藏与总库支持导出 SHIYUN JSON 或一行式纯文本 TXT
- “我的创作”使用本机 SQLite 数据库，支持不限长度的原创诗文、新建、编辑、搜索与 TXT 导出
- 简体中文 / English 界面切换
- 跟随系统 / 浅色 / 深色外观
- 9 种系统中文字体（宋、楷、苹方、黑体、仿宋、圆体、丽宋、魏碑、兰亭黑）、字号、自定义诗句颜色；署名信息同步继承正文的字体与颜色
- 默认氛围、用户自选纯色或本地图片背景；图片自动压缩到最长边 3840 px
- 运行时缓存硬上限为 8 MB，启动时清理最旧缓存；背景只保留当前一张且不超过 6 MB
- 自定义诗句停留（8–120 秒）和留白（1–15 秒），保留轻微自然随机
- 菜单栏入口与 Apple `SMAppService` 登录时启动
- Reduce Motion、VoiceOver 与 Retina 适配

## 运行

直接用 Xcode 打开 `SHIYUN.xcodeproj`，选择 `SHIYUN` scheme 后运行。

命令行构建：

```sh
xcodebuild -project SHIYUN.xcodeproj -scheme SHIYUN -configuration Debug build
```

工程由 `project.yml` 管理。如修改工程结构并已安装 XcodeGen，可执行：

```sh
xcodegen generate
```

正式版构建：

```sh
xcodebuild -project SHIYUN.xcodeproj -scheme SHIYUN -configuration Release -derivedDataPath DerivedData-Release build CODE_SIGNING_ALLOWED=NO
```

## 内容库

运行以下命令可重建并验证离线诗库：

```sh
python3 Scripts/build_poetry_dataset.py
python3 Scripts/validate_poetry.py
```

数据模型与界面逻辑完全分离，新增内容只需更新 `SHIYUN/Resources/Poetry/poetry.json`。生成脚本基于公共领域作品，并从 [chinese-poetry](https://github.com/chinese-poetry/chinese-poetry) 的结构化文本中筛选适合屏幕独立呈现的片段；运行时不会联网。参考稿中出处不稳定的现代流传句保留原文，并明确标注为“现代·佚名”，不冒充古人作品。

## 交互

- 移动鼠标或点击画面：显示控制层
- `→` 或空格：下一句
- `⌘F`：收藏/取消收藏当前诗句
- `Esc`：退出系统全屏
- 设置 → 诗词 → 播放范围：在完整诗库与个人收藏之间切换
- 设置 → 诗库：在“我的收藏 / 诗词总库 / 我的创作”之间切换
- 收藏可批量导入 JSON、CSV、TXT，并导出 JSON 或 TXT
- TXT 导出示例：`明月松间照，清泉石上流。--山居秋暝  唐·王维`

### 批量导入格式

- JSON：可直接重新导入 SHIYUN 导出的文件；只需提供 `text`，作者、诗名和朝代均可选。
- CSV：表头只要求 `text`（或“诗句”）；可选 `author`、`title`、`dynasty`，两句之间用 `/` 分隔。
- TXT：每首之间空一行；诗句写在前一或两行，末行可写 `作者 | 诗名 | 朝代`。也支持重新导入 SHIYUN 导出的一行式 TXT。

用户导入时不需要填写“山水、月”等标签。导入查重会忽略诗句中的空格、换行和标点差异，同时检查文件内部、个人诗库和内置诗库；重复项不会再次占用存储空间。

## 目录

```text
SHIYUN/
├── App/                 App 入口与共享模型
├── Models/              诗词、设置模型
├── Services/            诗库、Shuffle Bag、调度与收藏
├── Theme/               统一色彩与字体
├── Views/               Ambient、设置、收藏、关于
├── Resources/Poetry/    离线诗库与分类
└── Assets.xcassets/     正式 Logo 与 App Icon
```

Logo 位于 `SHIYUN_logo.png`，应用图标资源位于 `SHIYUN/Assets.xcassets/`。

## 隐私

SHIYUN 不联网、不上传诗词或背景图片。收藏、导入内容与原创诗文只保存在本机；应用不会收集分析数据或个人资料。
