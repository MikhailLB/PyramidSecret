import 'package:flutter/material.dart';

class AppColors {
  static const Color darkNavy = Color(0xFF0A1128);
  static const Color gold = Color(0xFFD4A24C);
  static const Color goldBright = Color(0xFFF2C464);
  static const Color sand = Color(0xFFE7C68C);
  static const Color shadow = Color(0x99000000);
}

class AppAssets {
  static const String menuBg = 'assets/menubg.webp';
  static const String loadingBg = 'assets/loading.jpg';
  static const String verticalLoading = 'assets/vertical_loadingg.png';
  static const String icon = 'assets/icons.jpg';
  static const String rock = 'assets/rock.png';
  static const String nothing = 'assets/nothing.webp';
  static const String money = 'assets/money.webp';
  static const String death = 'assets/death.webp';
  static const String egyptFlag = 'assets/Egypt.webp';
  static const String frame = 'assets/Frame 2.webp';
}

/// Draws a bordered "Egyptian tablet" button.
class EgyptButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;
  final IconData? icon;

  const EgyptButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 260,
    this.height = 62,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB07B2A), Color(0xFF7A4E14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.goldBright, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.goldBright, size: 22),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
