import 'package:flutter/material.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:page_transition/page_transition.dart';
import 'package:task_management_app/presentation/pages/auth/login_page.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Lottie.asset(
        "assets/To-do splash.json",
        repeat: false, // Only play animation once
        width: 300,
        height: 300,
      ),
      nextScreen: const LoginPage(),
      splashIconSize: 250,
      duration: 3000, // Total time to show splash (ms)
      animationDuration: const Duration(
        milliseconds: 1000,
      ), // Fade transition duration
      splashTransition: SplashTransition.fadeTransition,
      pageTransitionType: PageTransitionType.fade,
      backgroundColor: Colors.white,
    );
  }
}
