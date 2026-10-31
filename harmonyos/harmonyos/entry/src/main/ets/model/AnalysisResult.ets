export class MetricResult {
  value: string = '';
  confidence: number = 0;
}

export class ExerciseItem {
  name: string = '';
  duration: string = '';
  target: string = '';
  tip: string = '';
}

export class HealthRisk {
  metric: string = '';
  severity: string = '';
  risk: string = '';
  desc: string = '';
}

export class RadarDataItem {
  metric: string = '';
  score: number = 0;
  severity: string = '';
}

export class AnalysisResult {
  high_low_shoulder: MetricResult = new MetricResult();
  pelvic_lateral_tilt: MetricResult = new MetricResult();
  pelvic_anterior_tilt: MetricResult = new MetricResult();
  forward_head: MetricResult = new MetricResult();
  round_shoulder: MetricResult = new MetricResult();
  spinal_asymmetry: MetricResult = new MetricResult();
  elbow_asymmetry: MetricResult = new MetricResult();
  leg_length_diff: MetricResult = new MetricResult();
  knee_hyperextension: MetricResult = new MetricResult();
  overall_score: string = '';
  advice: string[] = [];
  deep_analysis: string = '';
  exercise_prescription: ExerciseItem[] = [];
  health_risks: HealthRisk[] = [];
  radar_data: RadarDataItem[] = [];

  /**
   * 根据 key 获取对应指标结果（统一入口，消除页面级 if-else 重复）
   */
  static getMetricResult(result: AnalysisResult, key: string): MetricResult {
    const resultObj: Record<string, MetricResult> = {
      'high_low_shoulder': result.high_low_shoulder,
      'pelvic_lateral_tilt': result.pelvic_lateral_tilt,
      'pelvic_anterior_tilt': result.pelvic_anterior_tilt,
      'forward_head': result.forward_head,
      'round_shoulder': result.round_shoulder,
      'spinal_asymmetry': result.spinal_asymmetry,
      'elbow_asymmetry': result.elbow_asymmetry,
      'leg_length_diff': result.leg_length_diff,
      'knee_hyperextension': result.knee_hyperextension,
    };
    return resultObj[key] ?? new MetricResult();
  }

  /**
   * 分数→等级映射（90/75/60 阈值）
   */
  static getScoreLevel(score: string): string {
    const n = parseInt(score);
    if (isNaN(n)) return '未知';
    if (n >= 90) return '优秀';
    if (n >= 75) return '良好';
    if (n >= 60) return '一般';
    return '需改善';
  }

  /**
   * 分数→颜色映射（直接阈值判断，避免双重查找）
   */
  static getScoreColor(score: string): string {
    const n = parseInt(score);
    if (isNaN(n)) return '#94A3B8';
    if (n >= 90) return '#059669';
    if (n >= 75) return '#CA8A04';
    if (n >= 60) return '#EA580C';
    return '#DC2626';
  }
}

export class UploadResponse {
  message: string = '';
  analysis: AnalysisResult = new AnalysisResult();
}

export class HistoryItem {
  id: number = 0;
  date: string = '';
  score: string = '';
  result: AnalysisResult = new AnalysisResult();
}

export class MetricDef {
  label: string = '';
  key: string = '';
  view: string = '';
}

export const METRIC_DEFS: MetricDef[] = [
  { label: '高低肩', key: 'high_low_shoulder', view: '正面' } as MetricDef,
  { label: '骨盆侧倾', key: 'pelvic_lateral_tilt', view: '正面' } as MetricDef,
  { label: '骨盆前倾', key: 'pelvic_anterior_tilt', view: '侧面' } as MetricDef,
  { label: '头前伸', key: 'forward_head', view: '侧面' } as MetricDef,
  { label: '圆肩', key: 'round_shoulder', view: '侧面' } as MetricDef,
  { label: '脊柱侧弯趋势', key: 'spinal_asymmetry', view: '背面' } as MetricDef,
  { label: '肘关节对称', key: 'elbow_asymmetry', view: '正面' } as MetricDef,
  { label: '长短腿', key: 'leg_length_diff', view: '正面' } as MetricDef,
  { label: '膝盖超伸', key: 'knee_hyperextension', view: '侧面' } as MetricDef,
];
