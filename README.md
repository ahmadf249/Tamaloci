# TAMA"LO"CI

Native iOS virtual-pet game. Offline-first Tamagotchi-style care with a stylized 3D floating-head avatar.

**Bundle ID:** `com.local.Tamaloci`  
**Display name:** `TAMA"LO"CI`

## Active focus

**M2 — Pet creation** complete. Next: first **M3** slice (SwiftData persistent pet) when written in private docs.

Product roadmap, requirements PDF, asset policy, and runbook live in a local `docs/` folder that is **not published** with this repository. Keep your private copy nearby when developing.

| Milestone | Status |
| --- | --- |
| M0 — Prototype (floating head + expression HUD) | Done |
| M1 — Avatar system | Done |
| M2 — Pet creation | Done |
| M3+ | Tracked in local private docs |

## M2 shipped (pet creation)

- First-run welcome → camera explain → ARKit live preview **or** selfie/manual → avatar editor → naming → pet home
- `CreatedPetStore` (UserDefaults) for returning-player skip (SwiftData in M3)
- Expanded `AvatarConfiguration` morphs + Vision/ARKit mappers (never raw face mesh as pet)
- CC0 low-poly head selected and provenance-logged; procedural fallback until `TamalociHead.usdz` is exported
- Camera usage string; denied camera still reaches create via manual editor
- No Apple Memoji / private APIs

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
4. Create a pet (Simulator: skip camera or selfie/photo library → editor → name)

For device signing: select your Team under Signing & Capabilities. Camera permission is required only for face scan / selfie paths.
