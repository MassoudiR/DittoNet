import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';

void showTabSwitcherSheet(BuildContext context, {required VoidCallback onTabSwitched}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TabSwitcherSheet(onTabSwitched: onTabSwitched),
  );
}

class TabSwitcherSheet extends StatelessWidget {
  final VoidCallback onTabSwitched;

  const TabSwitcherSheet({super.key, required this.onTabSwitched});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    final tabs = state.tabs;

    return Material(
      color: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Open Tabs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('${tabs.length} tabs', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).padding.bottom + 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final isActive = index == state.currentTabIndex;
                      final host = tab.url.isEmpty || tab.url == 'about:blank' ? 'Home Dashboard' : state.getHostFromUrl(tab.url);

                      return GestureDetector(
                        onTap: () {
                          state.switchTab(index);
                          Navigator.pop(context);
                          onTabSwitched();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF222230),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive ? Colors.tealAccent : Colors.white12,
                              width: isActive ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header with Title and Close button
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tab.title.isEmpty ? host : tab.title,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () {
                                        state.closeTab(index);
                                        onTabSwitched();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // Thumbnail Preview
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                                  child: tab.screenshot != null
                                      ? Image.memory(
                                          tab.screenshot!,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.topCenter,
                                        )
                                      : Container(
                                          color: const Color(0xFF181824),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  tab.url.isEmpty ? Icons.home_rounded : Icons.public_rounded,
                                                  color: Colors.white24,
                                                  size: 36,
                                                ),
                                                const SizedBox(height: 8),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  child: Text(
                                                    host,
                                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Floating New Tab Button
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              right: 24,
              child: FloatingActionButton.extended(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                elevation: 6,
                icon: const Icon(Icons.add_rounded, size: 24),
                label: const Text('New Tab', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  state.addNewTab();
                  Navigator.pop(context);
                  onTabSwitched();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
