# MagSlime Arena

Godot 4.x 本地双人物理 brawler：平台跳跃 + 最近目标磁力 + 岩浆淘汰。

**游戏理念、Jam 主题 ANCHOR、完成度与扩展方向** → 见 [DESIGN.md](DESIGN.md)

## 快速开始

1. 用 **Godot 4.3+** 打开本目录（含 `project.godot`）
2. 主场景已设为 `scenes/main_arena.tscn`
3. 按 **F5** 运行

## 操作说明

| 玩家 | 角色 | 左 | 右 | 跳跃 | 磁力场（按住） |
|------|------|----|----|------|----------------|
| P1 | N-Pole（蓝） | A | D | W | **F** |
| P2 | S-Pole（红） | ← | → | ↑ | **Shift** |

- **按住 F/Shift → 磁力场**；**异极墙锚**（绿线）可抓握续跳，**同极**（红线）相斥
- 异极相吸、同极相斥（P1 固定 N、P2 固定 S）
- 5 秒后**场景上滚**、屏幕底部 **25% 固定岩浆**；掉队者被吞噬 → 1 秒后重开
- **冲过顶部虚线终点**即获胜
- 史莱姆会根据速度**形变**（VisualRoot squash & stretch）

---

## 参数在哪里改？（最重要）

所有「手感」分两类，改的地方不同：

### A. 玩家手感 → 改 SlimePlayer 节点

1. 打开场景 **`scenes/main_arena.tscn`**
2. 在左侧 Scene 树点击 **`Player1`** 或 **`Player2`**
3. 右侧 **Inspector（检查器）** 面板，找到脚本 **`slime_player.gd`** 下的导出变量：

| Inspector 里的名字 | 作用 | 当前默认值 |
|-------------------|------|-----------|
| Move Force | 左右移动推力 | 1200 |
| Max Horizontal Speed | 最高水平速度 | 525 |
| Jump Strength | 跳跃力度（**填正数**，越大跳越高） | 830 |
| **Magnet Strength** | **磁力强度（线性衰减，默认 600000）** | **600000** |
| Prefer Player Targets | 优先吸附对方玩家而非锚点 | true |
| Magnet Min Distance | 最近距离钳制 | 50 |
| Stretch Amount | 形变幅度 | 0.35 |
| Recovery Speed | 形变恢复速度 | 12 |

> 极性由 `player_id` 自动固定（P1=N，P2=S），无需手动改。

> 想改「全局默认值」：打开 **`scenes/slime_player.tscn`** → 选中根节点 `SlimePlayer` → 同样在 Inspector 里改。

### B. 物理属性（质量、重力、摩擦）→ 改 RigidBody2D 节点

仍在 **`Player1` / `Player2`** 或 **`slime_player.tscn`** 根节点上，Inspector 的 **RigidBody2D** 区块：

| 属性 | 当前值 | 作用 |
|------|--------|------|
| Mass | 1.0 | 质量，越大越难推动 |
| Gravity Scale | 2.5 | 下落速度 |
| Linear Damp | 0.5 | 滑行阻尼 |
| Physics Material Override → Friction | 0.15 | 地面摩擦 |
| Physics Material Override → Bounce | 0.35 | 弹跳 |

### C. 窗口/画面大小 → 改 project.godot

**Project → Project Settings → Display → Window**

| 属性 | 当前值 |
|------|--------|
| Viewport Width | 1080 |
| Viewport Height | 1920 |
| Mode | Maximized（启动时最大化窗口） |
| Stretch Mode | canvas_items |

### D. 竞技场与平台生成 → 改 `scripts/main_arena.gd`

**主文件**：`scripts/main_arena.gd` 里的 `_build_staircase()` 及相关函数。

#### 生成规则（当前版本）

| 层 | 规则 |
|----|------|
| 第 0 层 | 底部出生台，居中 `x=540`，宽度随机 3.1–3.9× |
| 第 1 层 | **随机左或右**，贴墙极端位置，**不悬在任一玩家头顶** |
| 第 2–13 层 | 左右交替（每 6 层偶尔居中桥接），宽度 1.35–2.85× 随机 |
| 层间距 | 垂直 108–128 px；拒绝上下层 X 重叠过多导致顶头 |

