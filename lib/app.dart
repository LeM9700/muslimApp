import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'utils/app_theme.dart';

/// Widget racine de l'application
/// Configure le thème, les routes et la navigation globale
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Clé globale pour la navigation (utile pour notifications)
  static final GlobalKey<NavigatorState> navigatorKey = 
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muslim App',
      debugShowCheckedModeBanner: false,
      
      // Thème sombre personnalisé
      theme: AppTheme.getDarkTheme(),
      
      // Configuration de navigation
      navigatorKey: navigatorKey,
      initialRoute: AppRoutes.home,
      routes: AppRoutes.getRoutes(),
      
      // Gestion des routes inconnues
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(
              child: Text(
                'Page non trouvée',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ),
          ),
        );
      },
    );
  }
}