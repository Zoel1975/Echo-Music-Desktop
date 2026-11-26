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

  // All formerly-placeholdered features are now real screens (see router.dart):
  // Podcasts, Canvas/Ambient, full Music Flow, export queue, and all
  // integration settings (Discord/Last.fm/Jellyfin/Listen Together/Extensions/
  // Song DNA). Kept as an empty catalog so route generation stays data-driven.
  static const features = <ComingSoonFeature>[];

  static ComingSoonFeature? byRoute(String route) {
    for (final f in features) {
      if ('/${f.route}' == route || f.route == route) return f;
    }
    return null;
  }
}
