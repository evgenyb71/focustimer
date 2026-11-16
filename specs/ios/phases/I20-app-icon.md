# I20 Supply the final app icon

Status: verified

## Goal

FocusTimer has its own icon on the Home Screen and wherever iOS shows the app, such as Settings and notifications, in the light, dark, and tinted Home Screen looks. Today the 1024×1024 slot is empty, so iOS shows a blank placeholder.

Roadmap exit check: the 1024×1024 artwork slot is complete, and its appearance is verified in the app and on the Home Screen.

## Decisions

User, 2026-11-16:

- **Source:** the agent draws the artwork with a small Swift script using CoreGraphics, kept in `scripts/`, so the icon is reproducible and easy to adjust. No outside tools or downloads.
- **Concept:** two overlapping timer rings, Focus then Break, carried over from the Chrome icon and redrawn in the app's teal and sage on its warm cream.
- **Variants:** light, dark, and tinted versions, each made by hand in the same icon asset.
- **Checks:** the user builds and runs on their simulator, takes a Home Screen screenshot in each look, and checks the icon in Settings > Notifications and on a delivered alert. The agent takes its own screenshots on its simulator.

Agent decisions, open to revision:

- **Light:** cream background from the app's gradient; the Focus ring in teal (0.16, 0.44, 0.42) behind and to the upper left, the Break ring in sage (0.28, 0.44, 0.26) in front and to the lower right, each with a short hand. The rings are thick enough to read at 60 pt and smaller, and the Chrome icon's orange hands become the ring colours.
- **Dark:** the same rings in lighter teal and sage on a transparent background, so iOS supplies its dark backdrop, as Apple recommends.
- **Tinted:** a greyscale version on a transparent background, with the front ring brighter, so iOS can apply the user's tint.
- **Format:** three 1024×1024 PNGs without transparency in the light one and without rounded corners, since iOS applies the mask. The asset catalog lists them by appearance. The script writes the PNGs; the PNGs are committed so a build needs no script run.
- **Script:** run with `swift scripts/make-app-icon.swift`, from the repository root, writing into the icon set. It is not part of the build.
- **Saved data:** no change.

## Non-goals

- An Icon Composer (Liquid Glass) layered icon; worth revisiting if iOS's automatic glass treatment of the flat PNGs looks poor.
- App Store marketing artwork or screenshots.
- Changing the in-app UI, launch screen, or accent colour.

## Plan

Tick an item only when it is done.

- [x] Write the icon-drawing script for the light, dark, and tinted versions.
- [x] Generate the three PNGs and list them by appearance in the icon set.
- [x] Check the PNGs: 1024×1024, the light one opaque, and the design readable when scaled down to 60 pt and 40 pt.
- [x] Build and run `scripts/test.sh`, and record the output in Results.
- [x] Take agent screenshots of the light icon on iPhone 17 Pro, iOS 26.5; the dark and tinted looks are left to the user check (see Results).
- [x] User: run on the simulator, screenshot the Home Screen in each look, and check Settings > Notifications and a delivered alert; record in Results as user-reported.
- [x] Update the [mission](../mission.md) UI description, "Still to build", and the [tech stack](../tech-stack.md) source map.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [ ] Open the PR with screenshots; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run:

- `scripts/test.sh`, as the project's assets change; no new unit tests, since no Swift logic changes.
- `sips` checks the size and alpha of each PNG.
- Home Screen screenshots in each look on the agent's own simulator.

User-reported, in Xcode:

- The app builds and runs.
- Home Screen screenshots in the light, dark, and tinted looks.
- The icon appears in Settings > Notifications > FocusTimer and on a delivered alert.

Stays unverified: a physical device; how the icon looks at every system size beyond the Home Screen, Settings, and alerts.

## Results

Agent-run, 2026-11-16, iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 247, passed 247, failed 0, skipped 0, expected failures 0
PASSED
```

- `swift scripts/make-app-icon.swift` wrote the three PNGs. `sips`: each is 1024×1024; the light one has no alpha, and the dark and tinted ones have alpha.
- Scaled down to 120 px and 300 px, the light icon's two rings and hands stay distinct.
- The built app's `Assets.car` holds all three renditions, with the dark and tintable appearances (`assetutil --info`).
- The light icon appears in the App Library, with iOS's rounded mask and glass edge. With the simulator in dark mode, the App Library still showed the light icon: the Home Screen's icon look is set separately under Customize, which the agent cannot set from the command line. The dark and tinted looks are therefore left to the user check.

User-reported, 2026-11-16, on the user's simulator: the app built and ran; Home Screen screenshots in the light, dark, and tinted looks show the matching icon; the icon appears in Settings > Notifications > FocusTimer and on a delivered alert. The screenshots go in the PR.

Remaining limitations: not checked on a physical device, or at every system size beyond the Home Screen, App Library, Settings, and alerts. The icon is flat; iOS adds its own glass edge, and an Icon Composer layered icon stays a later option.

