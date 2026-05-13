# EggyRobotClient iOS 原生客户端

SwiftUI 原生 iOS 客户端，连接 `Ros_car_web` 服务器 WebSocket：

```text
wss://liueggy.live/ws
```

## 功能

- 实时接收 `nav_view` 数据
- 默认使用 `wss://liueggy.live/ws`，适配当前 HTTPS/Nginx 入口
- 区分服务器连接、小车在线、ROS 状态和数据延迟
- 心跳、超时检测、自动重连退避和发送前状态保护
- 总览：连接、导航、电池、距离、建图进度
- 地图：OccupancyGrid、雷达点、全局路径、局部路径、小车姿态、目标点
- 控制：前进/后退/平移/旋转/停止、自动探索、重置地图
- 设置：服务器地址、预设场景、保存/加载地图、日志

## 本地生成 Xcode 工程

需要 macOS + Xcode + XcodeGen：

```bash
brew install xcodegen
cd ios/EggyRobotClient
xcodegen generate
open EggyRobotClient.xcodeproj
```

## GitHub Actions 自动编译

工作流：

```text
.github/workflows/ios-client.yml
```

默认会在 macOS runner 上构建 **模拟器 app artifact**。

## 生成 IPA / Release

Apple 真机 IPA 需要签名资产。请在 GitHub Secrets 配置：

```text
IOS_CERTIFICATE_P12          # base64 后的 p12 证书
IOS_CERTIFICATE_PASSWORD     # p12 密码
IOS_PROVISIONING_PROFILE     # base64 后的 mobileprovision
```

然后手动触发 workflow_dispatch，会尝试 archive/export IPA，并上传到 GitHub Release。

> 没有 Apple Developer 签名资产时，GitHub Actions 不能产出可安装真机 IPA，只能产出未签名/模拟器构建产物。
