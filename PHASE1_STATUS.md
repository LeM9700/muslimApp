# Phase 1 — UI Overhaul (terminée)

## Fichiers modifiés

| Fichier | Changement |
|---|---|
| `pubspec.yaml` | lottie ^3.1.0, intl ^0.19.0, flutter_localizations, generate: true |
| `lib/utils/app_theme.dart` | AppColors light (peach/lavande/rose, émeraude, cuivre). getLightTheme(). |
| `lib/widgets/glass_widgets.dart` | AnimatedGlassBackground → gradient pastel. LiquidGlassCard → bordure iridescente. |
| `lib/widgets/floating_navbar.dart` | Indicateur spring glissant émeraude→cuivre. Icônes dark sur fond clair. |
| `lib/navigation/main_navigation.dart` | status bar Brightness.dark. Nav items outlined/filled. |
| `lib/app.dart` | App renommée "Sakina". getLightTheme(). |
| `lib/screens/home_screen.dart` | Colors.white → AppColors dark. Titre "Sakina". |

## Fichiers créés

- `lib/l10n/app_fr.arb` — 32 clés (FR, principal)
- `lib/l10n/app_en.arb` — 32 clés (EN)
- `lib/l10n/app_ar.arb` — 32 clés (AR, RTL)

## À lancer maintenant

```bash
flutter pub get
flutter gen-l10n
flutter analyze
```

## 3 noms proposés (Q2)

1. **Sakina** (سكينة) — Tranquillité divine
2. **Nour** (نور) — Lumière
3. **Barakah** (بركة) — Bénédiction

## Phase 2 (à faire)

- Hero widgets sur les cards home (shared element transitions)
- Lottie : quiz ✓/✗, prayer glow, qibla found
- Quran "Play Sourate" — queue audio
- Progressive tooltips onboarding
- Couleurs quiz_screen / qibla_screen / quran_screen
