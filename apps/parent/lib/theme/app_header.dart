import 'package:flutter/material.dart';

/// Kinetic Link logo for headers — same art as the Android launcher.
class KineticLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const KineticLogo({super.key, this.size = 28, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/icons/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Logo + title row for use as an [AppBar.title].
class AppHeader extends StatelessWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final Widget? leading;

  const AppHeader({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: centerTitle ? MainAxisSize.min : MainAxisSize.max,
      children: [
        const KineticLogo(size: 28),
        const SizedBox(width: 10),
        Flexible(
          child: Text(title, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
