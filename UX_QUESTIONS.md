# muslimApp — Questions UX/UI

> Réponds en format libre ici même, une ligne par question suffit.
> Ces questions informent l'implémentation motion + design basée sur :
> genjutsu (AThevon) · motion-design-skill (LottieFiles) · design-dna (zanwei)

---

## Design DNA — identité visuelle

**Q1.** Tu as des apps ou sites de référence dont tu admires le design ?
_(noms, screenshots, URLs — design-dna extrait un ADN visuel JSON depuis tes références)_

**Q2.** Tu as un nom de marque en tête, ou on reste sur "Muslim App" pour le MVP ?

**Q3.** Quel mot unique résume l'émotion que l'app doit dégager ?
→ Sérénité · Spiritualité · Modernité · Tradition · Force · Douceur

**Q4.** Tu gardes la palette actuelle (bleu nuit #0A1E32 + glassmorphism) ou tu explores autre chose ?
Couleur d'accent envisagée — or, vert émeraude, cuivre... ?

---

## Motion Design — personnalité du mouvement

**Q5.** Animations **discrètes et apaisantes** (contexte spirituel) ou **expressives et engageantes** (app moderne) ?

**Q6.** Quelles micro-interactions sont prioritaires ?
- A) Réponse quiz (correct/incorrect)
- B) Boussole Qibla (rotation)
- C) Verset Coran (tap → audio)
- D) Countdown prochaine prière
- E) Navigation entre onglets

**Q7.** Transitions entre écrans :
- **Shared element** (card → plein écran) ≈ 2 jours
- **Simple slide/fade** (standard) ≈ 2 heures

---

## Genjutsu — interaction thesis

**Q8.** Le moment-clé émotionnel de l'app — celui où l'utilisateur doit ressentir quelque chose de fort ?
_(prochaine prière qui arrive, bonne réponse quiz, Qibla trouvée, fin de sourate...)_

**Q9.** Navbar flottante : **conserver + améliorer** (indicateur d'onglet spring animé) ou **repenser** ?

**Q10.** Animations de chargement / états vides :
- **Lottie** = premium, JSON After Effects, dépendance `lottie: ^3.x`
- **Flutter pur Dart** = léger, 100% customisable, zéro dépendance

---

## UX Structure — décisions de flux

**Q11.** Onboarding au premier lancement :
- **3 slides illustrées** (features + permissions) ≈ 1 jour
- **Tooltips contextuels progressifs** ≈ meilleure UX, plus complexe

**Q12.** Lecture Coran — playback continu :
- **A)** Bouton "Play sourate" → lit tous les versets en file
- **B)** Tap verset → joue + auto-passe au suivant après 2s

**Q13.** Cible principale :
- **Diaspora française** — MVP tout en français (le plus rapide)
- **Multilingue dès maintenant** — i18n AR + EN + FR (à cadrer maintenant, 3-5× plus cher après)

---

## Ton format de réponse

```
1. Zikr app + Notion
3. Sérénité
4. Or comme accent
5. Discret
6. A + B
8. Moment Qibla trouvée
10. Flutter pur Dart
12. A
13. FR pour le MVP
```
