# Ros_car_app

Eggy ROS 小车 Apple 原生 iOS 客户端。

后端 Web/中转服务仓库：

```text
https://github.com/liueggy/Ros_car_web
```

默认连接服务器：

```text
ws://167.71.221.110:8088/ws
```

## 功能

- SwiftUI 原生 iOS App
- WebSocket 接收服务器 `nav_view` 数据
- 总览、电池、导航状态、建图进度
- 地图显示：OccupancyGrid、雷达点、路径、小车姿态、目标点
- 手动控制：前进、后退、平移、旋转、停止
- 自动探索、重置地图
- 预设场景、保存/加载地图

## 本地开发

```bash
cd ios/EggyRobotClient
brew install xcodegen
xcodegen generate
open EggyRobotClient.xcodeproj
```

## GitHub Actions

工作流：

```text
.github/workflows/ios-client.yml
```

默认构建模拟器 app artifact。

如需生成真机 IPA 并发布 Release，需要配置 GitHub Secrets：

```text
IOS_CERTIFICATE_P12
IOS_CERTIFICATE_PASSWORD
IOS_PROVISIONING_PROFILE
```
