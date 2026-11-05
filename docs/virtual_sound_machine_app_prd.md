# 纯软件拟物 S670 台式助眠音箱设计规范 (PRD - Dual-Theme & Haptic Final Edition)
**产品代号：S670 Virtual / SleepDeck Console**
*“日白夜黑双主题无缝演进，大尺寸彩色微动琴键，系统级线性马达拟物触觉体系”*

---

## 1. 双主题自适应系统 (Dual-Theme System)

为了兼顾“白天床头美学”与“深夜全黑入睡”，产品确立为双主题形态，支持用户手动一键切换或跟随环境光传感器（ALS）/系统昼夜自动流转：

```mermaid
graph LR
    subgraph 昼夜双主题形态
    A[S670 虚拟台式音箱] --> B[日间纯白主题 (Day White)]
    A --> C[夜间钛黑主题 (Night Titanium / OLED)]
    
    B --> B1[经典哑光暖白机身 - 致敬 Braun / MUJI 极简]
    B --> B2[8 个大尺寸复古彩色琴键 - 优雅微撞色美学]
    B --> B3[下沉纯黑微孔时钟屏 - 强对比高辨识]

    C --> C1[深色钛金属机身 + 边缘无极泛黑]
    C --> C2[8 个深色冷光大琴键 - 柔和自发光微光]
    C --> C3[OLED 纯黑模式 - 屏幕背光彻底熄灭, 保护褪黑素]
    end
```

---

## 2. 拟物线性马达触觉体系 (Haptic Engine Architecture)

摒弃传统 App 冰冷平面的玻璃感，深度结合 iOS Taptic Engine 与 Android 线性振动马达（Web 端已全面接入 `navigator.vibrate`）：

| 交互行为 | 触觉振动模式 (Haptic Pattern) | 原理与体验目标 | 对应 API 映射 (Native / Web) |
| :--- | :--- | :--- | :--- |
| **8 颗彩色大按键点击** | **单次清晰下沉 (Click - 18ms)** | 模拟实体微动机械开关下压并触发底部的清脆段落感 | iOS: `UIImpactFeedbackGenerator(.medium)`<br>Web: `navigator.vibrate(18)` |
| **主音量旋钮旋转** | **连续高频微齿轮感 (Tick - 8ms)** | 旋钮每旋转 15° 触发一次微弱跳格，模拟精密滚珠阻尼阻力 | iOS: `UISelectionFeedbackGenerator()`<br>Web: `navigator.vibrate(8)` |
| **双主题 / 夜灯开关切换** | **两段式卡扣震动 (Toggle - 12ms + 16ms)** | 模拟拨动大型机械开关时金属回弹与锁定感觉 | iOS: `UIImpactFeedbackGenerator(.rigid)`<br>Web: `navigator.vibrate([12, 30, 16])` |

---

## 3. 横屏 8 键多选叠加声学系统 (Multi-Stacking Engine)

* **8 种经典声音大按键矩阵**：白噪音（雾白）、风扇声（薄荷青）、雨声（雨蓝）、海浪（深青）、雷暴（靛紫）、鸟鸣（苔绿）、篝火（暖橙）、溪流（冰蓝）。
* **自由叠加混音（Multi-Stacking）**：允许用户任意点亮 1 至 8 种声音并行播放，系统实时平衡各声道增益（Headroom Management），杜绝破音或失真。
* **纯粹助眠环境**：无任何闹铃打扰，仅保留 15m / 30m / 60m / 持续（∞）纯净睡眠倒计时与 660nm 护眼红光夜灯。
