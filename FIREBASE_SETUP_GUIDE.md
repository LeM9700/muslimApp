# 🔥 Guide Configuration Firebase - Muslim App

## ✅ Configuration Firebase Terminée

**Firebase est maintenant correctement configuré dans votre application !**

## 📊 Que Faire Maintenant ?

### 1. **Configurer Firestore Database**

1. **Allez sur** : https://console.firebase.google.com/project/muslim-app-1c2a9
2. **Firestore Database** → **Créer une base de données**
3. **Mode de test** (règles ouvertes pendant 30 jours)
4. **Région** : `europe-west3` (Francfort)

### 2. **Importer les Données de Test**

Dans Firebase Console → Firestore :

#### Collection `hadiths` :
Créer les documents suivants (utilisez l'ID automatique) :

**Document 1 :**
```json
{
  "text": "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى",
  "source": "صحيح البخاري",
  "reviewed": true,
  "created_at": "2025-01-01T00:00:00Z"
}
```

**Document 2 :**
```json
{
  "text": "من كان يؤمن بالله واليوم الآخر فليقل خيرا أو ليصمت",
  "source": "صحيح البخاري", 
  "reviewed": true,
  "created_at": "2025-01-02T00:00:00Z"
}
```

#### Collection `quiz_questions` :
Créer les documents suivants :

**Document 1 :**
```json
{
  "question": "Combien de sourates compte le Coran ?",
  "options": ["112", "114", "116", "118"],
  "answerIndex": 1,
  "explanation": "Le Coran comprend 114 sourates, de Al-Fatiha à An-Nas.",
  "reviewed": true,
  "created_at": "2025-01-01T00:00:00Z"
}
```

**Document 2 :**
```json
{
  "question": "Combien de piliers compte l'Islam ?",
  "options": ["3", "4", "5", "6"],
  "answerIndex": 2,
  "explanation": "L'Islam repose sur 5 piliers : la Shahada, la Salat, la Zakat, le Hajj et le Sawm.",
  "reviewed": true,
  "created_at": "2025-01-03T00:00:00Z"
}
```

### 3. **Règles de Sécurité Firestore** (Optionnel)

Pour la production, remplacez les règles par :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Lecture seule pour tous les utilisateurs
    match /{document=**} {
      allow read: if true;
      allow write: if false; // Écriture uniquement par admin
    }
  }
}
```

## 🚀 **Test de l'Application**

Maintenant vous pouvez tester l'application :

```powershell
# Dans le terminal VS Code
flutter run -d emulator-5554
```

## 📱 **Fonctionnalités Avec Firebase**

### ✅ **Mode Connecté** (avec Firebase) :
- **Indicateur vert** 🟢 sur les widgets
- **Données réelles** depuis Firestore
- **Synchronisation** en temps réel
- **Compteurs exacts** dans le profil

### ⚠️ **Mode Hors Ligne** (sans Firebase) :
- **Indicateur orange** 🟠 sur les widgets  
- **Données de test** prédéfinies
- **Fonctionnement** complet en local
- **Compteurs fixes** (42 hadiths, 156 questions)

## 🔧 **Indicateurs de Statut**

L'application affiche automatiquement :
- **Cloud vert** ☁️ : Firebase connecté
- **Cloud barré orange** ☁️ : Mode hors ligne/test

## 📊 **Structure Firebase Actuelle**

```
muslim-app-1c2a9 (Firebase Project)
├── 📁 collections/
│   ├── hadiths/
│   │   ├── text (string)
│   │   ├── source (string)  
│   │   ├── reviewed (boolean)
│   │   └── created_at (timestamp)
│   └── quiz_questions/
│       ├── question (string)
│       ├── options (array)
│       ├── answerIndex (number)
│       ├── explanation (string)
│       ├── reviewed (boolean)
│       └── created_at (timestamp)
```

## 🐛 **Dépannage**

**Si Firebase ne se connecte pas :**
1. Vérifiez que `google-services.json` est dans `android/app/`
2. Le package name doit être exactement `com.example.muslim_app`
3. Redémarrez l'application complètement

**Si compilation échoue :**
```powershell
flutter clean
flutter pub get
flutter run
```

---

**🎉 Firebase est maintenant parfaitement intégré ! L'application fonctionne en mode hybride : Firebase quand disponible, données locales sinon.**