import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable profile image widget with optional border.
/// Displays a network image or a letter-avatar fallback.
class ProfileImageWidget extends StatelessWidget {
  final String? photoUrl;
  final String fallbackLetter;
  final double size;
  final Color borderColor;
  final double borderWidth;

  const ProfileImageWidget({
    super.key,
    required this.photoUrl,
    required this.fallbackLetter,
    this.size = 64,
    this.borderColor = Colors.white,
    this.borderWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(
                photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => _buildLetterAvatar(),
              )
            : _buildLetterAvatar(),
      ),
    );
  }

  Widget _buildLetterAvatar() {
    return Container(
      color: Colors.white.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        fallbackLetter[0].toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
