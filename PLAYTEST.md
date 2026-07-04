# MagSlime Arena — Playtest & Branches

## Game flow (current: `feature/game-flow-ux`)

1. **Title** — MagSlime Arena + START
2. **Match** — Best of 7, first to 4 wins
3. **Round** — Cross finish line or opponent falls in lava
4. **Match end** — Winner screen: PLAY AGAIN / MENU

All in-game UI is **ASCII English** (Web-safe).

## Controls

| Player | Move | Jump | Anchor (strong) | Hook (weak) |
|--------|------|------|-----------------|-------------|
| P1 | A/D | W | F | G |
| P2 | Arrows | Up | Shift | Option |

## Branches

| Branch | Notes |
|--------|-------|
| `master` | Hold magnet + anchor jump |
| `experiment/anchor-impulse-one-shot` | One-shot anchor impulse |
| `experiment/dual-key-pvp-impulse` | Dual-key + weak PvP hook |
| **`feature/game-flow-ux`** | Title, scoring, lava FX, P1/P2 UI |

## Rollback

```bash
git checkout experiment/dual-key-pvp-impulse   # gameplay only, no title flow
git checkout master                              # original
```

## Web deploy

See [DEPLOY.md](DEPLOY.md). After changes:

```bash
./scripts/export-web.sh
git add web/ && git commit -m "Update web build" && git push
```
