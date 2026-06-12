import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Widget buildGoogleSignInButton({required VoidCallback onPressed}) {
  return ElevatedButton.icon(
    onPressed: onPressed,
    icon: const FaIcon(FontAwesomeIcons.google, size: 18),
    label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.bold)),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF4285F4),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 0,
    ),
  );
}
