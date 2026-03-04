import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roamly/core/themes/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.poppins()),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildThemeSection(context),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 24, color: isDark ? Colors.white70 : Colors.grey[700]),
              const SizedBox(width: 12),
              Text(
                'Appearance',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeProvider.themeNotifier,
            builder: (context, currentMode, _) {
              return Column(
                children: [
                  _ThemeRadioOption(
                    title: 'System Default',
                    value: ThemeMode.system,
                    groupValue: currentMode,
                    icon: Icons.brightness_auto,
                  ),
                  _ThemeRadioOption(
                    title: 'Light',
                    value: ThemeMode.light,
                    groupValue: currentMode,
                    icon: Icons.light_mode,
                  ),
                  _ThemeRadioOption(
                    title: 'Dark',
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                    icon: Icons.dark_mode,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeRadioOption extends StatelessWidget {
  final String title;
  final ThemeMode value;
  final ThemeMode groupValue;
  final IconData icon;

  const _ThemeRadioOption({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RadioListTile<ThemeMode>(
      title: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ],
      ),
      value: value,
      groupValue: groupValue,
      onChanged: (ThemeMode? newMode) {
        if (newMode != null) {
          ThemeProvider.setThemeMode(newMode);
        }
      },
      contentPadding: EdgeInsets.zero,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
