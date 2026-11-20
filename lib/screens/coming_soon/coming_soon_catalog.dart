/// Catalog of mobile features not yet feasible on desktop. Each entry has a
/// stable route and an honest "coming in a future update" message, so no
/// parity-matrix row is a dead end — every feature is reachable.
class ComingSoonFeature {
  const ComingSoonFeature(this.route, this.title, this.message);
  final String route;
  final String title;
  final String message;
}

class ComingSoonCatalog {
  ComingSoonCatalog._();

  // Podcasts, Canvas/Ambient, full Music Flow and the export queue are now
  // real screens (see router.dart). Only genuinely infeasible features remain.
  static const features = [
    ComingSoonFeature(
      'song_dna',
      'Song DNA',
      'Genius / Wikipedia song metadata is planned for a future update.',
    ),
  ];

  static ComingSoonFeature? byRoute(String route) {
    for (final f in features) {
      if ('/${f.route}' == route || f.route == route) return f;
    }
    return null;
  }
}
