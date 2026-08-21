# Kinetic brand assets

Source of truth for app icons (bold white lowercase **k** on a colored tile — same
form as the classic Android launcher, drawn as a sharp vector):

| File | Role |
|------|------|
| `logo-parent.svg` / `logo-kids.svg` | Vector masters (edit these) |
| `logo-*-1024.png` | Full-bleed square PNG for `flutter_launcher_icons` |
| `logo-*-1024-rounded.png` | Rounded tile for README / in-app headers |
| `logo-*-512.png` | F-Droid / web convenience size |

Regenerate rasters after editing the SVGs (exporter mirrors the SVG geometry):

```bash
python tool/export_brand_icons.py
```

Then regenerate platform icons:

```bash
cd apps/parent && dart run flutter_launcher_icons
cd ../kids && dart run flutter_launcher_icons
```

Copy rounded masters into app assets if needed:

```bash
cp brand/logo-parent-1024-rounded.png apps/parent/assets/icons/app_icon.png
cp brand/logo-kids-1024-rounded.png apps/kids/assets/icons/app_icon.png
```
