import 'package:bmsc/model/entity.dart';
import 'package:flutter/material.dart';
import 'package:bmsc/cache_manager.dart';
import 'package:bmsc/globals.dart' as globals;
import 'package:bmsc/util/logger.dart';

final _logger = LoggerUtils.getLogger('ExcludedPartsDialog');

class ExcludedPartsDialog extends StatefulWidget {
  final String bvid;
  final String title;

  const ExcludedPartsDialog({
    super.key,
    required this.bvid,
    required this.title,
  });

  @override
  State<ExcludedPartsDialog> createState() => _ExcludedPartsDialogState();
}

class _ExcludedPartsDialogState extends State<ExcludedPartsDialog> {
  bool isLoading = true;
  List<Entity> entities = [];
  List<bool> modified = [];
  int skipped = 0;

  @override
  void initState() {
    super.initState();
    _loadExcludedParts();
  }

  Future<void> _loadExcludedParts() async {
    var es = await CacheManager.getEntities(widget.bvid);
    if (es.isEmpty) {
      _logger
          .info('entities of ${widget.bvid} not in cache, fetching from API');
      await globals.api.getVidDetail(bvid: widget.bvid);
      es = await CacheManager.getEntities(widget.bvid);
    }
    if (es.isNotEmpty) {
      setState(() {
        isLoading = false;
        modified = List.filled(es.length, false);
        entities = es;
        skipped = es.where((e) => e.excluded == 1).length;
      });
    }
  }

  void _toggleAll(bool include) {
    final modifiedCopy = List<bool>.from(modified);
    int s = 0;
    if (include) {
      for (var i = 0; i < modified.length; i++) {
        modifiedCopy[i] = entities[i].excluded == 1;
        skipped += entities[i].excluded == 0 ? 1 : 0;
      }
      s = 0;
    } else {
      for (var i = 0; i < modified.length; i++) {
        modifiedCopy[i] = !modified[i];
      }
      s = entities.length - skipped;
    }
    setState(() {
      modified = modifiedCopy;
      skipped = s;
    });
  }

  Future<void> _saveChanges() async {
    for (var i = 0; i < modified.length; i++) {
      if (!modified[i]) continue;
      if (entities[i].excluded == 1) {
        await CacheManager.removeExcludedPart(widget.bvid, entities[i].cid);
      } else {
        await CacheManager.addExcludedPart(widget.bvid, entities[i].cid);
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '${entities.length} 个分集，已跳过 $skipped 个',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('全选'),
                onPressed: () => _toggleAll(true),
              ),
              TextButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text('反选'),
                onPressed: () => _toggleAll(false),
              ),
            ],
          ),
        ],
      ),
      content: isLoading
          ? const Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
            ])
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                cacheExtent: 10000,
                shrinkWrap: true,
                itemCount: entities.length,
                itemBuilder: (context, index) {
                  final e = entities[index];
                  final isIncluded = (e.excluded == 0) ^ modified[index];

                  return InkWell(
                    onTap: () {
                      setState(() {
                        modified[index] = !modified[index];
                        skipped += isIncluded ? 1 : -1;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isIncluded
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.3)
                            : Theme.of(context)
                                .colorScheme
                                .errorContainer
                                .withOpacity(0.3),
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text('P${index + 1}'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.partTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isIncluded
                                        ? null
                                        : Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                Text(
                                  _formatDuration(e.duration),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () {
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            setState(() => isLoading = true);
            await _saveChanges();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
