# SETUP — среда разработки и отладки

Проект: **Bring Dimitrii To Home: Luperon**
Движок: **Godot 4.7** (сборка GDScript), 2D, рендерер Compatibility
Машина: **Windows 11**, оболочка **PowerShell**, редактор **VS Code**

Цель документа: собрать среду так, чтобы отладка — включая живой деплой и
брейкпоинты на телефоне (Android) — заработала с первого прохода.

Отмечайте пункты по мере выполнения (`[x]`). Разделы 7-8 — приёмочная проверка
и типовые грабли.

> Вариант на C#: вместо стандартной сборки скачайте сборку **.NET (Mono)**
> Godot 4.7, а отладку скриптов ведите через **C# Dev Kit** (VS Code) или
> **JetBrains Rider**. Разделы по godot-tools / launch.json относятся к GDScript.
> Всё остальное (Android-тулчейн, телефон, деплой) — общее.

---

## 0. Предпосылки

- [ ] Windows 11 с правами администратора для установщиков.
- [ ] GPU с поддержкой Direct3D 12 — на Windows 11 есть гарантированно
      (это требование самой ОС), отдельное железо не нужно.
- [ ] Телефон на Android с кабелем USB (данные, не только зарядка).

---

## 1. Godot 4.7 (редактор)

Godot — портативный .exe, установка не требуется.

- [ ] Скачать **Godot 4.7 (Standard)** с godotengine.org.
- [ ] Положить в постоянную папку, например `C:\Tools\Godot\`.
      Переименовать исполняемый файл в `godot.exe` (упростит CLI и CI).
- [ ] Добавить `C:\Tools\Godot\` в переменную окружения **PATH**
      (System Properties -> Environment Variables -> Path -> New).
- [ ] Проверить в новом окне PowerShell:

```powershell
godot --version
# ожидается: 4.7.x.stable ...
```

- [ ] Запустить редактор, создать/открыть проект, в настройках проекта
      выбрать рендерер **Compatibility** (Project Settings -> Rendering ->
      Renderer -> Rendering Method = `gl_compatibility`).
- [ ] Установить шаблоны экспорта той же версии:
      Editor -> Manage Export Templates -> Download and Install.
      (Версия шаблонов обязана точно совпадать с версией редактора.)

---

## 2. VS Code + godot-tools

- [ ] Установить VS Code (если ещё нет).
- [ ] Установить расширение **godot-tools** (издатель: Godot Engine).
- [ ] В VS Code открыть Settings (JSON) и указать путь к движку:

```json
{
  "godotTools.editorPath.godot4": "C:\\Tools\\Godot\\godot.exe"
}
```

- [ ] В Godot связать внешний редактор с VS Code:
      Editor -> Editor Settings -> Text Editor -> External
      - Use External Editor: **включить**
      - Exec Path: `C:\Program Files\Microsoft VS Code\bin\code.cmd`
        (именно `code.cmd`, не `Code.exe`)
      - Exec Flags: `{project} --goto {file}:{line}:{col}`
        (с Godot 4.5 определяется автоматически, но лучше задать явно)
- [ ] Включить автоперечитывание:
      Text Editor -> Behavior -> Auto Reload Scripts on External Change.

Порты по умолчанию (менять не нужно, знать полезно):
Language Server **6005**, Debug Adapter **6006**
(Editor Settings -> Network). Для работы LSP редактор Godot должен быть открыт.

> Для C#: вместо godot-tools установить **C# Dev Kit** и использовать
> **C# Tools for Godot**; путь отладки — через .NET-дебаггер.

---

## 3. launch.json (отладка из VS Code)

- [ ] Открыть папку проекта в VS Code.
- [ ] Run and Debug -> create a launch.json file -> выбрать конфигурацию
      **Debug Godot**. Либо создать `.vscode/launch.json` вручную:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Godot project",
      "type": "godot",
      "request": "launch"
    }
  ]
}
```

Минимально достаточно `{ "name": "...", "type": "godot", "request": "launch" }`.
При необходимости добавляются поля: `scene` (конкретная сцена вместо главной),
`additional_options` (флаги командной строки движка), `address`, `port`.

- [ ] Порядок запуска: **сначала открыть проект в редакторе Godot**, затем в
      VS Code нажать **F5**. Если VS Code открыли раньше — нажать **Retry**
      в правом нижнем углу.

