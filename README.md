# PoseAI · 智能体态评估系统（HarmonyOS）

基于 **MediaPipe 姿态识别 + GLM-4 大模型**的智能体态评估系统：手机拍摄正面 / 侧面 / 背面三视图照片，云端完成体态指标分析，并生成 AI 深度解读与运动处方。

> ⚠️ 本系统输出仅供体态自测参考，不构成医疗诊断建议。如有明显不适，请前往医院骨科或康复科就诊。

## ✨ 功能特性

- **三视图采集**：正面 / 侧面 / 背面三张照片联合分析，拍照时有人体完整性与质量校验
- **6 项体态指标**：高低肩、骨盆侧倾、骨盆前倾、头前伸、圆肩、脊柱侧弯趋势，每项含严重程度分级（轻度 / 中度 / 重度）与置信度
- **AI 深度报告**：GLM-4 生成个性化建议、深度解读、运动处方；AI 不可用时自动降级为内置规则兜底内容，服务永不空转
- **可视化呈现**：六维雷达图、总体评分、健康风险预警
- **历史与趋势**：本地保存最近 20 次评估（Preferences），评分趋势折线图与统计
- **鸿蒙特性**：分布式流转（评估结果跨设备查看）、桌面卡片（PostureFormAbility）

## 🏗️ 系统架构

```
HarmonyOS App (ArkTS)                Flask 后端
┌──────────────────┐   3×JPEG    ┌─────────────────────────────┐
│ 拍照/压缩/校验     │ ─────────→ │ /upload 限流 + 格式校验       │
│ Index/ResultPage  │             │   ├─ MediaPipe 关键点提取(6点) │
│ History/卡片      │             │   ├─ 几何规则 → 6 指标分级     │
│                  │ ←────────── │   ├─ 总分计算 + 风险规则表     │
└──────────────────┘  JSON 报告   │   └─ GLM-4 生成 AI 内容(带兜底) │
                                  └─────────────────────────────┘
```

分析管道三张照片并行执行（线程池），MediaPipe 仅使用 6 个关键点（双耳 / 双肩 / 双髋），通过比例阈值分级严重度。

## 🧰 技术栈

| 端 | 技术 |
|---|---|
| App | HarmonyOS ArkTS（API 12）、ArkUI、Preferences、分布式数据服务 |
| 后端 | Python / Flask / MediaPipe Tasks Vision / OpenCV |
| AI | 智谱 GLM-4-Flash（`zhipuai` SDK），失败自动兜底 |
| 测试 | Flask test_client 契约测试（离线可跑，见下） |

## 📁 目录结构

```
backend/                     Flask 后端
├── app.py                   路由 + 分析编排 + AI 生成 + 兜底
├── pose_metrics.py          MediaPipe 关键点提取与 6 项指标计算
├── models/                  pose_landmarker_full.task（已内置）
├── test_upload_fields.py    响应契约测试（含限流器与 severity 值域回归）
├── requirements.txt
└── .env.example             密钥模板

harmonyos/
├── harmonyos/               HarmonyOS 工程（DevEco Studio 打开此目录）
│   └── entry/src/main/ets/
│       ├── pages/           Index / ResultPage / HistoryPage / PostureCardPage
│       ├── service/         HttpService（上传）/ DistributedService（分布式）
│       ├── model/           AnalysisResult 等数据模型
│       ├── util/            PreferencesUtil（历史记录）
│       └── common/          Constants（服务器地址等）
└── *.js / *.bat             hdc 部署、模拟器启动等开发辅助脚本

docs/test_report.md          测试报告
```

## 🚀 快速开始

### 1. 启动后端

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows（Linux/macOS: source .venv/bin/activate）
pip install -r requirements.txt

copy .env.example .env          # 可选：填入 ZHIPU_API_KEY（Linux/macOS: cp）
python app.py                   # 监听 0.0.0.0:5000
```

- 不配置 `ZHIPU_API_KEY` 也能完整跑通：AI 内容自动使用内置兜底
- 模型文件已随仓库内置，无需额外下载

### 2. 运行 App

1. 用 DevEco Studio 打开 `harmonyos/harmonyos/`
2. 修改 `entry/src/main/ets/common/Constants.ets` 中的 `SERVER_URL` 为你后端机器的局域网 IP
3. 连接真机或启动模拟器，运行 Entry

## 🧪 测试

```bash
cd backend
.venv\Scripts\python.exe test_upload_fields.py
```

离线确定性运行（1×1 合成图走"未检出人体"路径），覆盖：6 项指标完整性、雷达图契约、AI 模板回声拒绝、限流器回归、severity 值域。

## 📡 API

| 端点 | 方法 | 说明 |
|---|---|---|
| `/health` | GET | 健康检查 |
| `/upload` | POST | `multipart/form-data`：`front_image` / `side_image` / `back_image`（至少一张），返回 6 项指标 + 总分 + AI 报告 + 雷达图数据 + 健康风险 |

## 📄 License

[MIT](LICENSE) © 2026 AzureDestiny346