#### 常用微调常量（文件顶部 `const`）

| 常量 | 默认 | 作用 |
|------|------|------|
| `LEVEL_COUNT` | 14 | 平台总层数 |
| `MIN_VERT_STEP` / `MAX_VERT_STEP` | 108 / 128 | 层与层之间的垂直距离 |
| `MIN_PLATFORM_SCALE` / `MAX_PLATFORM_SCALE` | 1.35 / 2.85 | 平台宽度随机范围（×200px 基础宽） |
| `LEFT_LANE_X` / `RIGHT_LANE_X` | 330 / 750 | 常规左右车道中心 |
| `P1_SPAWN_X` / `P2_SPAWN_X` | 420 / 660 | 玩家出生 X（改 `_place_players()` 同步） |
| `SPAWN_HEAD_CLEARANCE` | 55 | 出生保护：前几层平台不能覆盖玩家头顶此半径 |
| `SPAWN_PROTECTED_LEVELS` | 2 | 出生保护生效的层数（第 1–2 层上方平台） |

#### 相关函数

- `_lane_x_for_side()` — 左右/居中车道 X 坐标；`level_index == 1` 时贴墙极端位置
- `_is_placement_valid()` — 层距、重叠、出生头顶保护
- `_pick_platform_placement()` — 随机尝试 10 次，选得分最高的合法位置
- `_place_players()` — 玩家出生坐标

#### 其他

- **岩浆 / 镜头**：`scripts/arena_camera.gd`
- **终点线高度**：`FINISH_LINE_ABOVE_TOP`（最高平台上方 100px）
- **单平台默认宽**：`scenes/platform.tscn` 基础 200px + `scripts/platform.gd`

---

## 磁力调参速查

| 现象 | 改什么 | 方向 |
|------|--------|------|
| 按住 F 感觉不到吸力 | Magnet Strength | 增大（如 600000） |
| 吸力太强，一按就飞 | Magnet Strength | 减小 |
| 贴太近时弹飞 | Magnet Min Distance | 增大（如 80） |
| 中距离拉力不够 | Magnet Strength | 增大 |

---

## 项目结构

```
MagSlimeArena/
├── project.godot
├── scenes/
│   ├── main_arena.tscn
│   ├── slime_player.tscn
│   ├── platform.tscn
│   └── magnetic_anchor.tscn
└── scripts/
    ├── main_arena.gd       ← 楼梯生成、HUD、玩家出生
    ├── arena_camera.gd     ← 跟随 + 自动上滚
    ├── finish_line.gd      ← 虚线终点
    ├── slime_player.gd
    ├── lava.gd             ← 屏幕岩浆区判定（ScrollHazard）
    ├── platform.gd
    ├── magnetic_anchor.gd
    ├── magnetic_utils.gd
    └── magnet_link_draw.gd
```

---

## 编辑器逐步设置指南

若你从零手动搭建，或需要调整手感，按以下步骤操作。

### 1. 创建项目与碰撞层

1. **Project → Project Settings → Layer Names → 2D Physics**
2. 设置：
   - Layer 1: `world`
   - Layer 2: `players`
   - Layer 3: `hazards`（预留，DeathZone 当前仅用 mask 检测玩家）

3. **Project → Project Settings → Display → Window**
   - Viewport: **1080 × 1920**（竖屏 silo，比初版大 1.5 倍）
   - Mode: Maximized
   - Stretch Mode: `canvas_items`

### 2. SlimePlayer 场景 (`slime_player.tscn`)

#### 节点树

```
SlimePlayer (RigidBody2D)
├── VisualRoot (Node2D)        ← 形变只缩放此节点
│   ├── MagnetRing (Polygon2D)
│   ├── Visual (Polygon2D)
│   └── PolarityLabel (Label)
├── CollisionShape2D           ← 不受 scale 影响
└── GroundRay (RayCast2D)
```

#### RigidBody2D 属性