---

## 4. Android-тулчейн (на Windows)

### 4.1 JDK

- [ ] Установить **OpenJDK 17** (Microsoft Build of OpenJDK или Eclipse Temurin).
      Godot 4.7 рекомендует именно 17. Ставится ОТДЕЛЬНО и ДО SDK — sdkmanager
      сам написан на Java и без JDK не стартует.
- [ ] Проверить:

```powershell
java -version
# ожидается: 17.x
```

> Android Studio приносит собственный встроенный JDK (JetBrains Runtime).
> Он обслуживает только IDE — в настройках Godot (4.7) указывайте именно
> отдельный OpenJDK 17, а не встроенный. Смешение двух JDK — частый источник
> невнятных ошибок сборки.

### 4.2 Android SDK — через Android Studio

Рекомендуемый путь — поставить SDK через **Android Studio** (его SDK Manager
кладёт компоненты в правильную структуру каталогов и проводит через лицензии).
IDE после установки можно не открывать: Godot работает с папкой SDK напрямую.

**Требования Godot 4.7 (точные версии, сверено с docs 4.7):**
- OpenJDK 17 (раздел 4.1)
- Android SDK Platform-Tools 35.0.0+
- Android SDK Build-Tools **35.0.1**
- Android SDK Platform **android-35**
- Android SDK Command-line Tools (latest)
- NDK **28.1.13356709** (r28b)
- CMake **3.10.2.4988404**

> ВАЖНО, изменение против 4.6: в 4.7 **NDK и CMake входят в требования к
> экспорту** (в 4.6 были нужны только для сборки из исходников). Ставьте их.
> Заодно они понадобятся для нативного расширения физики троса (Rapier/Box2D).

Шаги:

- [ ] Запустить установщик Android Studio, тип установки — **Custom**.
- [ ] Снять галочку **Android Virtual Device** (встроенный эмулятор не нужен:
      тестируем на реальном телефоне, а AVD ещё и конфликтует с гипервизором
      MuMuPlayer). Бинарник эмулятора всё равно может остаться в списке — это
      безвредно, он без системного образа ничего не запускает.
- [ ] Путь SDK оставить по умолчанию: `%LOCALAPPDATA%\Android\Sdk`
      (например `C:\Users\<user>\AppData\Local\Android\Sdk`). Запишите его.
- [ ] Довести первичную установку до конца.
- [ ] Открыть **SDK Manager** (More Actions -> SDK Manager) и доставить точные
      версии. КЛЮЧЕВОЙ момент: включить галочку **Show Package Details** в правом
      нижнем углу — без неё видны только свежие версии (напр. android-37), а
      нужные 35.x и конкретные NDK/CMake спрятаны.
      - Вкладка **SDK Platforms** (с Show Package Details): отметить
        **Android SDK Platform 35** (android-35).
      - Вкладка **SDK Tools** (с Show Package Details): Build-Tools **35.0.1**,
        **Command-line Tools (latest)**, NDK **28.1.13356709**, CMake
        **3.10.2.4988404**, Platform-Tools.
- [ ] Apply, принять все лицензии (непринятая лицензия позже валит экспорт).

> Если Standard/первичная установка поставила Build-Tools 36 / Platform 37 /
> Sources 37 — это безвредные излишки, Godot будет использовать версии 35.
> Можно оставить или снять в SDK Manager.

**Проверка состава (PowerShell):**

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
"platform-tools","build-tools\35.0.1","platforms\android-35",
"cmdline-tools\latest","ndk\28.1.13356709","cmake\3.10.2.4988404" |
  ForEach-Object { "{0,-30} {1}" -f $_, (Test-Path "$sdk\$_") }
# все шесть строк должны быть True
```

> Про CLI: в новых сборках Android Studio standalone-утилита `sdkmanager`
> объявлена deprecated и подменяется новым `android` CLI, который НЕ понимает
> старый синтаксис `pkg;version` (выдаёт "Package ... not found"). Это не
> поломка — просто ставьте/добирайте компоненты через GUI SDK Manager, он
> надёжен и авторитетен. Новый `android` CLI: см. d.android.com/tools/agents.

### 4.2a MuMuPlayer как доп. цель (опционально)

Можно деплоить и в MuMuPlayer через adb, НО он x86_64, а не ARM. В пресете
экспорта (6) тогда дополнительно включите архитектуру **x86_64** (arm64-v8a
оставьте для телефона), иначе APK под один arm64 в MuMu упадёт при старте.
Подключение: `adb connect 127.0.0.1:<порт из настроек MuMu>` -> `adb devices`.
Для «честного» ощущения физики и тача основная цель — всё равно телефон.

### 4.3 Debug keystore

Создать канонический отладочный keystore (детерминированно):

```powershell
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android `
  -keystore debug.keystore -storepass android `
  -dname "CN=Android Debug,O=Android,C=US" -validity 10000 -deststoretype pkcs12
