# TouchFish-Client/lib/l10n

该目录下为 `touchfish_client` 的翻译文件

*注：由于文言无 IANA 语言代码，其语言文件借用 Old Chinese(OCH) 的语言代码

## 修改

请修改当前目录下的 `*.arb` 文件后使用 `flutter pub get`，会自动生成 `app_localizations` 更新。

## 新增

复制一个基本 `.arb` 语言文件，进行修改后运行 `flutter pub get`，会自动生成 `app_localizations`，新增语言需在 `settings_model.dart` 和 `main.dart` 主动支持。

注：新增语言请在所有其余语言里添加 `settingsLanguageXX` 进行修改 
