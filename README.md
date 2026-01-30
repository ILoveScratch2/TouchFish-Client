<div align="center">
  <img src="assets/logo.png" alt="TouchFish Logo" width="200"/>
  <p><em>TouchFish Client 是 TouchFish 的现代化的聊天客户端，基于Flutter构建</em></p>
  <a href="https://github.com/ILoveScratch2/TouchFish-Client/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ILoveScratch2/TouchFish-Client" alt="License" /></a>
  <a href="https://github.com/ILoveScratch2/TouchFish-Client/releases"><img src="https://img.shields.io/github/release/ILoveScratch2/TouchFish-Client" alt="latest version" /></a>
  <a href="https://github.com/ILoveScratch2/TouchFish-Client/releases"><img src="https://img.shields.io/github/downloads/ILoveScratch2/TouchFish-Client/total?color=%239F7AEA&logo=github" alt="Downloads" /></a>
</div>

<div align="center">
  <a href="README.md">🇨🇳 中文</a> | <a href="README_en.md">🇺🇸 English</a>
</div>

## 简介

TouchFish Client 是一个基于 Flutter 构建的现代化聊天客户端，旨在为 TouchFish 提供流畅且跨平台的聊天体验。支持 Windows、macOS、Linux 以及移动设备（iOS 和 Android），与 TouchFish 聊天协议完全兼容。


## 截图

仍在开发中，敬请期待！

## 使用
前往Releases页面下载对应平台的可执行文件，安装/运行即可。

需要连接到一个运行中的 TouchFish或其他兼容服务端 服务器。

### 下载与安装

#### Windows

前往 [Releases 页面](https://github.com/ILoveScratch2/TouchFish-Client/releases) 下载`.exe` 文件 或带有 `windows` 的 `.zip` 文件。

注意: MSIX文件没有签名，不推荐下载安装！

最低系统要求为 Windows 10

需要 Microsoft Visual C++ 库，没有可前往 https://learn.microsoft.com/zh-cn/cpp/windows/latest-supported-vc-redist?view=msvc-170 安装，安装后无须重启计算机。


##### 便携版
下载 Release 中的带有 `windows` 的 `.zip` 文件，解压（不可直接运行）后，运行 `exe` 文件即可。

##### 安装版
下载 Release 中的带有 `windows` 的 `.exe` 文件，双击运行，按照安装向导完成安装。

#### macOS

前往 [Releases 页面](https://github.com/ILoveScratch2/TouchFish-Client/releases) 下载 `macos` 的文件。

你可能需要在设置里打开从未认证的开发者处下载的应用

#### Linux

前往 [Releases 页面](https://github.com/ILoveScratch2/TouchFish-Client/releases) 下载 `linux` 的文件。


#### Android

前往 [Releases 页面](https://github.com/ILoveScratch2/TouchFish-Client/releases) 下载 `.apk` 文件，直接安装即可。

如果你了解 `.aab` 文件的使用方法，也可以下载 `.aab` 文件进行安装。

SDK 编译版本 36 (Android 16.0)

SDK 运行版本 36 (Android 16.0)

SDK 最小兼容版本 24 (Android 7.0)

#### iOS

目前尚未提供 iOS 版本的 TouchFish Client（虽然理论上支持，但无相应设备进行调试和发布），敬请期待未来的更新。

## 构建与运行

请确保已安装 Flutter SDK，并配置好开发环境。然后克隆本仓库：

```bash
git clone https://github.com/ILoveScratch2/TouchFish-Client.git

cd TouchFish-Client

flutter pub get

flutter run
```

## 贡献

欢迎任何形式的贡献！无论是报告问题、提出功能请求，还是直接提交代码，我们都非常欢迎。请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解更多信息。


## 许可证

TouchFish Client 采用 [GNU Affero General Public License v3.0](LICENSE) 许可证。

此最强 Copyleft 许可的权限以在同一许可下提供许可作品和修改的完整源代码为条件，其中包括使用许可作品的较大作品。版权和许可声明必须保留 贡献者明确授予专利权。当使用修改后的版本通过网络提供服务时，必须提供修改后版本的完整源代码。
