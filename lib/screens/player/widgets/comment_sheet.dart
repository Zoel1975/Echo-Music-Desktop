import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../services/comments_service.dart';
import '../../../services/media_player.dart';

/// Port of Android `CommentSheet.kt`: a modal sheet listing YouTube comments
/// for the playing song, with a replies view.
class CommentSheet extends StatefulWidget {
  const CommentSheet({required this.videoId, super.key});

  final String videoId;

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CommentSheet(
          videoId: GetIt.I<MediaPlayer>().currentSongNotifier.value?.id ?? '',
        ),
      );

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  Future<CommentPage>? _future;

  @override
  void initState() {
    super.initState();
    _future = CommentsService.instance.fetch(widget.videoId);
  }

  @override
  Widget build(BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  Text('Commenti',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<CommentPage>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final comments = snapshot.data!.comments;
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text('Nessun commento disponibile'),
                      );
                    }
                    return ListView.separated(
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) =>
                          _commentTile(context, comments[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

  Widget _commentTile(BuildContext context, YtComment c) => ListTile(
        leading: c.avatarUrl == null
            ? const CircleAvatar(child: Icon(Icons.person))
            : CircleAvatar(
                backgroundImage: NetworkImage(c.avatarUrl!),
                onBackgroundImageError: (_, __) {},
              ),
        title: Text(c.author,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.published != null)
              Text(c.published!,
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(c.text),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.thumb_up_outlined, size: 14),
                const SizedBox(width: 4),
                Text(c.voteCount),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.reply, size: 16),
                  tooltip: 'Risposte',
                  onPressed: () => _showReplies(context, c),
                ),
                Text('${c.replyCount ?? 0}'),
              ],
            ),
          ],
        ),
      );

  void _showReplies(BuildContext context, YtComment c) {
    // Replies need the thread token, which is only present on threads returned
    // by a continuation. Show the (already loaded) comment thread directly.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Risposte'),
                onTap: () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(c.author,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(c.text),
                    const Divider(height: 24),
                    const Text('Nessun\'altra risposta caricata'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
