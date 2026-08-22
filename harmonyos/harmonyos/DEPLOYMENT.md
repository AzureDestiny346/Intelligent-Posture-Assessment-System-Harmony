# 智能体态分析 HarmonyOS 客户端 — 项目部署说明

## 一、项目概述

本项目为**智能体态分析系统**的 HarmonyOS 客户端，基于 ArkTS 语言开发，使用 DevEco Studio 作为 IDE。

- **应用包名**：`com.titaifenxi.app`
- **当前版本**：`2.0.0`（versionCode: 1000000）
- **目标 SDK**：HarmonyOS 5.0.0 (API 12)
- **兼容 SDK**：HarmonyOS 5.0.0 (API 12)
- **运行时 OS**：HarmonyOS
- **支持设备**：phone（手机）、tablet（平板）

### 项目结构

```
harmonyos/
├── AppScope/                    # 应用级配置
│   └── app.json5                # 应用信息（包名、版本等）
├── entry/                       # 入口模块
│   └── src/main/
│       ├── ets/
│       │   ├── common/          # 常量配置（Constants.ets）
│       │   ├── entryability/    # 应用入口 Ability
│       │   ├── model/           # 数据模型
│       │   ├── pages/           # 页面（Index / ResultPage / HistoryPage）
│       │   ├── service/         # 网络服务（HttpService.ets）
│       │   └── util/            # 工具类（PreferencesUtil.ets）
│       └── resources/           # 资源文件
├── build-profile.json5          # 构建配置
└── oh-package.json5             # 依赖管理
```

---

## 二、环境准备

### 2.1 开发工具

| 工具 | 版本要求 | 说明 |
|------|---------|------|
| **DevEco Studio** | 5.0+ | 华为官方 HarmonyOS 开发 IDE |
| **HarmonyOS SDK** | API 12 (5.0.0) | 在 DevEco Studio 中通过 SDK Manager 安装 |
| **Node.js** | 16+ | 构建工具链依赖 |

### 2.2 安装 DevEco Studio