| 属性 | 值 | 说明 |
|------|-----|------|
| Lock Rotation | ✅ | 防止无限翻滚 |
| Mass | 1.0 | 标准质量 |
| Gravity Scale | 2.5 | 略快下落，更有街机感 |
| Linear Damp | 0.5 | 减少无限滑行 |
| Contact Monitor | ✅ | 启用接触报告 |
| Max Contacts Reported | 4 | 备用接地检测 |
| Collision Layer | `players` (2) | 第 2 层 |
| Collision Mask | `world` + `players` (3) | 与墙壁、地面及对方史莱姆碰撞 |

#### Physics Material（新建 SubResource）

- **Friction**: 0.1（低摩擦）
- **Bounce**: 0.55（对撞时明显弹开）

拖到 RigidBody2D 的 **Physics Material Override**。

#### GroundRay (RayCast2D)

- **Target Position**: `(0, 42)` — 略长于碰撞半径，检测脚下地面
- **Collision Mask**: 仅勾选 `world`
- **Enabled**: ✅

#### 脚本导出变量（Inspector）

| 变量 | P1 建议 | P2 建议 |
|------|---------|---------|
| player_id | 1 | 2 |
| move_force | 1200 | 1200 |
| jump_strength | 830 | 830 |
| magnet_strength | 600000 | 600000 | 600000 |
| magnet_min_distance | 50 | 50 |

### 3. Platform 场景 (`platform.tscn`)

- 根节点 **StaticBody2D**，`collision_layer = world`
- 脚本 `platform.gd` 在 `_ready()` 中 `scale.x = randf_range(0.5, 2.0)`
- 缩放根节点 → 碰撞与 ColorRect 视觉同步

**摆放**：左右车道交替（贴墙宽平台）+ 偶尔居中桥接；层距 108–128 px，重叠检测防顶头；出生台 3.6× 全宽。

### 4. MagneticAnchor 场景 (`magnetic_anchor.tscn`)

- **Node2D**（无碰撞），玩家可与之重合；贴左/右墙内表面
- `@export is_north_pole` — N 极（蓝）/ S 极（红）
- `@export wall_side` — `-1` 左墙，`1` 右墙

### 5. 岩浆与终点 (`main_arena.tscn`)

| 组件 | 说明 |
|------|------|
| HUD/LavaOverlay | 屏幕底部 25% 固定岩浆视觉 |
| ScrollHazard | `lava.gd`：上滚开始后检测玩家是否进入岩浆区 |
| ArenaCamera | 5 秒后自动上滚 25 px/s，跟随领先者 |
| FinishLine | 顶部虚线，先冲过者胜 |

### 6. MainArena 场景 (`main_arena.tscn`)

#### 节点树

```
MainArena (Node2D) + main_arena.gd
├── Background (2700 高)
├── LeftWall / RightWall      ← collision_layer=1, 高 2700
├── Platforms/                ← 脚本生成 platform.tscn
├── Anchors/                  ← 脚本生成 magnetic_anchor.tscn
├── FinishLine                ← finish_line.gd 虚线终点
├── Player1 / Player2
├── ScrollHazard              ← lava.gd 岩浆判定
├── ArenaCamera (Camera2D)    ← arena_camera.gd 上滚 + 跟随
└── HUD (LavaOverlay + LavaStatus + ControlsHint)
```

#### 玩家出生点

- 由 `main_arena.gd` 放置：底部平台上方，约 `(440, 2432)` / `(640, 2432)`

### 7. 设为主场景

**Project → Project Settings → Application → Run → Main Scene**  
设为 `res://scenes/main_arena.tscn`。

---

## 手感调参参考

| 参数 | 默认 | 在哪里改 | 调大效果 | 调小效果 |
|------|------|----------|----------|----------|
| move_force | 1200 | Player → Inspector → Move Force | 加速更快 | 移动 sluggish |
| jump_strength | 830 | Player → Inspector → Jump Strength | 跳更高 | 跳更低 |
| magnet_strength | 600000 | Player → Magnet Strength | 磁力更强 | 磁力微弱 |
| magnet_min_distance | 50 | Player → Inspector → Magnet Min Distance | 贴身力更小 | 贴身力更大 |
| gravity_scale | 2.5 | Player → Inspector → RigidBody2D → Gravity Scale | 更快落底 | 更漂浮 |
| max_horizontal_speed | 525 | Player → Inspector → Max Horizontal Speed | 允许更高速 | 上限更低 |

