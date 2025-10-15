import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/home_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/quran_screen.dart';
import '../screens/qibla_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/floating_navbar.dart';

/// Navigation principale avec design glassmorphism
/// Interface moderne avec navbar flottante et animations liquides
class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _fabController;

  final List<Widget> _screens = [
    const HomeScreen(),
    const QuranScreen(),
    const QiblaScreen(),
    const QuizScreen(),
    const ProfileScreen(),
  ];

  final List<FloatingNavItem> _navItems = [
    FloatingNavItem(icon: Icons.home_rounded, label: 'Accueil'),
    FloatingNavItem(icon: Icons.menu_book_rounded, label: 'Coran'),
    FloatingNavItem(icon: Icons.explore_rounded, label: 'Qibla'),
    FloatingNavItem(icon: Icons.quiz_rounded, label: 'Quiz'),
    FloatingNavItem(icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fabController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    
    // Configuration de la barre de statut
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Arrière-plan animé avec effet glassmorphism
          AnimatedGlassBackground(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: _screens,
            ),
          ),
          
          // Navbar flottante moderne
          FloatingGlassNavBar(
            selectedIndex: _selectedIndex,
            onItemTapped: _onItemTapped,
            items: _navItems,
          ),
          
          // FAB glassmorphism (optionnel, peut être activé selon les besoins)
          if (_selectedIndex == 2) // Afficher sur la page Qibla par exemple
            GlassFloatingActionButton(
              onPressed: () {
                // Action du FAB selon le contexte
                _showGlassDialog(context);
              },
              tooltip: 'Actualiser',
              child: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
        ],
      ),
    );
  }

  /// Dialog moderne avec effet glassmorphism
  void _showGlassDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 25,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_rounded,
                size: 48,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Actualiser la Qibla',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Recalculer la direction de la Mecque avec votre position actuelle ?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDialogButton(
                    'Annuler',
                    () => Navigator.pop(context),
                    isSecondary: true,
                  ),
                  _buildDialogButton(
                    'Actualiser',
                    () {
                      Navigator.pop(context);
                      // Logique d'actualisation
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton(String text, VoidCallback onPressed, {bool isSecondary = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: isSecondary
                ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
                : [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.1)],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}