1. 访问 [华为开发者联盟](https://developer.huawei.com/consumer/cn/deveco-studio/) 下载 DevEco Studio
2. 安装完成后首次启动，进入 **SDK Manager**
3. 安装以下组件：
   - **HarmonyOS SDK**（API 12）
   - **Ohpm**（包管理工具）

### 2.3 导入项目

1. 打开 DevEco Studio，选择 **File → Open**
2. 选择项目根目录 `harmonyos/`
3. 等待 IDE 自动同步依赖（底部状态栏会显示同步进度）
4. 同步完成后，确认项目无红色错误标记

---

## 三、服务器连接配置

### 3.1 服务器地址

客户端通过 HTTP 与后端服务器通信，服务器地址配置在：

**文件路径**：`entry/src/main/ets/common/Constants.ets`

```typescript
static readonly SERVER_URL: string = 'http://10.0.2.2:5000';
```

### 3.2 地址说明

| 场景 | 服务器地址 | 说明 |
|------|-----------|------|
| **模拟器运行** | `http://10.0.2.2:5000` | `10.0.2.2` 是 HarmonyOS 模拟器访问宿主机 `localhost` 的特殊 IP |
| **真机调试（同一局域网）** | `http://<电脑局域网IP>:5000` | 例如 `http://192.168.1.100:5000`，需确保手机与电脑在同一网络 |
| **远程服务器** | `http://<服务器公网IP>:<端口>` | 需确保服务器防火墙开放对应端口 |

### 3.3 修改服务器地址

根据实际部署环境，修改 `Constants.ets` 中的 `SERVER_URL`：

```typescript
// 示例：真机调试，电脑 IP 为 192.168.1.100
static readonly SERVER_URL: string = 'http://192.168.1.100:5000';

// 示例：远程服务器
static readonly SERVER_URL: string = 'http://your-server.com:5000';
```

### 3.4 后端 API 接口

客户端依赖以下后端接口：

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 健康检查 | `GET` | `/health` | 检测服务器是否可用，支持最多 2 次自动重试 |
| 上传分析 | `POST` | `/upload` | 上传三张体态照片并获取 AI 分析结果 |

#### `/upload` 请求格式

- **Content-Type**：`multipart/form-data`
- **表单字段**：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `front_image` | image/jpeg | 正面照 |
| `side_image` | image/jpeg | 侧面照 |
| `back_image` | image/jpeg | 背面照 |

#### `/upload` 响应格式

```json
{
  "analysis": { ... },
  "message": "分析完成"
}
```

#### 错误码说明

| HTTP 状态码 | 含义 |
|------------|------|
| 200 | 成功 |
| 413 | 图片文件过大 |
| 429 | 请求过于频繁 |
| 500+ | 服务器错误 |
| 503 | AI 服务不可用 |

### 3.5 网络超时配置

在 `Constants.ets` 中可调整超时参数：

```typescript
static readonly CONNECT_TIMEOUT: number = 10000;   // 连接超时：10秒
static readonly UPLOAD_TIMEOUT: number = 60000;     // 上传超时：60秒
```

### 3.6 权限说明

应用需要在 `entry/src/main/module.json5` 中声明以下权限：

| 权限 | 用途 |
|------|------|
| `ohos.permission.INTERNET` | 访问网络，与服务器通信 |
| `ohos.permission.CAMERA` | 拍照获取体态照片 |
| `ohos.permission.READ_IMAGEVIDEO` | 从相册选择照片 |
| `ohos.permission.WRITE_IMAGEVIDEO` | 保存压缩后的临时照片 |

---

## 四、启动后端服务器

在运行客户端之前，**必须先启动后端服务器**。

### 4.1 本地启动（开发环境）

在后端项目目录下执行（具体命令参考后端项目文档），确保服务器监听在 `5000` 端口：

```bash
# 示例（以后端使用 Python Flask 为例）
python app.py
```

启动成功后，终端应显示类似：

```
* Running on http://0.0.0.0:5000
```

### 4.2 验证服务器是否启动

在浏览器中访问健康检查接口：

```
http://localhost:5000/health
```

返回 `200 OK` 即表示服务器正常运行。

### 4.3 客户端验证连接

1. 启动客户端后，首页顶部会显示连接状态：
   - 绿色圆点 + **"服务器已连接"** → 连接成功
   - 红色圆点 + **"服务器未连接"** → 连接失败，可点击"（点击重试）"重新检测

2. 如果连接失败，请排查：
   - 后端服务器是否已启动
   - 服务器地址和端口是否正确
   - 模拟器：确认使用 `10.0.2.2` 而非 `127.0.0.1`
   - 真机：确认手机与电脑在同一局域网，且地址使用电脑局域网 IP
   - 防火墙是否放行了 `5000` 端口

---

## 五、运行 HarmonyOS 项目

### 5.1 模拟器运行

#### 步骤一：创建模拟器

1. 打开 DevEco Studio，进入 **Tools → Device Manager**
2. 点击 **"+"** 创建新模拟器
3. 选择设备类型（推荐 Phone），选择系统镜像（HarmonyOS 5.0）
4. 完成创建后启动模拟器

#### 步骤二：配置服务器地址

确保 `Constants.ets` 中的地址为模拟器专用地址：

```typescript
static readonly SERVER_URL: string = 'http://10.0.2.2:5000';
```

#### 步骤三：运行项目

1. 在 DevEco Studio 顶部运行配置栏选择 **entry** 模块
2. 选择目标设备为刚创建的模拟器
3. 点击 **▶ Run** 按钮（或按 `Shift + F10`）
4. 等待编译完成，应用将自动安装到模拟器并启动

### 5.2 真机运行

#### 步骤一：开启开发者模式

1. 在 HarmonyOS 设备上进入 **设置 → 关于手机**
2. 连续点击 **版本号** 7 次，开启开发者模式
3. 返回 **设置 → 系统与更新 → 开发人员选项**
4. 开启 **USB 调试**

#### 步骤二：连接设备

1. 使用 USB 数据线连接手机与电脑
2. 手机上弹出授权提示时，点击 **允许**
3. 在 DevEco Studio 的 **Device Manager** 中确认设备已识别

#### 步骤三：配置服务器地址

真机调试需将服务器地址改为电脑的局域网 IP：

```typescript
// entry/src/main/ets/common/Constants.ets
static readonly SERVER_URL: string = 'http://192.168.x.x:5000';  // 替换为实际 IP
```

#### 步骤四：配置签名

真机运行需要配置签名信息：

1. 进入 **File → Project Structure → Project**
2. 勾选 **Automatically generate signature**（自动签名）
3. 或使用已有的调试签名证书

#### 步骤五：运行项目

1. 顶部运行配置栏选择 **entry** 模块
2. 目标设备选择已连接的真机
3. 点击 **▶ Run**（或按 `Shift + F10`）
4. 等待编译、签名、安装完成，应用将在真机上启动

### 5.3 命令行构建（可选）

如需命令行构建 HAP 安装包：

```bash
# 在项目根目录执行
hvigorw assembleHap --no-daemon
```

构建产物位于：`entry/build/default/outputs/default/entry-default-signed.hap`

---

## 六、常见问题排查

### Q1：首页显示"服务器未连接"

| 排查项 | 操作 |
|--------|------|
| 后端是否启动 | 浏览器访问 `http://localhost:5000/health` |
| 地址是否正确 | 模拟器用 `10.0.2.2`，真机用局域网 IP |
| 防火墙 | 关闭或放行 5000 端口 |
| 网络连通性 | 真机确认与电脑在同一 WiFi |

### Q2：DevEco Studio 无法识别设备

- 确认 USB 调试已开启
- 重新插拔 USB 线
- 安装华为手机助手（HiSuite）驱动
- 重启 ADB 服务：`hdc kill` 然后 `hdc start`

### Q3：编译报错 "Module not found"

- 在 DevEco Studio 中执行 **File → Sync and Refresh Project**
- 确认 `oh_modules` 目录已正确生成
- 检查网络连接，确保 ohpm 仓库可访问

### Q4：拍照/选图功能不可用

- 确认应用已授予相机和相册权限（首次启动时会弹出权限申请）
- 如误拒绝了权限，进入 **设置 → 应用 → 体态分析 → 权限** 手动开启

### Q5：上传图片过大

- 客户端会自动压缩图片至 1920px 以内，JPEG 质量 85%
- 文件大小上限为 32MB
- 如仍超限，请选择更小的图片

---

## 七、技术栈总结

| 类别 | 技术 |
|------|------|
| 开发语言 | ArkTS |
| UI 框架 | ArkUI（声明式） |
| IDE | DevEco Studio 5.0+ |
| SDK | HarmonyOS SDK API 12 |
| 网络库 | @kit.NetworkKit（http 模块） |
| 相机 | @kit.CameraKit |
| 相册 | @kit.MediaLibraryKit |
| 图片处理 | @kit.ImageKit |
| 文件操作 | @kit.CoreFileKit |
| 日志 | @kit.PerformanceAnalysisKit（hilog） |
| 本地存储 | Preferences（首选项） |
| 包管理 | ohpm |
