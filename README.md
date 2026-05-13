# Ros_car_app

Eggy ROS 小车原生移动客户端仓库：iOS SwiftUI 客户端 + Android 客户端。

后端 Web/中转服务仓库：

```text
https://github.com/liueggy/Ros_car_web
```

默认连接服务器：

```text
wss://liueggy.live/ws
```

## 仓库结构

```text
android/EggyRosCar/        Android Gradle 工程
ios/EggyRobotClient/       iOS SwiftUI + XcodeGen 工程
docs/                      维护说明
.github/workflows/         自动构建与 Release 发布
```

维护说明见：[`docs/MAINTENANCE.md`](docs/MAINTENANCE.md)。

## 功能

- iOS SwiftUI 原生 App
- Android 原生 App
- WebSocket 接收服务器 `nav_view` 数据
- 默认使用 `wss://liueggy.live/ws`，兼容 HTTPS/Nginx 反向代理
- 连接状态区分：App ⇄ 云端 relay、云端 ⇄ 小车 agent、ROS 数据新鲜度
- 内置心跳、超时检测、自动重连退避与发送前连接状态保护
- 总览、电池、导航状态、建图进度
- 地图显示：OccupancyGrid、雷达点、路径、小车姿态、目标点
- 手动控制：前进、后退、平移、旋转、停止
- 自动探索、重置地图
- 预设场景、保存/加载地图

## 本地开发

### iOS

```bash
cd ios/EggyRobotClient
brew install xcodegen
xcodegen generate
open EggyRobotClient.xcodeproj
```

### Android

```bash
cd android/EggyRosCar
gradle assembleDebug
```

## GitHub Actions / Release

工作流：

```text
.github/workflows/ios-client.yml
.github/workflows/android-client.yml
```

自动构建产物会发布到同一个滚动 Release：

```text
tag: mobile-latest
name: Eggy ROS Car Mobile Latest
```

Release 中两个平台产物共存：

- `EggyRosCar-debug.apk`
- `ROS Car-unsigned.ipa`

Android 和 iOS 工作流相互独立：任一平台重新构建只更新自己的资产，不会删除另一个平台的资产。

> iOS 默认产物是未签名 IPA，不能直接安装。请用轻松签、iOS App Signer、Sideloadly、AltStore 或自己的证书重新签名。

如需生成签名 IPA，需要配置 GitHub Secrets：

```text
IOS_CERTIFICATE_P12
IOS_CERTIFICATE_PASSWORD
IOS_PROVISIONING_PROFILE
```
