# 🚗 DriveData

**Aplikace pro sledování jízd, správu vozidel a analýzu řidičského výkonu.**

DriveData je mobilní Flutter aplikace pro řidiče, kteří chtějí mít přehled o svých jízdách, spotřebě paliva, nákladech, servisní historii a pojistkách – vše lokálně v telefonu bez nutnosti registrace nebo cloudového účtu.

---

## ✨ Funkce

### 🛣️ Jízdy
- Záznam každé jízdy: vzdálenost, čas, typ trasy, počasí, hustota provozu
- Spotřeba paliva – zadání z palubního počítače nebo výpočet z tankování
- Náklady na km (Kč/km)
- Připojení vozíku k jízdě (automaticky upraví limity rychlosti dle CZ zákona)
- Swipe-to-delete s potvrzovacím dialogem
- Filtrování jízd podle vozidla

### 📊 Skóre řidiče
Každá jízda dostane objektivní hodnocení 1–10 ze tří složek:
- **Plynulost** – poměr průměrné a maximální rychlosti (s korekcí na hustotu provozu)
- **Předvídavost** – skutečná spotřeba vs. historický průměr auta (s korekcí na provoz)
- **Dodržování limitů** – max. rychlost vs. limit pro typ trasy / s vozíkem

### 📈 Analýza
- Trend skóre řidiče (posledních 20 jízd)
- Trend spotřeby paliva (fill-to-fill metoda)
- Spotřeba podle typu trasy
- Přehledové karty: celkem km, náklady, průměrná spotřeba, průměrné skóre

### 🚙 Auta
- Evidence vozidel (značka, model, rok, typ paliva, SPZ, fotka)
- Typická spotřeba z technického průkazu jako výchozí baseline
- Statistiky na přehledové kartě (celkem km, spotřeba, náklady)

### 🔧 Servis
- Historie servisních záznamů s přílohami (fotky, PDF)
- Připomínky: datum nebo km interval (push notifikace)
- Filtrování podle vozidla

### 🛡️ Pojistky
- Evidence pojistek s datem platnosti a výší pojistného
- Upozornění na blížící se expiraci

### 🎯 Cíle
- Vlastní cíle (km za měsíc/rok, max. spotřeba, max. náklady atd.)
- Progress bar s aktuálním plněním

### 🚚 Vozíky / Přívěsy
- Evidence přívěsů, připojení k jízdám
- Automatická úprava rychlostních limitů (CZ zákon: 80 km/h dálnice, 50 město, 30 terén)

### ⚙️ Nastavení
- Světlé / Tmavé téma + výběr barevného schématu
- Zálohování a obnova dat (export/import SQLite DB)

---

## 🛠️ Technický stack

| Vrstva | Technologie |
|--------|------------|
| Framework | [Flutter](https://flutter.dev) 3.x |
| State management | [Provider](https://pub.dev/packages/provider) |
| Databáze | [sqflite](https://pub.dev/packages/sqflite) (lokální SQLite) |
| Grafy | [fl_chart](https://pub.dev/packages/fl_chart) |
| Notifikace | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |
| ID generace | [uuid](https://pub.dev/packages/uuid) |
| Lokalizace čísel | [intl](https://pub.dev/packages/intl) |

---

## 🚀 Spuštění

### Požadavky
- Flutter SDK >= 3.0.0
- Android Studio / VS Code s Flutter extension
- Android emulator nebo fyzické zařízení (Android 7+)

### Instalace

```bash
git clone https://github.com/Belzeus30/DriveData.git
cd DriveData
flutter pub get
flutter run
```

### Build release APK

```bash
flutter build apk --release
```

APK najdeš v `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📁 Struktura projektu

```
lib/
├── database/
│   └── database_helper.dart     # SQLite – veškerá práce s DB
├── models/                      # Datové modely (Car, Trip, ServiceRecord, ...)
├── providers/                   # State management (ChangeNotifier)
├── screens/
│   ├── analytics/               # Grafy a přehledové statistiky
│   ├── cars/                    # Správa vozidel
│   ├── goals/                   # Cíle
│   ├── insurance/               # Pojistky
│   ├── service/                 # Servisní záznamy
│   ├── trailers/                # Vozíky / přívěsy
│   ├── trips/                   # Jízdy + přidání/editace
│   └── settings/                # Nastavení, záloha
├── services/
│   ├── backup_service.dart      # Export / import DB
│   └── notification_service.dart
└── utils/
    └── constants.dart           # Konstanty (ikony, popisky, barvy)
```

---

## 📸 Screenshots

*Brzy doplním*

---

## 📄 Licence

Tento projekt je soukromý. Všechna práva vyhrazena © 2026 Radek (Belzeus30).
