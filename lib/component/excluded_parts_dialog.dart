import 'package:flutter/material.dart';
import 'package:bmsc/cache_manager.dart';
import 'package:bmsc/model/vid.dart';
import 'package:bmsc/globals.dart' as globals;

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
  Set<int> excludedCids = {};
  Set<int> pendingExcludedCids = {};
  bool isLoading = true;
  List<Pages> pages = [];

  @override
  void initState() {
    super.initState();
    _loadExcludedParts();
  }

  Future<void> _loadExcludedParts() async {
    final entities = await CacheManager.getEntities(widget.bvid);
    if (entities.isNotEmpty) {
      setState(() {
        excludedCids =
            entities.where((e) => e.excluded == 1).map((e) => e.cid).toSet();
        pendingExcludedCids = {...excludedCids};
        isLoading = false;
        pages = entities
            .map((e) => Pages(
                cid: e.cid,
                page: e.part,
                duration: e.duration,
                from: e.artist,
                part: e.partTitle))
            .toList();
      });
    } else {
      try {
        final vid = await globals.api.getVidDetail(widget.bvid);
        if (vid == null) return;
        final excluded = await CacheManager.getExcludedParts(widget.bvid);
        setState(() {
          excludedCids = excluded.toSet();
          pendingExcludedCids = {...excludedCids};
          pages = vid.pages;
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _toggleAll(bool include) {
    setState(() {
      if (include) {
        pendingExcludedCids.clear();
      } else {
        pendingExcludedCids = pages.map((p) => p.cid).toSet();
      }
    });
  }

  Future<void> _saveChanges() async {
    final toExclude = pendingExcludedCids.difference(excludedCids);
    final toInclude = excludedCids.difference(pendingExcludedCids);

    for (var cid in toExclude) {
      await CacheManager.addExcludedPart(widget.bvid, cid);
    }
    for (var cid in toInclude) {
      await CacheManager.removeExcludedPart(widget.bvid, cid);
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
            '${pages.length} 个分集，已跳过 ${pendingExcludedCids.length} 个',
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
                shrinkWrap: true,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final page = pages[index];
                  final isIncluded = !pendingExcludedCids.contains(page.cid);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isIncluded) {
                          pendingExcludedCids.add(page.cid);
                        } else {
                          pendingExcludedCids.remove(page.cid);
                        }
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
                                  page.part,
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
                                  _formatDuration(page.duration),
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
