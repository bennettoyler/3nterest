# AGENTS.md — Interest

Instructions for every coding agent (Claude Code, Capy, or other) working in this repo. Read this first, then the two documents below.

## What we are building

3nterest (3D + Pinterest, pronounced "interest"): a native iOS app where a LiDAR room scan becomes a room of movable, vendor-linked 3D products that can be bought through Whop, extended with AI-designed pieces, and shared to a Pinterest-style feed. It is a hackathon demo built in one day by three developers, each running agents.

- Spec (what and why): `docs/superpowers/specs/2026-11-15-interest-prd.md`
- Plan (how, task by task): `docs/superpowers/plans/2026-11-15-interest-implementation.md`

If this file and the plan disagree, the plan wins. If the plan and the spec disagree, stop and ask your developer.

## Find your lane

Your developer tells you which lane you are. You work only on that lane's tasks.

| Lane | Branch | Folders you may edit | Plan section | Tasks |
|---|---|---|---|---|
| Dev 1 — 3D | `dev1-3d` | `Interest/Room3D/` | "Dev 1 — Room3D" | A1–A5 |
| Dev 2 — App | `dev2-app` | `Interest/App/`, `Interest/Screens/`, `project.yml` | "Dev 2 — App, screens, payments UI" | B1–B6 |
| Dev 3 — Backend | `dev3-backend` | `convex/`, `seed/`, `Interest/Shared/` | "Dev 3 — Convex, seed, OpenAI, Whop" | C1–C5 |

Tests go in `InterestTests/` (Swift) or next to the code in `convex/lib/` (TypeScript); name test files after the thing they test so lanes do not collide.

From the plan, read: the header, Global Constraints, Review Focus, File Map, Task 0, your own lane, and Task Z. You can skip the other two lanes; everything you need from them is in Task 0's contracts and your tasks' "Consumes" lines.

## Setup order

1. **Task 0 first, together.** Nothing else starts until Task 0 is merged to `main`: the Xcode project spec, `Interest/Shared/Models.swift`, `Interest/Shared/Backend.swift`, `StubBackend`, `SampleRoom.json`, the test fixtures, and the Convex schema.
2. **Then branch.** Each lane creates its branch from `main` in its own git worktree.
3. **Work your tasks in order.** Each task lists its files, the interfaces it consumes and produces, its tests, and how to verify it. Commit at the end of every task.
4. **Merge at the milestones:** 1:00 PM, 3:30 PM, 4:30 PM (feature freeze). Rebase on `main` before merging. After 4:30, fixes only.

## Rules

- **Stay in your folders.** Never edit another lane's folder. If you need something changed there, tell your developer; do not do it yourself.
- **`Interest/Shared/` is frozen after Task 0.** The model types and the `Backend` protocol change only when all three developers agree. Dev 3's lane may add `ConvexBackend.swift` there and fill it in; nothing else.
- **Use the exact names in the plan** for types, functions, files and Convex functions. Other lanes are building against them without seeing your code.
- **Build against `StubBackend`** until the real backend lands. Do not wait on another lane.
- **Never commit the Xcode project.** It is generated: run `xcodegen generate` after pulling or adding files. `*.xcodeproj` is git-ignored.
- **Never commit secrets.** OpenAI and Whop keys live in Convex environment variables only; they never go in the app or the repo.
- **It is a demo.** Hardcode where the plan says to. Do not add features, settings, auth, or abstractions the plan does not ask for. If you are behind, cut in the order the PRD gives.
- **Every network step needs its fallback** (sample room, canned design, stub feed, fallback checkout link) as written in the plan.
- **Tests only where the plan specifies them** (pure logic). Screens and 3D are verified by hand on the phone; say plainly in your report what you could not verify yourself.
- **Do not push to `main` directly** after Task 0, and do not merge another lane's branch. Your developer merges.

## Conventions

- Swift 5.10, SwiftUI, iOS 17+, SceneKit for 3D, RoomPlan for scanning.
- Units: metres, Y up, floor at `y = 0`. Transforms are 16 floats, column-major. Money is integer cents. AI design parts are centimetres and degrees.
- Platform fee is 5%: `platformFeeCents = round(amountCents * 0.05)`, `sellerCents = amountCents - platformFeeCents`.
- Brand: the app's name is "3nterest" (3D + Pinterest, pronounced "interest"), the logo is a bold white sans-serif 3 on a YC-orange `#FF6600` square, and code identifiers (target, scheme, module, folders, bundle id, the `interest://` URL scheme) keep the name Interest. Colours are YC orange `#FF6600` and white.
- Commit messages: `feat(room3d): …`, `feat(app): …`, `feat(backend): …`, `fix(…): …`.

## Commands

```bash
xcodegen generate
xcodebuild -scheme Interest -destination 'generic/platform=iOS' build
xcodebuild test -scheme Interest -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
npx convex dev
npx convex run seed:run
node seed/upload.mjs
npx vitest run
```

## When you are blocked

- Something you consume from another lane is missing or different from the plan → use the stub, note it in your report, and tell your developer.
- A sponsor API (Whop, Convex Swift client, OpenAI) does not behave as the plan assumes → stop guessing, check its current documentation, and report what you found. The plan marks these as unverified.
- A task will not fit its time slot → say so early and propose what to cut, following the PRD's cut order.
