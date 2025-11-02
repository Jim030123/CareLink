import 'package:flutter/material.dart';

class Service {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  Service({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });
}