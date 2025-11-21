import 'package:fatora/screens/auth_screen.dart';
import 'package:fatora/screens/dashboard_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading indicator while waiting for the auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If the user is logged in, show the dashboard
        if (snapshot.hasData) {
          return const DashboardPage();
        }

        // Otherwise, show the auth screen
        return const AuthScreen();
      },
    );
  }
}
