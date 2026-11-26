import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// OpenStreetMap xəritə istifadə şərti: "© OpenStreetMap contributors" həmişə görünməlidir.
/// FlutterMap `children` siyahısının SONUNA əlavə edin (markerlərin üstündə qalsın).
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomRight,
        child: GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          ),
          child: Container(
            color: Colors.white.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
