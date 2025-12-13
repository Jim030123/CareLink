import 'package:flutter/material.dart';

class Service {
  final String title;
  final String subtitle;
  final IconData icon;
  final MaterialColor color;
  final VoidCallback? onTap;

  Service({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
}