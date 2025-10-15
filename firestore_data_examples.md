# Exemples de données Firestore pour Muslim App

## Collection: hadiths

```json
{
  "hadith_001": {
    "text": "إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى",
    "source": "صحيح البخاري - كتاب بدء الوحي",
    "reviewed": true,
    "created_at": "2025-01-01T00:00:00Z"
  },
  "hadith_002": {
    "text": "لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ",
    "source": "صحيح البخاري - كتاب الإيمان",
    "reviewed": true,
    "created_at": "2025-01-02T00:00:00Z"
  }
}
```

## Collection: quiz_questions

```json
{
  "quiz_001": {
    "question": "Combien de piliers (Arkaan) compte l'Islam ?",
    "options": ["3", "4", "5", "6"],
    "answerIndex": 2,
    "explanation": "L'Islam repose sur 5 piliers fondamentaux : la Shahada (attestation de foi), la Salah (prière), la Zakat (aumône), le Sawm (jeûne du Ramadan) et le Hajj (pèlerinage à La Mecque).",
    "reviewed": true,
    "created_at": "2025-01-01T00:00:00Z"
  },
  "quiz_002": {
    "question": "Quelle est la première sourate du Coran ?",
    "options": ["Al-Baqarah", "Al-Fatiha", "An-Nas", "Al-Ikhlas"],
    "answerIndex": 1,
    "explanation": "Al-Fatiha (L'Ouverture) est la première sourate du Coran. Elle est récitée dans chaque unité (rak'ah) de la prière.",
    "reviewed": true,
    "created_at": "2025-01-02T00:00:00Z"
  }
}
```

## Collection: quran

```json
{
  "sura_001": {
    "sura_number": 1,
    "name": "Al-Fatiha",
    "verses": [
      {
        "ayah": 1,
        "text": "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        "translation_fr": "Au nom d'Allah, le Tout Miséricordieux, le Très Miséricordieux.",
        "audio_url": "https://example.com/quran/001/001.mp3"
      },
      {
        "ayah": 2,
        "text": "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
        "translation_fr": "Louange à Allah, Seigneur de l'univers.",
        "audio_url": "https://example.com/quran/001/002.mp3"
      },
      {
        "ayah": 3,
        "text": "الرَّحْمَٰنِ الرَّحِيمِ",
        "translation_fr": "Le Tout Miséricordieux, le Très Miséricordieux,",
        "audio_url": "https://example.com/quran/001/003.mp3"
      }
    ]
  },
  "sura_002": {
    "sura_number": 2,
    "name": "Al-Baqarah",
    "verses": [
      {
        "ayah": 1,
        "text": "الم",
        "translation_fr": "Alif, Lam, Mim.",
        "audio_url": "https://example.com/quran/002/001.mp3"
      },
      {
        "ayah": 2,
        "text": "ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ",
        "translation_fr": "Ce Livre n'est sujet à aucun doute; c'est un guide pour les pieux,",
        "audio_url": "https://example.com/quran/002/002.mp3"
      }
    ]
  }
}
```

## Instructions d'import

### 1. Configuration Firestore
- Créer les collections avec ces noms exacts
- Configurer les règles de sécurité (voir firestore.rules)
- Activer les index composites si nécessaire

### 2. Import des données
- Utiliser Firebase Console ou Firebase CLI
- Respecter la structure JSON exacte
- Vérifier que `reviewed: true` pour tous les contenus validés

### 3. URLs audio
- Remplacer les URLs d'exemple par de vraies sources
- Recommandé : hébergement sur Firebase Storage
- Formats supportés : MP3, M4A

### 4. Expansion des données
- Ajouter plus de hadiths avec sources authentiques
- Compléter les 114 sourates du Coran
- Créer plus de questions de quiz variées

### 5. Validation du contenu
- Seuls les contenus avec `reviewed: true` apparaissent dans l'app
- Révision par des érudits islamiques recommandée
- Sources authentiques uniquement (Sahih Bukhari, Sahih Muslim, etc.)

## Notes importantes
- Respecter l'ordre chronologique pour les sourates
- Numérotation des versets selon la version standard
- Traductions en français de qualité
- Audio de récitateurs reconnus