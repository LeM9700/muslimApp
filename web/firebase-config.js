// Firebase configuration for web
// Note: For web deployment, these values should be set via environment variables
const firebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY || "your_api_key_here",
  authDomain: process.env.FIREBASE_AUTH_DOMAIN || "your_project.firebaseapp.com",
  projectId: process.env.FIREBASE_PROJECT_ID || "your_project_id",
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || "your_project.firebasestorage.app",
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID || "your_sender_id",
  appId: process.env.FIREBASE_APP_ID || "your_app_id"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);