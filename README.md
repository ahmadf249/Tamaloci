# TAMA"LO"CI

Native iOS virtual-pet game. Offline-first Tamagotchi-style care with a stylized 3D floating-head avatar.

**Bundle ID:** `com.local.Tamaloci`  
**Display name:** `TAMA"LO"CI`

## Active focus

**M3 — Persistent pet** complete. Next: first **M4** slice (simulation engine) when written in private docs. Authored mesh polish is optional and non-blocking.

Product roadmap, requirements PDF, asset policy, and runbook live in a local `docs/` folder that is **not published** with this repository. Keep your private copy nearby when developing.

| Milestone | Status |
| --- | --- |
| M0 — Prototype (floating head + expression HUD) | Done |
| M1 — Avatar system | Done |
| M2 — Pet creation | Done |
| M3 — Persistent pet | Done |
| M4+ | Tracked in local private docs |

## M3 shipped (persistence)

- SwiftData models: Pet, Needs, State, CareEvent, Memorial, EnvironmentSnapshot
- `PetRepository` + one-shot UserDefaults → SwiftData migration
- Kill/relaunch keeps active pet; minimal Memorial list + DEBUG mark deceased / append care

## M2 shipped (pet creation)

- First-run welcome → camera explain → ARKit live preview **or** selfie/manual → avatar editor → naming → pet home
- `CreatedPetStore` (UserDefaults) for returning-player skip (SwiftData in M3)
- Expanded `AvatarConfiguration` morphs + Vision/ARKit mappers (never raw face mesh as pet)
- CC0 low-poly head selected and provenance-logged; procedural fallback until `TamalociHead.usdz` is exported
- Camera usage string; denied camera still reaches create via manual editor
- No private Memoji/AvatarKit APIs; optional Memoji/Genmoji sticker via system keyboard (`UITextView`) maps to stylized params only (image not kept)

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
