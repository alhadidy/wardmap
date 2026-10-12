import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../record_sections.dart';
import '../roles.dart';
import '../ui.dart';

/// Images and videos on one lab or imaging result: a photo of a lab report,
/// CT slices, an echo clip. Anyone who can see the patient can open them;
/// editors can add more (camera or gallery) and remove them. Removed files
/// stay in the History tab.
class ResultFilesSheet extends StatefulWidget {
  const ResultFilesSheet({
    super.key,
    required this.result,
    required this.me,
    required this.canEdit,
    required this.staff,
  });

  final Map<String, dynamic> result;
  final Staff me;
  final bool canEdit;
  final List<Staff> staff;

  /// Number of files on a result row loaded with `result_files(count)`.
  static int countOn(Map<String, dynamic> row) =>
      ((row['result_files'] as List?)?.firstOrNull?['count'] as int?) ?? 0;

  @override
  State<ResultFilesSheet> createState() => _ResultFilesSheetState();
}

/// The bucket allows 50 MB per file; checked here too for a clear message.
const _maxBytes = 50 * 1024 * 1024;

class _ResultFilesSheetState extends State<ResultFilesSheet> {
  late Future<_Files> _files = _load();
  String? _uploading;

  Future<_Files> _load() async {
    final rows = await Api.resultFiles(widget.result['id']);
    final links = await Api.fileLinks([
      for (final r in rows) r['path'] as String,
    ]);
    return (rows: rows, links: links);
  }

  void _reload() => setState(() => _files = _load());

  Future<void> _add(Future<List<XFile>> Function(ImagePicker) pick) async {
    final List<XFile> picked;
    try {
      picked = await pick(ImagePicker());
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
      return;
    }
    for (final (i, file) in picked.indexed) {
      if (!mounted) return;
      setState(() => _uploading = 'Uploading ${i + 1} of ${picked.length}…');
      final type = file.mimeType ?? _typeFromName(file.name);
      final ok = await runAction(context, () async {
        if (type == null) {
          throw Exception('Only images and videos can be added.');
        }
        if (await file.length() > _maxBytes) {
          throw Exception('${file.name} is too big (50 MB at most).');
        }
        await Api.addResultFile(
          hospitalId: widget.me.hospitalId,
          patientId: widget.result['patient_id'],
          resultId: widget.result['id'],
          fileName: file.name,
          contentType: type,
          bytes: await file.readAsBytes(),
        );
      }, 'Added ${file.name}');
      if (!ok) break;
    }
    if (mounted) setState(() => _uploading = null);
    _reload();
  }

  Future<void> _open(Map<String, dynamic> file, String? link) async {
    if (link == null) return;
    final removed = await showDialog<bool>(
      context: context,
      builder: (_) => _FileViewer(
        file: file,
        link: link,
        canEdit: widget.canEdit,
        who: staffLookup(widget.staff),
      ),
    );
    if (removed == true && mounted) {
      if (await runAction(
        context,
        () => Api.removeResultFile(file['id']),
        'Removed',
      )) {
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return AlertDialog(
      title: Text('${r['name']}: images and videos'),
      content: SizedBox(
        width: 480,
        child: FutureBuilder(
          future: _files,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(errorText(snapshot.error!));
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final (:rows, :links) = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No images or videos yet',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in rows)
                        _Thumbnail(
                          file: f,
                          link: links[f['path']],
                          onTap: () => _open(f, links[f['path']]),
                        ),
                    ],
                  ),
                  if (_uploading != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(_uploading!),
                        ],
                      ),
                    ),
                  if (widget.canEdit && _uploading == null) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _add((p) async {
                            final f = await p.pickImage(
                              source: ImageSource.camera,
                            );
                            return [?f];
                          }),
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Take photo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _add((p) async {
                            final f = await p.pickVideo(
                              source: ImageSource.camera,
                            );
                            return [?f];
                          }),
                          icon: const Icon(Icons.videocam),
                          label: const Text('Record video'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _add((p) => p.pickMultipleMedia()),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Choose files'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

typedef _Files = ({List<Map<String, dynamic>> rows, Map<String, String> links});

bool _isVideo(Map<String, dynamic> file) =>
    (file['content_type'] as String).startsWith('video/');

/// For files whose type the picker didn't report.
String? _typeFromName(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' || 'gif' || 'webp' || 'bmp' || 'heic' || 'heif' => 'image/$ext',
    'mp4' || 'webm' => 'video/$ext',
    'mov' => 'video/quicktime',
    'm4v' => 'video/x-m4v',
    '3gp' => 'video/3gpp',
    _ => null,
  };
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.file,
    required this.link,
    required this.onTap,
  });

  final Map<String, dynamic> file;
  final String? link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Icon(
      _isVideo(file) ? Icons.play_circle : Icons.image,
      size: 40,
      color: colors.onSurfaceVariant,
    );
    return Semantics(
      button: true,
      label: file['file_name'],
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 96,
          height: 96,
          color: colors.surfaceContainerHighest,
          child: _isVideo(file) || link == null
              ? placeholder
              : Image.network(
                  link!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

/// Full screen: pinch to zoom an image, or play a video. Pops true when the
/// user chooses to remove the file.
class _FileViewer extends StatelessWidget {
  const _FileViewer({
    required this.file,
    required this.link,
    required this.canEdit,
    required this.who,
  });

  final Map<String, dynamic> file;
  final String link;
  final bool canEdit;
  final StaffLookup who;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(file['file_name']),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Added by ${who(file['created_by'])} · ${when(file['created_at'])}',
              ),
            ),
          ),
          actions: [
            if (canEdit)
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(
                        context,
                        'Remove this file? It stays in the history.',
                        'Remove',
                      ) &&
                      context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
          ],
        ),
        backgroundColor: Colors.black,
        body: _isVideo(file)
            ? _VideoPlayer(link: link)
            : InteractiveViewer(
                maxScale: 8,
                child: Center(
                  child: Image.network(
                    link,
                    errorBuilder: (_, _, _) => const Text(
                      'Could not open this image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.link});

  final String link;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late final _video = VideoPlayerController.networkUrl(Uri.parse(widget.link));
  late final Future<void> _ready = _video.initialize().then((_) {
    _video.setLooping(true);
    _video.play();
  });

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Could not play this video',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _video.value.aspectRatio,
                  child: VideoPlayer(_video),
                ),
              ),
            ),
            VideoProgressIndicator(_video, allowScrubbing: true),
            ValueListenableBuilder(
              valueListenable: _video,
              builder: (context, value, _) => IconButton(
                color: Colors.white,
                iconSize: 40,
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () =>
                    value.isPlaying ? _video.pause() : _video.play(),
              ),
            ),
          ],
        );
      },
    );
  }
}
