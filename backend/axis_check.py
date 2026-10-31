"""模块1配套实验：验证 MediaPipe 世界坐标的轴向约定。

用法:
    .venv\\Scripts\\python.exe axis_check.py <全身站直照路径>

原理:
    站直的人，鼻尖到脚跟的跨度集中在竖直轴上，跨度最大的轴即竖直轴。
    局限: 该探针测的是「画面中的身体长轴」，仅当相机接近水平、人物直立
    时才等于重力竖直轴；大幅侧倾或躺卧的照片结论不可信。

世界坐标约定（MediaPipe Pose）: 原点在双髋中点，x 右、y 下、z 朝相机。
生产代码 pose_metrics.py 的轴向用法:
    - _pelvic_anterior_tilt_level: 竖直分量取 torso[1]（y 轴）
    - _round_shoulder_ratio_world: 水平面跨度 hypot(torso[0], torso[2])
本脚本检测出竖直轴后与上述约定比对，输出 PASS/FAIL。
"""

import sys

from pose_metrics import extract_landmarks

NOSE, LEFT_HEEL = 0, 29  # BlazePose 33 点索引
EXPECTED_VERTICAL = "y"


def main(image_path: str) -> int:
    landmarks, world = extract_landmarks(image_path)
    if world is None:
        print("未检出人体或未返回世界坐标：请换一张清晰的站直全身照")
        return 1

    nose, heel = world[NOSE], world[LEFT_HEEL]
    span = {
        "x": abs(nose.x - heel.x),
        "y": abs(nose.y - heel.y),
        "z": abs(nose.z - heel.z),
    }
    vertical = max(span, key=span.get)
    others = [v for k, v in span.items() if k != vertical]

    print(f"鼻尖世界坐标:   x={nose.x:+.3f} y={nose.y:+.3f} z={nose.z:+.3f} (米)")
    print(f"左脚跟世界坐标: x={heel.x:+.3f} y={heel.y:+.3f} z={heel.z:+.3f} (米)")
    print(f"头-跟跨度:      x={span['x']:.3f} y={span['y']:.3f} z={span['z']:.3f}")
    print(f"结论: 竖直轴 = {vertical} 轴")

    if span[vertical] <= 2 * max(others):
        print("自检失败: 竖直跨度不够突出（照片不够直立或不是全身照），结论不可信")
        return 1

    if vertical == EXPECTED_VERTICAL:
        print(f"自检通过: 竖直轴 = {EXPECTED_VERTICAL}，与 pose_metrics.py 的 torso[1] 一致")
        return 0
    print(
        f"自检失败: 检测出竖直轴 = {vertical}，但生产代码按 {EXPECTED_VERTICAL} 轴"
        f"计算骨盆前倾 —— 请核对 _pelvic_anterior_tilt_level"
    )
    return 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
