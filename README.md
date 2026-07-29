# moongettext

`moongettext` 是一个用 MoonBit 编写的 GNU gettext 目录工具库。
它可以解析和写出 PO/POT 文本、编译和读取 MO revision 0 二进制，
并提供复数规则、目录校验、模板合并和运行时翻译查询。

## 主要功能

- 解析与规范化写出 PO/POT 文件；
- 支持上下文、单复数消息、多行字符串和常见转义；
- 保留翻译注释、提取注释、来源引用、标志和历史值；
- 识别 `fuzzy` 与废弃条目，并在编译时按规则处理；
- 读写大端和小端 GNU MO revision 0 文件；
- 解析并执行 `Plural-Forms` 表达式；
- 提供 `gettext`、`pgettext`、`ngettext` 和 `npgettext` 查询；
- 提供目录校验、统计、来源查询和 POT/PO 合并；
- 核心库可检查于 wasm、wasm-gc、js 和 native 后端；
- 附带 native CLI 和一个不依赖文件系统的最小示例。

## 安装

```bash
moon add YanFangNie/moongettext
```

在使用该包的 `moon.pkg` 中加入：

```moonbit
import {
  "YanFangNie/moongettext",
}
```

## 最小示例

```moonbit
fn main {
  let source =
    #|msgid "Hello"
    #|msgstr "Bonjour"
    #|
  let document = try! @moongettext.parse_po(source)
  let catalog = try! @moongettext.Catalog::from_po(document)
  println(catalog.gettext("Hello"))
}
```

仓库内的完整示例可以直接运行：

```bash
moon run examples/basic
```

## CLI

CLI 仅支持 native 后端，可用于检查、规范化和编译目录文件：

```bash
moon run cmd/main -- validate examples/fr.po
moon run cmd/main -- normalize examples/fr.po
moon run cmd/main -- compile examples/fr.po _build/fr.mo
moon run cmd/main -- inspect _build/fr.mo
```

## 验证

```bash
moon fmt --check
moon info --target all
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn --warn-list +73
moon build --target native
moon run examples/basic
moon package --frozen
```

## 文档说明

本文件用于 GitHub、GitLink 等代码托管平台的项目首页。
更完整的 API 说明、兼容边界和可由 MoonBit 工具链检查的示例，
请阅读 [README.mbt.md](README.mbt.md)。

## 来源说明

本项目是原创 MoonBit 实现，依据 GNU gettext 的 PO、MO 和
`Plural-Forms` 公开格式规范及可观察行为设计，不是对现有代码库的逐行移植。
仓库未复制 GNU gettext 实现源码、生成代码或第三方目录样例；
Mooncakes 上的 `Zhouz-z/moon_l10n` 侧重 ICU MessageFormat 与目录检查，
本项目侧重 GNU PO/POT/MO 互操作和 gettext 运行时查询。
详细来源链接和兼容范围见 [README.mbt.md](README.mbt.md)。

## 许可证

项目采用 [Apache License 2.0](LICENSE)。
