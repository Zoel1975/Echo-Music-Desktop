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

  static const features = [
    ComingSoonFeature(
      'podcasts',
      'Podcasts',
      'Podcast home, episodes and subscriptions from the mobile app are '
      'planned for a future update.',
    ),
    ComingSoonFeature(
      'canvas_ambient',
      'Canvas & Ambient mode',
      'Animated album canvas and the immersive ambient player are planned '
      'for a future update.',
    ),
    ComingSoonFeature(
      'music_flow_full',
      'Music Flow',
      'The full Resso-style vertical swipe discovery feed with AI mixes is '
      'planned for a future update.',
    ),
    ComingSoonFeature(
      'song_dna',
      'Song DNA',
      'Genius / Wikipedia song metadata is planned for a future update.',
    ),
    ComingSoonFeature(
      'export_queue',
      'Export as MP3',
      'The background export task queue is planned for a future update.',
    ),
  ];

  static ComingSoonFeature? byRoute(String route) {
    for (final f in features) {
      if ('/${f.route}' == route || f.route == route) return f;
    }
    return null;
  }
}
