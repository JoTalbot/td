# Сборка под Android

## Требования

- Godot 4.2.2 (редактор) + **Export Templates** той же версии (`Editor → Manage Export Templates`).
- Android SDK (через Android Studio или командные `cmdline-tools`):
  - Platform Tools, Build-Tools 33+, Platform android-33+, NDK (устанавливается Godot'ом при необходимости).
- OpenJDK 17.

## Настройка (один раз)

1. В Godot: `Editor → Editor Settings → Export → Android` — укажите пути к Android SDK и Java.
2. Создайте debug keystore (или используйте свой release):
   ```bash
   keytool -genkey -v -keystore debug.keystore -alias androiddebugkey \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
   ```
3. `Project → Export → Add → Android`:
   - Package name: `com.neonbastion.td`
   - Orientation: Portrait (уже задано в настройках проекта)
   - Architectures: `arm64-v8a` (+ `armeabi-v7a` при желании)
   - Keystore: путь к вашему keystore.

Это создаст `export_presets.cfg` (не коммитим с приватными данными keystore — см. `.gitignore`).

## Сборка

Из редактора: `Project → Export → Android → Export Project`.

Или headless:

```bash
godot --headless --path . --export-debug "Android" build/NeonBastionTD-debug.apk
godot --headless --path . --export-release "Android" build/NeonBastionTD.apk
```

## Советы по производительности

- Рендерер уже `mobile`, MSAA 2x, glow включён — на слабых устройствах можно отключить glow в `Main._setup_environment()`.
- Тени только от одного DirectionalLight; не добавляйте shadow-casting OmniLight.
