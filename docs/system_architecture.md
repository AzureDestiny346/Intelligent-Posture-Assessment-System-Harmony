# 智能体态评估系统 - 系统架构设计文档

## 目录
1. [系统概述](#系统概述)
2. [整体架构](#整体架构)
3. [后端架构](#后端架构)
4. [前端架构](#前端架构)
5. [数据流程](#数据流程)
6. [技术选型](#技术选型)
7. [安全设计](#安全设计)
8. [性能优化](#性能优化)

---

## 1. 系统概述

### 1.1 系统定位

智能体态评估系统是一款基于AI视觉技术的健康管理应用，通过分析用户上传的正面/侧面/背面三张照片，自动生成体态评分报告和个性化改善建议。

### 1.2 核心功能

- **体态检测**：基于MediaPipe提取关键点，计算9项体态指标
- **智能评分**：综合评估体态健康状况，生成0-100分评分
- **AI建议**：利用GLM-4大模型生成个性化改善建议和运动处方
- **数据可视化**：雷达图展示多维度体态指标
- **健康风险预警**：识别潜在健康风险并提供干预建议
- **历史追踪**（移动端）：记录体态变化趋势

### 1.3 系统特点

| 特点 | 说明 |
|------|------|
| **混合AI架构** | 几何算法+大模型，确定性评估+生成性建议 |
| **高性能** | 并行处理三张照片，总耗时≈最慢一张 |
| **高可用** | AI三层容错机制，系统可用性100% |
| **跨平台** | Web端+HarmonyOS移动端 |
| **零成本** | 不收费、无广告、本地部署 |

---

## 2. 整体架构

### 2.1 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                         用户层                               │
│  ┌──────────────┐              ┌──────────────┐            │
│  │  Web浏览器    │              │ HarmonyOS App │            │
│  │  (HTML/JS)   │              │   (ArkTS)     │            │
│  └───────┬──────┘              └───────┬───────┘            │
└──────────┼─────────────────────────────┼────────────────────┘
           │                             │
           │        HTTP/HTTPS           │
           │                             │
┌──────────┼─────────────────────────────┼────────────────────┐
│          │        应用层                │                     │
│  ┌───────▼─────────┐         ┌────────▼──────────┐         │
│  │  Flask Web Server│         │  HttpService.ets   │         │
│  │  (app.py)        │         │  (网络请求封装)    │         │
│  └───────┬─────────┘         └───────────────────┘         │
│          │                                                   │
│  ┌───────▼────────────────────────────────┐                │
│  │         业务逻辑层                       │                │
│  │  ┌────────────┐    ┌─────────────┐   │                │
│  │  │限流器       │    │文件管理     │   │                │
│  │  │RateLimiter │    │save/cleanup │   │                │
│  │  └────────────┘    └─────────────┘   │                │
│  │  ┌────────────────────────────────┐  │                │
│  │  │  体态分析协调器 run_analysis    │  │                │
│  │  │  (并行调度、结果聚合)           │  │                │
│  │  └────────────────────────────────┘  │                │
│  └───────────────────────────────────────┘                │
└───────────────────────────────────────────────────────────┘
           │                             │
┌──────────┼─────────────────────────────┼────────────────────┐
│          │        AI处理层              │                     │
│  ┌───────▼───────────┐       ┌────────▼──────────┐         │
│  │ MediaPipe姿态检测  │       │  GLM-4大模型       │         │
│  │ (pose_metrics.py) │       │  (建议生成)        │         │
│  │                   │       │                    │         │
│  │ ┌───────────────┐ │       │ ┌────────────────┐│         │
│  │ │关键点提取     │ │       │ │内容生成        ││         │
│  │ │13个关键点     │ │       │ │advice/deep/ex  ││         │
│  │ └───────────────┘ │       │ └────────────────┘│         │
│  │ ┌───────────────┐ │       │ ┌────────────────┐│         │
│  │ │体态指标计算   │ │       │ │正则提取        ││         │
│  │ │9项指标        │ │       │ │容错解析        ││         │
│  │ └───────────────┘ │       │ └────────────────┘│         │
│  │ ┌───────────────┐ │       │ ┌────────────────┐│         │
│  │ │评分体系       │ │       │ │兜底内容        ││         │
│  │ │综合打分       │ │       │ │硬编码建议      ││         │
│  │ └───────────────┘ │       │ └────────────────┘│         │
│  └───────────────────┘       └────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
           │                             │
┌──────────┼─────────────────────────────┼────────────────────┐
│          │        数据层                │                     │
│  ┌───────▼─────────┐         ┌────────▼──────────┐         │
│  │ 临时文件存储     │         │  本地KV存储        │         │
│  │ uploads/         │         │  (HarmonyOS)       │         │
│  │ (24h自动清理)    │         │  PreferencesUtil   │         │
│  └─────────────────┘         └───────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 技术架构分层

| 层级 | 技术栈 | 职责 |
|------|--------|------|
| **用户界面层** | HTML/CSS/JS, ArkTS | 用户交互、数据展示 |
| **应用服务层** | Flask, HarmonyOS | HTTP服务、请求路由 |
| **业务逻辑层** | Python | 限流、文件管理、任务调度 |
| **AI处理层** | MediaPipe, GLM-4 | 姿态检测、内容生成 |
| **数据存储层** | 文件系统, Preferences | 临时存储、历史记录 |

---

## 3. 后端架构

### 3.1 Flask应用结构

```python
backend/
├── app.py                    # Flask主应用
├── pose_metrics.py           # 体态指标计算模块
├── axis_check.py             # 坐标系诊断工具
├── index.html                # Web前端页面
├── .env                      # 环境变量（API密钥）
├── uploads/                  # 临时文件目录
└── models/                   # MediaPipe模型文件
    └── pose_landmarker_full.task
```

### 3.2 核心模块设计

#### 3.2.1 应用层 (app.py)

**职责**：HTTP服务、路由、限流、文件管理、任务协调

**关键组件**：

```python
# 1. Flask应用实例
app = Flask(__name__)

# 2. 限流器（滑动窗口算法）
class RateLimiter:
    - 10次/分钟/IP
    - 滑动窗口记录
    - 线程安全（Lock）

# 3. 线程池（并行处理）
_executor = ThreadPoolExecutor(max_workers=3)

# 4. 文件管理
- save_upload()      # 保存上传文件（UUID命名）
- cleanup_files()    # 清理临时文件
- cleanup_old_files() # 清理24h过期文件

# 5. AI客户端管理
get_zhipu_client()  # 单例模式，懒加载
```

**路由设计**：

| 路由 | 方法 | 功能 |
|------|------|------|
| `/` | GET | 返回Web前端页面 |
| `/health` | GET | 健康检查端点 |
| `/upload` | POST | 体态分析主接口 |

#### 3.2.2 分析协调层 (run_analysis)

**并行处理流程**：

```python
def run_analysis(front_path, side_path, back_path):
    # 1. 初始化指标字典
    metrics = {key: {"value": "unknown", "confidence": 0} 
               for key in METRIC_LABELS}
    
    # 2. 构建并行任务
    tasks = {
        "front": (analyze_front, front_path),
        "side": (analyze_side, side_path),
        "back": (analyze_back, back_path),
    }
    
    # 3. 提交到线程池
    futures = {
        _executor.submit(func, path): key
        for key, (func, path) in tasks.items()
    }
    
    # 4. 收集结果（as_completed迭代器）
    for future in as_completed(futures):
        result = future.result()
        metrics.update(result)
    
    # 5. 计算综合评分
    overall = compute_overall_score(metrics)
    
    # 6. AI生成建议
    ai_content = generate_full_ai_content(metrics)
    
    # 7. 构建雷达图和风险数据
    metrics["radar_data"] = _build_radar_data(metrics)
    metrics["health_risks"] = _build_health_risks(metrics)
    
    return metrics
```

**性能优势**：
- 并行度：3（三张照片同时处理）
- 总耗时 ≈ max(front_time, side_time, back_time)
- 实测提升：60-70%

#### 3.2.3 AI内容生成层

**三层容错机制**：

```python
def generate_full_ai_content(metrics):
    try:
        # 第一层：正常调用GLM-4 API（30秒超时）
        response = client.chat.completions.create(
            model="glm-4-flash",
            extra_body={"temperature": 0.7, "max_tokens": 800},
            messages=[{"role": "user", "content": prompt}]
        )
        raw = response.choices[0].message.content
        
        # 第二层：正则提取JSON结构
        parsed = _parse_full_content_json(raw)
        if parsed:
            return parsed
        
    except Exception as e:
        logger.error("AI完整内容生成失败: %s", str(e))
    
    # 第三层：硬编码兜底内容
    return _fallback_full_content(metrics)
```

**Prompt设计**：

```python
prompt = f"""
你是一位专业的体态评估师和运动康复专家。根据以下体态检测结果，
生成一个JSON对象，包含三个字段，不要markdown，不要其他文字：

检测结果：{summary}

请返回如下JSON格式：
{{
  "advice": ["建议1(20字以内)", "建议2", "建议3"],
  "deep_analysis": "对整体体态状况的专业解读，包括问题成因和可能的影响，100-200字",
  "exercise_prescription": [
    {{"name": "动作名称", "duration": "时长/次数", "target": "目标肌群", "tip": "动作要领"}}
  ]
}}
"""
```

#### 3.2.4 限流器设计

**滑动窗口算法**：

```python
class RateLimiter:
    def __init__(self, max_requests=10, window_seconds=60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._requests: dict[str, list[float]] = defaultdict(list)
        self._lock = Lock()
    
    def is_allowed(self, client_ip: str) -> bool:
        now = time.time()
        with self._lock:
            # 只保留窗口内的请求记录
            recent = [t for t in self._requests[client_ip] 
                     if now - t < self.window_seconds]
            
            if len(recent) >= self.max_requests:
                return False
            
            recent.append(now)
            self._requests[client_ip] = recent
            return True
```

**特点**：
- 精确限流（非令牌桶近似）
- 线程安全（Lock保护）
- 内存高效（只保留窗口内记录）

---

## 4. 前端架构

### 4.1 HarmonyOS应用结构

```
entry/src/main/ets/
├── pages/
│   ├── Index.ets              # 首页：三视图照片采集
│   ├── ResultPage.ets         # 分析报告页
│   └── HistoryPage.ets        # 历史记录页
├── service/
│   └── HttpService.ets        # HTTP请求封装
├── model/
│   └── AnalysisResult.ets     # 数据模型定义
├── common/
│   └── Constants.ets          # 全局常量
└── util/
    └── PreferencesUtil.ets    # 本地KV存储封装
```

### 4.2 页面架构

#### 4.2.1 首页 (Index.ets)

**功能**：三视图照片采集、上传

**组件结构**：
```
Index
├── Header（标题栏）
├── PhotoGrid（三视图照片区）
│   ├── PhotoCard（正面）
│   ├── PhotoCard（侧面）
│   └── PhotoCard（背面）
├── ActionButtons（操作按钮）
│   ├── 分析按钮
│   └── 历史记录按钮
└── LoadingOverlay（加载遮罩）
```

**照片采集方式**：
1. 相机拍照
2. 相册选择
3. 文件选择器

#### 4.2.2 结果页 (ResultPage.ets)

**功能**：体态报告展示、数据可视化

**组件结构**：
```
ResultPage
├── ScoreSection（评分区）
│   └── CircularProgress（环形进度条）
├── RadarChart（雷达图）
│   └── 6维指标可视化
├── MetricsDetail（指标详情）
│   └── MetricCard × 6
├── AdviceSection（改善建议）
│   └── AdviceCard × 3
├── ExerciseSection（运动处方）
│   └── ExerciseCard × N
└── RiskSection（健康风险）
    └── RiskCard × N
```

### 4.3 服务层架构

#### 4.3.1 HttpService.ets

**职责**：HTTP请求封装、错误处理、重试逻辑

```typescript
export class HttpService {
  // 上传照片进行分析
  static async uploadImages(
    frontUri, sideUri, backUri
  ): Promise<AnalysisResult>
  
  // 健康检查
  static async healthCheck(): Promise<boolean>
}
```

**重试策略**：
- 最大重试：3次
- 重试间隔：1秒、2秒、4秒（指数退避）

---

## 5. 数据流程

### 5.1 完整分析流程

```
用户上传 → 限流检查 → 文件保存 → 并行分析（3张） 
→ 结果聚合 → 综合评分 → AI建议生成 → 构建响应 
→ 清理文件 → 返回结果 → 保存历史
```

### 5.2 数据模型

```typescript
interface AnalysisResult {
  // 9项体态指标
  high_low_shoulder: MetricResult
  pelvic_lateral_tilt: MetricResult
  forward_head: MetricResult
  round_shoulder: MetricResult
  pelvic_anterior_tilt: MetricResult
  spinal_asymmetry: MetricResult
  elbow_asymmetry: MetricResult
  leg_length_diff: MetricResult
  knee_hyperextension: MetricResult

  // 综合评分
  overall_score: string
  
  // AI生成内容
  advice: string[]
  deep_analysis: string
  exercise_prescription: ExerciseItem[]
  
  // 可视化数据
  radar_data: RadarDataItem[]
  health_risks: HealthRisk[]
}
```

---

## 6. 技术选型

| 技术 | 版本 | 选型理由 |
|------|------|----------|
| **Python** | 3.10+ | AI库支持好 |
| **Flask** | 3.0+ | 轻量级Web框架 |
| **MediaPipe** | 0.10+ | 姿态检测精度高 |
| **GLM-4-Flash** | 最新 | 中文优秀、响应快 |
| **HarmonyOS** | 5.0 | 国产生态完善 |
| **ArkTS** | API 12 | 官方开发语言 |

---

## 7. 安全设计

### 7.1 请求限流

- 限制：10次/分钟/IP
- 防御：暴力请求、DDoS

### 7.2 文件安全

- 格式校验：仅允许图片格式
- UUID命名：避免冲突
- 自动清理：24小时后删除

### 7.3 API密钥保护

```python
# .env 文件（不提交到Git）
ZHIPU_API_KEY=你的密钥
```

---

## 8. 性能优化

### 8.1 并行处理

三张照片并行分析，性能提升60-70%

### 8.2 资源复用

- AI客户端单例
- 线程池单例
- 关键点精简（6个vs33个）

### 8.3 文件清理

- 24小时自动清理
- 分析完成立即删除
- 避免磁盘耗尽

---

**文档版本**: v1.0  
**最后更新**: 2026年9月  
**作者**: 智能体态评估系统开发团队
