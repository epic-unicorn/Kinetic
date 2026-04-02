import 'package:flutter/material.dart';

/// Kinetic app logo/icon widget for use in headers (kids version - fun colors)
class KineticLogoKids extends StatelessWidget {
  final double size;
  final Color? color;

  const KineticLogoKids({Key? key, this.size = 28, this.color})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF97316), // Orange
            const Color(0xFFEC4899), // Pink
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Center(
        child: Text(
          'K',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// App header widget with logo and title (kids version)
class AppHeaderKids extends StatelessWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final Widget? leading;

  const AppHeaderKids({
    Key? key,
    required this.title,
    this.centerTitle = false,
    this.actions,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        const KineticLogoKids(size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    );
  }
}
