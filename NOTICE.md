# NOTICE

**Aurel** (formerly EduTune) is a modified version of **FineTune**.

## Original work

- FineTune — Copyright (C) 2026 Ronit Singh
- Source: https://github.com/ronitsingh10/FineTune
- Based on upstream commit `2285279d36d3f8115c1c2d4aecd904f1bdf96a51` ("Update appcast for v1.9.0")
- Licensed under the GNU General Public License v3.0 (see `LICENSE`)

## Modifications

- Aurel modifications — Copyright (C) 2026 Eduardo Carvalho
- Licensed under the GNU General Public License v3.0, same as the original work

Ronit Singh is the author of FineTune and is not the author of, nor responsible for, the Aurel modifications.

### Summary of changes (2026-11-02)

- App name and bundle identifier changed to `EduTune` / `com.github.eduardo00873.EduTune`.
- Settings and AutoEQ data stored in `~/Library/Application Support/EduTune` (independent from FineTune).
- URL scheme changed from `finetune://` to `edutune://`.
- Internal aggregate audio devices renamed from `FineTune-<pid>` to `EduTune-<pid>`.
- Sparkle updates disabled: FineTune's update feed and signing key removed, updater not started, Updates tab hidden.
- About tab: EduTune name, attribution to FineTune, separate copyright lines; Donate button removed.

Internal target, scheme, folder and file names keep their original `FineTune` names.

### Rename (2026-11-02)

- Display name changed from EduTune to Aurel, with a new sound-wave app icon. Internal identifiers (bundle ID `com.github.eduardo00873.EduTune`, settings folder, `edutune://` URL scheme, `EduTune-` aggregate device prefix) are unchanged to preserve permissions and saved settings.
