# TAMA"LO"CI

Native iOS virtual-pet game. Offline-first Tamagotchi-style care with a stylized 3D floating-head avatar.

**Bundle ID:** `com.local.Tamaloci`  
**Display name:** `TAMA"LO"CI`

## Active focus

**M1 — Avatar system** (slice **M1.1**: head path + idle polish)

Product roadmap, requirements PDF, asset policy, and runbook live in a local `docs/` folder that is **not published** with this repository. Keep your private copy nearby when developing.

| Milestone | Status |
| --- | --- |
| M0 — Prototype (floating head + expression HUD) | Done |
| M1 — Avatar system | Next |
| M2+ | Tracked in local private docs |

## M0 shipped (prototype)

- SwiftUI shell with brand title
- RealityKit procedural floating head (idle float + blink)
- Expression pipeline driven by HUD / test state
- Domain stubs for future simulation (`PetNeeds`, lifecycle)

## Open in Xcode

```bash
cd /Users/miftahuljannah/Downloads/Tamaloci
open Tamaloci.xcodeproj
```

If you change `project.yml`, regenerate:

```bash
xcodegen generate
```

## Run

1. Open `Tamaloci.xcodeproj` in Xcode
2. Scheme **Tamaloci** → iPhone Simulator (e.g. iPhone 16, OS 18.6) or a physical device
3. Press Run (⌘R)
4. Use the expression HUD to verify the floating-head POC

For device signing: select your Team under Signing & Capabilities. No camera/location entitlements are required for M0/M1 prototype work.
