import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';

class HistorySheet extends StatelessWidget {
  final Function(String) onNavigate;

  const HistorySheet({super.key, required this.onNavigate});

  void _showClearConfirmation(BuildContext context, BrowserState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Clear History?'),
        content: const Text('This will permanently delete all your browsing history. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              state.clearVisitedHistory();
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          )
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  String _formatDate(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(time.year, time.month, time.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    final history = state.visitedHistory;

    return Material(
      color: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
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
                const Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                if (history.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showClearConfirmation(context, state),
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                    label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                  )
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('No history yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      // Determine if we need to show a date header
                      bool showHeader = false;
                      if (index == 0) {
                        showHeader = true;
                      } else {
                        final prevItem = history[index - 1];
                        if (_formatDate(item.timestamp) != _formatDate(prevItem.timestamp)) {
                          showHeader = true;
                        }
                      }

                      Widget tile = Dismissible(
                        key: Key('hist_${item.url}_${item.timestamp.millisecondsSinceEpoch}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          state.removeHistoryItem(index);
                        },
                        child: ListTile(
                          leading: const Icon(Icons.language, color: Colors.white38),
                          title: Text(item.title.isEmpty ? item.url : item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: Text(_formatTime(item.timestamp), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          onTap: () {
                            Navigator.pop(context); // Close the sheet
                            onNavigate(item.url);
                          },
                        ),
                      );

                      if (showHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 24.0, top: 16.0, bottom: 8.0, right: 24.0),
                              child: Text(_formatDate(item.timestamp), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent, fontSize: 14)),
                            ),
                            tile,
                          ],
                        );
                      }
                      
                      return tile;
                    },
                  ),
          ),
        ],
      ),
    ));
  }
}
