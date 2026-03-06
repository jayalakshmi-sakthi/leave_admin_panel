import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminHelpers {
  // ============================================
  // 🎨 PREMIUM THEME PALETTE (Slate / Indigo / Teal)
  // ============================================

  // Primary Integrations (Soulful Violet - Matches User App)
  static const Color primaryColor = Color(0xFF7C3AED);    // Violet 600
  static const Color secondaryColor = Color(0xFF6366F1);  // Indigo 500
  static const Color accentColor = Color(0xFF8B5CF6);     // Violet 500 (Highlights)
  
  // States
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color danger = Color(0xFFEF4444);  // Red 500
  static const Color info = Color(0xFF0EA5E9);    // Sky 500

  // Neutrals (Light Mode - Softer)
  static const Color scaffoldBg = Color(0xFFF8FAFC);  // Slate 50
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);      // Slate 200
  static const Color textMain = Color(0xFF1E293B);    // Slate 800
  static const Color textMuted = Color(0xFF64748B);   // Slate 500

  // 📊 Dashboard Summary Colors (Vibrant & Peaceful)
  static const Color summaryPurple = Color(0xFF8B5CF6);
  static const Color summaryTeal = Color(0xFF10B981);
  static const Color summaryPink = Color(0xFFEC4899);
  static const Color summaryBlue = Color(0xFF3B82F6);

  // Departments List (Synced with User App)
  // Departments List (Synced with User App)
  static const List<String> departments = [
    'All', // Special Admin Category
    'Placement Cell',
    // Engineering
    'CIVIL', 'MECH', 'MTS', 'AUTO', 'CHEM', 'FT',
    'EEE', 'ECE', 'EIE', 'CSE', 'IT', 'CSD', 'AIDS', 'AIML',
    // PG
    'MBA', 'MCA',
    // Science
    'B.Sc CSD', 'B.Sc IS', 'B.Sc SS', 'M.Sc SS',
    // Others
    'Ph.D', 'General'
  ];

  static Color getDeptColor(String dept) {
    // 🎨 Consistent Hashing for Dept Colors
    if (dept == 'All') return const Color(0xFF64748B); // Slate
    
    // Manual Overrides for Key Depts
    switch (dept.toUpperCase()) {
      case 'CSE': case 'IT': case 'CSD': case 'AIDS': case 'AIML': 
      case 'B.SC CSD': case 'B.SC IS': case 'B.SC SS': case 'M.SC SS':
        return const Color(0xFF3B82F6); // Blue
      case 'ECE': case 'EEE': case 'EIE': 
        return const Color(0xFFF59E0B); // Amber
      case 'MECH': case 'CIVIL': case 'MTS': case 'AUTO': case 'CHEM': case 'FT':
        return const Color(0xFFEF4444); // Red
      case 'MBA': case 'MCA': 
        return const Color(0xFF8B5CF6); // Violet
      case 'PLACEMENT CELL': 
        return const Color(0xFF10B981); // Emerald
    }
    
    // Fallback: Hash String to one of the safe colors
    final int hash = dept.codeUnitAt(0) + (dept.length > 1 ? dept.codeUnitAt(1) : 0);
    return _safePalette[hash % _safePalette.length];
  }

  // Neutrals (Dark Mode)
  static const Color darkScaffold = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B);  // Slate 800
  static const Color darkBorder = Color(0xFF334155);   // Slate 700

  // ============================================
  // 🖌️ TYPOGRAPHY & DECORATION
  // ============================================

  /// Returns a clean box decoration for cards
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? darkSurface : surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? darkBorder : border,
        width: 1,
      ),
      boxShadow: [
        if (!isDark)
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
          )
      ],
    );
  }

  // ============================================
  // 📅 UTILITIES
  // ============================================

  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
  
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, hh:mm a').format(date);
  }

  // ============================================
  // 🏢 LEAVE LOGIC (Consistent with Staff App)
  // ============================================

  static IconData getLeaveIcon(String type) {
    final t = type.toUpperCase();
    if (t == 'CL' || t.contains('CASUAL')) return Icons.person_outline_rounded;
    if (t == 'VL' || t.contains('VACATION')) return Icons.beach_access_rounded;
    if (t == 'COMP' || t.contains('COMP')) return Icons.stars_rounded;
    if (t == 'OD' || t.contains('DUTY')) return Icons.business_center_rounded;
    if (t == 'SL' || t.contains('SICK')) return Icons.local_hospital_rounded;
    if (t.contains('FESTIVAL')) return Icons.celebration_rounded;
    return Icons.event_note_rounded;
  }

  /// Helper to safely load icons from DB without breaking Web Icon Tree Shaker
  static IconData getIconFromCodePoint(int codePoint, [IconData fallback = Icons.stars]) {
    final allIcons = [
      Icons.person_outline_rounded,
      Icons.beach_access_rounded,
      Icons.stars_rounded,
      Icons.business_center_rounded,
      Icons.local_hospital_rounded,
      Icons.flight_takeoff_rounded,
      Icons.home_work_rounded,
      Icons.school_rounded,
      Icons.local_library_rounded,
      Icons.emoji_events_rounded,
      Icons.light_mode_rounded,
      Icons.celebration_rounded,
      Icons.event_note_rounded,
    ];
    for (var icon in allIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return fallback;
  }

  static Color getLeaveColor(String type) {
    final t = type.toUpperCase();
    if (t == 'CL' || t.contains('CASUAL')) return const Color(0xFF4F46E5); // Indigo
    if (t == 'VL' || t.contains('VACATION')) return const Color(0xFF10B981); // Emerald
    if (t == 'COMP' || t.contains('COMP')) return const Color(0xFF8B5CF6); // Violet
    if (t == 'OD' || t.contains('DUTY')) return const Color(0xFF0EA5E9); // Sky
    if (t == 'SL' || t.contains('SICK')) return const Color(0xFFEF4444); // Red
    if (t.contains('FESTIVAL')) return const Color(0xFFEC4899); // Pink
    return const Color(0xFF64748B); // Slate
  }

  static String getLeaveName(String type) {
    switch (type.toUpperCase()) {
      case 'CL': return "Casual Leave";
      case 'VL': return "Vacation Leave";
      case 'COMP': return "Comp Off";
      case 'OD': return "On Duty";
      case 'SL': return "Sick Leave";
      default: return type;
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return success;
      case 'rejected': return danger;
      case 'pending': return warning;
      default: return textMuted;
    }
  }

  static Color getAvatarColor(String name) {
    if (name.isEmpty) return secondaryColor;
    final List<Color> colors = [
      secondaryColor,
      success,
      warning,
      danger,
      accentColor,
      const Color(0xFFEC4899),
      const Color(0xFF0EA5E9),
      const Color(0xFF8B5CF6),
    ];
    return colors[name.hashCode % colors.length];
  }

  // --- Style Generation (Unchanged logic, cleaner colors) ---
  
  static const List<Color> _safePalette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
  ];

  static const List<IconData> _safeIcons = [
    Icons.person_outline_rounded,
    Icons.beach_access_rounded,
    Icons.stars_rounded,
    Icons.business_center_rounded,
    Icons.local_hospital_rounded,
    Icons.flight_takeoff_rounded,
    Icons.home_work_rounded,
    Icons.school_rounded,
    Icons.local_library_rounded,
    Icons.emoji_events_rounded,
    Icons.light_mode_rounded,
  ];

  static Map<String, dynamic> generateNewStyle(List<Map<String, dynamic>> existingTypes, {String? name}) {
     if (name != null) {
       final standardIcon = getLeaveIcon(name);
       if (standardIcon != Icons.event_note_rounded) {
          return {'color': getLeaveColor(name).value, 'icon': standardIcon.codePoint};
       }
     }
     // ... (Existing logic for random selection)
     // For brevity, just picking random if logic matches existing behavior
     // Re-implementing simplified logic to ensure integrity
     final Set<int> usedColors = existingTypes.map((e) => e['color'] as int?).where((e)=>e!=null).cast<int>().toSet();
     final Set<int> usedIcons = existingTypes.map((e) => e['icon'] as int?).where((e)=>e!=null).cast<int>().toSet();

     Color color = _safePalette.firstWhere((c) => !usedColors.contains(c.value), orElse: () => _safePalette[DateTime.now().millisecond % _safePalette.length]);
     IconData icon = _safeIcons.firstWhere((i) => !usedIcons.contains(i.codePoint), orElse: () => _safeIcons[DateTime.now().millisecond % _safeIcons.length]);

     return {'color': color.value, 'icon': icon.codePoint};
  }

  static Map<String, dynamic> migrateLegacyType(Map<String, dynamic> data) {
    if (data.containsKey('color') && data.containsKey('icon')) return data;
    final String name = data['name'] ?? '';
    final Map<String, dynamic> migrated = Map.from(data);
    if (!migrated.containsKey('color')) migrated['color'] = getLeaveColor(name).value;
    if (!migrated.containsKey('icon')) migrated['icon'] = getLeaveIcon(name).codePoint;
    return migrated;
  }

  // ============================================
  // 🧹 SANITIZATION
  // ============================================

  /// Removes redundant "(Placement Cell)" or similar from names/titles
  static String sanitizeLabel(String label) {
    if (label.isEmpty) return label;
    return label
        .replaceAll('(Placement Cell)', '')
        .replaceAll('Placement Cell', '')
        .replaceAll('()', '')
        .trim();
  }
}