---

## 核心机制说明

### 磁力公式（最近目标 + 线性衰减）

```
closest = magnetic_entities 组中最近目标（可优先玩家）
force = magnet_strength / max(distance, min_distance)   ← 线性衰减，垂直方向也有效
direction = normalize(target_pos - self_pos)           ← 含 X 和 Y 分量，非仅水平
interaction = polarity_self × polarity_target
apply_central_force(-direction × force × interaction)
```

**为何以前上下分层感觉没吸力？**
1. 旧版用平方反比 `1/distance²`，距离稍远时力极小，垂直分量被重力（`gravity_scale=2.5`）淹没
2. 水平方向没有「重力」竞争，所以侧向更明显
3. 锚点有时比对方玩家更近，磁力会被吸向锚点而非上下方的对手

- 组 `magnetic_entities` 包含：**两名玩家** + **所有 MagneticAnchor**
- 只对**最近的一个**目标施力

### 形变 (Squash & Stretch)

在 `_process` 中根据 `linear_velocity` 缩放 **VisualRoot**（不影响 CollisionShape2D）：
- 垂直速度大 → Y 拉长、X 压扁
- 水平速度大 → X 拉长、Y 压扁
- `lerp` 平滑恢复到 `(1, 1)`

### 磁力场开关

按住 F（P1）或 Shift（P2）→ 寻找最近目标并施力 + 外圈亮起 + **波浪连线**（Line2D 连接玩家与目标）。

**Magnet Link** 参数（Player → Inspector → Magnet Link）：`Width` 线宽、`Amplitude` 波浪幅度、`Wave Speed` 动画速度。

---

## 常见问题

**Q: 玩家穿过平台？**  
检查 Platform / 墙的 Collision Layer 是否为 `world`，玩家 Mask 是否勾选 `world`。

**Q: 岩浆不触发？**  
确认 Lava `monitoring = true`，Mask 勾选 `players`。

**Q: 磁力只吸玩家、不吸锚点？**  
确认 MagneticAnchor 在 `_ready` 中加入了 `magnetic_entities` 组。

**Q: 无法跳跃？**  
检查 GroundRay 的 `collision_mask` 仅含 `world`，且 `target_position.y` 足够长。

**Q: 磁力太强/太弱？**  
选中 `Player1` → Inspector → **Magnet Strength**（按住 F 才有力，先确认按键按住）。

**Q: 画面太小？**  
Project Settings → Display → Window → 增大 Viewport Width/Height，或确认 Mode 为 Maximized。

---

## Step 3：向上逃命

| 机制 | 说明 |
|------|------|
| 场景高度 | 2700 px 竖向竞技场，视口 1080×1920 |
| 平台 | 11 层（原 14 略减），左右交替，层距 108–128 px |
| 锚点 | 5–8 个，**散布**于层间（原规则）；N/S **各半** 随机 |
| 续跳 | 空中进入**异极**锚点范围 → 该锚点本轮 **+1 跳**（落地重置） |
| 岩浆 | 屏幕底部 **25% 固定**；5 秒后场景上滚 25 px/s |
| 淘汰 | 被屏幕底部岩浆追上者输 |
| 胜利 | 冲过顶部**虚线终点线** |
| 相机 | 默认固定；领先者跳出画面顶部且终点不可见时**上移一级**；5 秒后岩浆持续上滚 |

**攀岩要点**：平台作驿站 → 跳向本侧墙锚（蓝找左 S，红找右 N）→ 按住磁力抓握 → W/↑ 续跳往下一平台。可把对手打落或抢公共路线。

**Latch 参数**：`slime_player.gd` → `latch_distance`、`latch_jump_bonus`、`latch_snap_speed`

---

## 下一步 (Step 4 建议)

- 粒子与音效
- 屏幕震动
- 回合计分与胜负 UI
- 极性反转技能
