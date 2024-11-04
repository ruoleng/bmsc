import 'package:bmsc/model/fav.dart';
import 'package:flutter/material.dart';
import 'package:bmsc/globals.dart' as globals;
import 'package:bmsc/component/select_favlist_dialog.dart';

class SelectMultiFavlistDialog extends StatefulWidget {
  final int? aid;

  const SelectMultiFavlistDialog({super.key, this.aid});

  @override
  State<SelectMultiFavlistDialog> createState() =>
      _SelectMultiFavlistDialogState();
}

class _SelectMultiFavlistDialogState extends State<SelectMultiFavlistDialog> {
  List<Fav> favs = [];
  final Map<int, bool> _pendingFavStates = {};
  int defaultFolderId = 0;

  @override
  void initState() {
    super.initState();
    _loadFavs();
  }

  void _loadFavs() async {
    final uid = await globals.api.getStoredUID() ?? 0;
    final f = await globals.api.getFavs(uid, rid: widget.aid) ?? [];
    final df = await globals.api.getDefaultFavFolder();
    setState(() {
      favs = f;
      defaultFolderId = df?['id'] ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择收藏夹'),
      content: SizedBox(
        width: double.maxFinite,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              children: [
                createFavFolderListTile(context, false, callback: (folder) {
                  setDialogState(() {
                    favs.insert(0, folder);
                    _pendingFavStates[folder.id] = true;
                  });
                }),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: favs.length,
                    itemBuilder: (context, index) {
                      final folder = favs[index];
                      final isSelected =
                          _pendingFavStates.containsKey(folder.id)
                              ? _pendingFavStates[folder.id]!
                              : folder.favState == 1;
                      return CheckboxListTile(
                        title: Row(
                          children: [
                            Text(folder.title),
                            if (defaultFolderId == folder.id)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '默认',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            _pendingFavStates[folder.id] = value!;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _pendingFavStates.clear();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final toAdd = <int>[];
            final toRemove = <int>[];

            _pendingFavStates.forEach((folderId, newState) {
              final originalState =
                  favs.firstWhere((f) => f.id == folderId).favState == 1;

              if (newState != originalState) {
                if (newState) {
                  toAdd.add(folderId);
                } else {
                  toRemove.add(folderId);
                }
              }
            });

            Navigator.pop(context, {
              'toAdd': toAdd,
              'toRemove': toRemove,
            });
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
