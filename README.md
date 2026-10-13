# Lumen Camera - 无 Mac 使用指南

你没有 macOS，但只有 iPhone 和 Windows？没问题！本指南教你用 **GitHub Actions 免费编译 + SideStore 安装** 的方式，在 iPhone 上运行这个相机 App。

## 整体流程

```
你的代码 → 推送到 GitHub → Actions 自动编译 → 下载 .ipa → SideStore 安装到 iPhone
```

---

## 第一步：创建 GitHub 仓库

1. 注册/登录 [GitHub](https://github.com)
2. 新建仓库，命名为 `LumenCamera`（公开或私有均可）

## 第二步：上传代码到 GitHub

在 Windows 上操作：

**方式 A：用 GitHub Desktop（推荐新手）**
1. 下载 [GitHub Desktop](https://desktop.github.com)
2. File → Clone Repository，选择你刚创建的仓库
3. 把 `LumenCamera` 文件夹里的所有文件复制到克隆下来的仓库目录
4. 点击 Commit，然后 Push

**方式 B：用命令行 Git**
```bash
cd LumenCamera
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/你的用户名/LumenCamera.git
git push -u origin main
```

## 第三步：云端自动编译

1. 推送到 GitHub 后，打开仓库页面
2. 点击顶部 **Actions** 标签
3. 你会看到一个名为 "Build LumenCamera" 的工作流正在运行
4. 等待约 5-10 分钟，状态变成绿色 ✓ 表示编译成功
5. 点进该次运行，页面最下方 **Artifacts** 区域，下载 `LumenCamera-ipa`（解压得到 .ipa 文件）

> 如果失败，点进日志查看错误，截图发给我帮你排查。

## 第四步：安装 SideStore 到 iPhone

SideStore 是一个免越狱的 App 安装工具，能用你的免费 Apple ID 给 App 签名（7 天有效，到期可在手机上续签）。

1. iPhone 用 Safari 打开 https://sidestore.io
2. 按照页面指引安装 SideStore（需要配合电脑或 JIT 服务器）
   - **最简单方式**：用 Windows 电脑运行 `SideStore` 提供的配对工具，通过 Wi-Fi 给 iPhone 安装
3. 打开 SideStore，登录你的 Apple ID（免费账号即可）

## 第五步：安装 LumenCamera.ipa

1. 把下载的 `LumenCamera.ipa` 传到 iPhone（可用 AirDrop、微信文件传输、网盘等）
2. 在 iPhone 上用 SideStore 打开这个 .ipa 文件
3. 点击安装，等待完成
4. 桌面会出现 "Lumen Camera" 图标

> ⚠️ 免费 Apple ID 签名的 App **7 天后会过期**。到期前在 SideStore 里点 "Refresh" 续签即可（需要 iPhone 和电脑在同一 Wi-Fi，或使用 SideServer）。

## 常见问题

**Q: 编译失败怎么办？**
A: 打开 Actions 里的失败日志，把红色错误部分截图发给我。

**Q: 7 天过期太麻烦？**
A: 可以考虑花 $99/年购买 Apple Developer Program，签名有效期 1 年。或者租用云端 Mac（约 $1/天）长期开发。

**Q: 我想修改代码后重新编译？**
A: 修改文件后 commit & push，Actions 会自动重新编译，下载新的 .ipa 用 SideStore 覆盖安装即可。

**Q: 想直接在云端用完整 Xcode？**
A: 可以租 [MacinCloud](https://www.macincloud.com)（$1/天起）或 [MacStadium](https://www.macstadium.com)，通过远程桌面连接，体验和本地 Mac 一样，适合频繁调试。
