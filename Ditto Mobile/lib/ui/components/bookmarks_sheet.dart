import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';

class BookmarksSheet extends StatelessWidget {
  final Function(String) onNavigate;

  const BookmarksSheet({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    final bookmarks = state.bookmarks;

    return Material(
      color: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Bookmarks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${bookmarks.length} saved', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: bookmarks.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_border, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('No bookmarks yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Tap the star icon in the address bar to save sites.', style: TextStyle(color: Colors.white30, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: bookmarks.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      final initial = bookmark.title.isNotEmpty ? bookmark.title[0].toUpperCase() : '?';

                      return Dismissible(
                        key: Key('bm_${bookmark.url}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          state.removeBookmark(index);
                        },
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                          ),
                          title: Text(bookmark.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(bookmark.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          onTap: () {
                            Navigator.pop(context); // Close the sheet
                            onNavigate(bookmark.url);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ));
  }
}
