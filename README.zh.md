# RetroLab

[English](README.md) · [改动记录](发布记录.md)

这是一版中文胶片相机。取景时就能看到胶片颜色，按下快门后相纸滑出、显影，成片按取景比例裁切，并带上白相框。

基于 [AlvaroLopezLoayza/RetroLab](https://github.com/AlvaroLopezLoayza/RetroLab) 的 `bd7991a` 改的，没有推回原作者。当前版本 **1.2.3**。

## 能做什么

- 拍照时实时看到胶片颜色，不用拍完才知道效果。
- 录像走同一套胶片处理，结束时是「视频出片中」，不再进旧的冲洗页。
- 19 种胶卷，用彩色胶卷罐左右滑动选择。拍立得、口袋 110、一次性闪光是小机身。
- 虚拟胶卷、闪光、延时、前后镜头、相纸。
- 照片存在本机，也可以再冲洗。不上传。

## 胶卷

| 名字 | 感觉 |
| --- | --- |
| 柯达金 200 | 日光暖调 |
| 柯达金 400 | 更暖更艳 |
| 肖像 400 | 肤色柔和 |
| 鲜艳 100 | 细腻鲜红 |
| 日常 400 | 偏冷的绿 |
| 浓彩 200 | 红色很冲 |
| 风光 50 | 浓艳反转 |
| 自然 100 | 干净中性 |
| 经典黑白 | 阴影透一点 |
| 街拍黑白 | 对比强 |
| 细颗粒黑白 | 干净细腻 |
| 夜灯 800 | 霓虹夜景 |
| 日光电影 | 日光卤光 |
| 拍立得 | 黑位被抬起 |
| 交叉冲印 | 暗角很重 |
| 过期 1998 | 偏品红发灰 |
| 一次性闪光 | 直闪硬光 |
| 口袋 110 | 颗粒很粗 |
| 自定义 400 | 标准彩色负片 |

名字写在 `lib/core/zh.dart`，颜色和颗粒写在 `lib/core/film_stocks.dart`。

## 怎么拍

1. 在底下的胶卷罐里选一卷。
2. 取景窗里看颜色，再按快门。
3. 相纸滑出来，白一下就显出刚拍的画面。
4. 成片带白相框，和取景是同一个比例。

## 安装

Android arm64 安装包在 [Releases](https://github.com/chazai233/RetroLab/releases) 里，文件名 `RetroLab-1.2.3-arm64.apk`。装的时候如果系统拦截，允许安装这个来源即可。

## 自己编译

需要 Flutter SDK 和 Android 工具链。

```bash
flutter pub get
flutter run
```

打安装包：

```bash
flutter build apk --release --target-platform android-arm64
```

检查：

```bash
flutter analyze
flutter test
```

录像处理只在 Android 上。照片和设置都存在本机的 Hive 里。
