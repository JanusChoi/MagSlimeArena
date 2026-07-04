# 玩法实验：单次冲量锚点磁力

当前分支：`experiment/anchor-impulse-one-shot`  
基线版本：`master`（按住 F/Shift 持续磁力 + 锚点续跳）

## 本分支玩法

- **按一次** F（蓝）/ Shift（红）→ 对**范围内最近锚点**发射
  - **异极**（蓝→S 红）：飞向锚点并带向上分量，速度足以飞过锚点
  - **同极**：从锚点弹开
- **玩家之间无磁力**，RigidBody 碰撞保留
- 配合 `anchor_only_climb_test` 可测纯锚点攀爬
- **左 S 链（蓝 N）/ 右 N 链（红 S）**：各有一条保底可通关路线，锚点间距按冲量射程校验

## Inspector（MainArena 节点）

| 项 | 说明 |
|----|------|
| Magnet Gameplay | `Anchor Impulse One Shot` / 改回 `Classic Hold` |
| Magnet Affects Players | 本实验应为 **false** |
| Impulse Max Range | 锚点选取距离（默认 520） |
| Impulse Attract Speed | 异极发射基础速度 |
| Impulse Repel Speed | 同极弹开速度 |
| Impulse Up Bias | 异极向上分量（越大越陡） |

## 回滚到原版

```bash
cd /Users/januswing/code/MagSlimeArena
git checkout master
```

或在当前分支把 **Magnet Gameplay** 改回 **Classic Hold**，并勾选 **Magnet Affects Players**。

## 保留实验继续改

```bash
git checkout experiment/anchor-impulse-one-shot
```
