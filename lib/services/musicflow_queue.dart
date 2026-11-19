/// Port of Android `musicflow/MusicFlowQueue.kt`.
import 'package:Echo/services/musicflow_ranking.dart';
import 'package:Echo/services/musicflow_session.dart';

class MusicFlowQueue {
  MusicFlowQueue({required this.session, required this.title});

  final MusicFlowSession session;
  final String? title;

  List<MusicFlowItem> get items => session.items;

  int get initialIndex =>
      session.indexOf(session.currentSelectedId).clamp(0, session.items.isEmpty ? 0 : session.items.length - 1);

  Future<List<MusicFlowItem>> nextPage() async {
    await session.loadMore();
    return session.items;
  }
}