```

(Либо дать Godot сгенерировать keystore автоматически, если доступны keytool/jarsigner.)

### 4.4 Привязать тулчейн к Godot

- [ ] Editor -> Editor Settings -> Export -> Android:
      - Java SDK Path: папка установки OpenJDK 17
      - Android SDK Path: `%LOCALAPPDATA%\Android\Sdk`
      - Debug Keystore: путь к `debug.keystore`
      - Debug Keystore User: `androiddebugkey`
      - Debug Keystore Pass: `android`

---

## 5. Подготовка телефона

- [ ] Включить режим разработчика: Settings -> About phone ->
      тапнуть **Build number** 7 раз.
- [ ] В Developer options включить **USB debugging**.
- [ ] Подключить телефон кабелем, на экране телефона подтвердить
      доверие компьютеру (RSA-запрос).
- [ ] Проверить связь:

```powershell
adb devices
# ожидается строка вида: XXXXXXXX    device   (не "unauthorized")
```

---

## 6. Экспорт-пресет и деплой на устройство

- [ ] Project -> Export -> Add -> **Android**. Создать пресет.
      Для отладочных прогонов оставить Export With Debug включённым.
- [ ] После появления валидного пресета и подключённого устройства в правом
      верхнем углу редактора появится **иконка телефона** — это one-click deploy
      (запуск сборки на устройстве; деплой идёт по USB).
- [ ] Для живой отладки на телефоне включить:
      Debug -> **Deploy with Remote Debug**
      (запущенная на телефоне сборка подключается к IP этого ПК — работают
      брейкпоинты и логи).
- [ ] Для ускорения итераций: Debug -> **Small Deploy with Network Filesystem**.

---

## 7. Приёмочная проверка (среда готова, если всё проходит)

- [ ] `godot --version` печатает 4.7.x.
- [ ] В VS Code LSP подключён (нет статуса "Retry"), работает автодополнение API.
- [ ] F5 в VS Code останавливается на брейкпоинте в `.gd`-скрипте (локально).
- [ ] `adb devices` показывает телефон как `device`.
- [ ] Иконка телефона в редакторе активна; one-click deploy запускает игру
      на телефоне.
- [ ] При включённом Deploy with Remote Debug брейкпоинт срабатывает, пока
      игра выполняется **на телефоне**.
- [ ] CLI-экспорт работает (пригодится для CI):

```powershell
godot --headless --export-debug "Android" build/game.apk
```

---

## 8. Типовые грабли первого прохода

- **VS Code показывает "Retry" / нет автодополнения** — редактор Godot должен
  быть открыт (LSP живёт в нём). Открыть Godot и нажать Retry.
- **Exec Path не срабатывает** — на Windows указывать `code.cmd`, не `Code.exe`.
- **Сборка Android падает по Java** — `java -version` должен показывать 17;
  в Godot задан корректный Java SDK Path.
- **Несовпадение версий SDK** — ставить именно Build-Tools 35.0.1 /
  Platform android-35; иначе экспорт не соберётся.
- **`adb` показывает "unauthorized"** — подтвердить RSA-запрос на телефоне,
  переподключить кабель.
- **Export templates версии не той** — шаблоны обязаны совпадать с версией
  редактора (4.7.x), иначе экспорт не пройдёт.
- **Git метит сцены как изменённые на ровном месте** — `git config --global
  core.autocrlf input` и сгенерированный `.gitattributes`.
- **На будущее (плагины/GDExtension)** — когда подключите нативное расширение
  физики (Rapier/Box2D для троса) или плагины IAP/рекламы, в Android-пресете
  включите **Use Gradle Build** и установите шаблон сборки
  (Project -> Install Android Build Template), чтобы нативные библиотеки
  попали в APK.
