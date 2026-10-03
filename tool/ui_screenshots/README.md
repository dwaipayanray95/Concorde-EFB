# UI screenshot harness

Renders every tab (Plan, Performance, Checklists, Monitor) in light + dark at
several window sizes with fake data (airport DB, METARs, live telemetry), and
reports every RenderFlex overflow with its source line. No device or sim needed.

It is stored as `.txt` so `flutter test` / CI never runs it. To use:

```bash
cp tool/ui_screenshots/screens_test.dart.txt test/zz_screens_test.dart
flutter test --update-goldens \
  --dart-define=OUT=/abs/path/to/output \
  --dart-define=SIZES=1280x800,915x412,740x360 \
  --dart-define=TABS=plan,perf,check,monitor \
  test/zz_screens_test.dart | grep OVERFLOWS
rm test/zz_screens_test.dart
```

Fonts: JetBrains Mono is fetched by google_fonts at runtime, which tests
can't do, so the harness registers DejaVu Sans Mono under the JetBrains Mono
family names (Linux path `/usr/share/fonts/truetype/dejavu/`) and the
Material icon font from the Flutter SDK cache (adjust paths on other OSes).
Letterforms differ slightly from the real app; layout is faithful.
