import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';
import '../../models/bookmark.dart';
import '../dittoman_screen.dart';

class HomeDashboardWidget extends StatefulWidget {
  final Function(String) onNavigate;

  const HomeDashboardWidget({super.key, required this.onNavigate});

  @override
  State<HomeDashboardWidget> createState() => _HomeDashboardWidgetState();
}

class _HomeDashboardWidgetState extends State<HomeDashboardWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isDITTOMANTriggered = false;
  late AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDITTOMANTriggered) {
        _triggerDITTOMANEasterEgg();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onHoldStart(TapDownDetails details) {
    if (_isDITTOMANTriggered) return;
    HapticFeedback.selectionClick();
    _holdController.forward(from: 0.0);
  }

  void _onHoldCancel() {
    if (_isDITTOMANTriggered) return;
    _holdController.reverse();
  }

  void _triggerDITTOMANEasterEgg() async {
    if (_isDITTOMANTriggered) return;
    setState(() => _isDITTOMANTriggered = true);
    
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 10,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 2),
        ),
        backgroundColor: const Color(0xFF161622).withValues(alpha: 0.95),
        content: const Row(
          children: [
            Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚡ DITTOMAN UNLOCKED', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Entering Standalone REST Client...', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 1200),
      )
    );

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const DittomanScreen(),
        transitionsBuilder: (context, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      )
    );
    if (mounted) {
      setState(() => _isDITTOMANTriggered = false);
      _holdController.reset();
    }
  }

  void _handleSearchSubmit(String query) {
    if (query.isEmpty) return;
    String finalUrl;
    
    if (query.startsWith('file://') || query.startsWith('asset://') || query.startsWith('about:') || query.startsWith('data:')) {
      finalUrl = query;
    } else if (!query.contains(' ') && query.contains('.')) {
      if (!query.startsWith('http://') && !query.startsWith('https://')) {
        finalUrl = 'https://$query';
      } else {
        finalUrl = query;
      }
    } else {
      // Treat as search query
      final encodedQuery = Uri.encodeComponent(query);
      finalUrl = 'https://www.google.com/search?q=$encodedQuery';
    }
    widget.onNavigate(finalUrl);
  }

  void _showAddBookmarkModal(BuildContext context) {
    final titleController = TextEditingController();
    final urlController = TextEditingController(text: 'https://');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Quick Link', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Site Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder()),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                      context.read<BrowserState>().addBookmark(BookmarkItem(title: titleController.text, url: urlController.text));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Link'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  void _showEditDeleteModal(BuildContext context, int index, BookmarkItem bookmark) {
    final titleController = TextEditingController(text: bookmark.title);
    final urlController = TextEditingController(text: bookmark.url);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Quick Link', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      context.read<BrowserState>().removeBookmark(index);
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Site Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder()),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                      context.read<BrowserState>().updateBookmark(index, BookmarkItem(title: titleController.text, url: urlController.text));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Update Link'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    
    return Container(
      color: const Color(0xFF121212),
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            GestureDetector(
              onTapDown: _onHoldStart,
              onTapUp: (_) => _onHoldCancel(),
              onTapCancel: _onHoldCancel,
              child: Column(
                children: [
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _holdController,
                      builder: (context, child) {
                        return MagicalStarsOverlay(
                          holdProgress: _holdController.value,
                          child: child!,
                        );
                      },
                      child: Image.asset('assets/ditto_logo.png', height: 90),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DITTONET BROWSER',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Smart Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Search Google or type a URL',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onSubmitted: _handleSearchSubmit,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Quick Links Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.72,
                ),
                itemCount: state.bookmarks.length + 1, // +1 for the Add button
                itemBuilder: (context, index) {
                  if (index == state.bookmarks.length) {
                    // Add Button Tile
                    return GestureDetector(
                      onTap: () => _showAddBookmarkModal(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 58, height: 58,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          const Flexible(child: Text('Add Link', style: TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        ],
                      ),
                    );
                  }
                  
                  final link = state.bookmarks[index];
                  final initial = link.title.isNotEmpty ? link.title[0].toUpperCase() : '?';
                  
                  return GestureDetector(
                    onTap: () => widget.onNavigate(link.url),
                    onLongPress: () => _showEditDeleteModal(context, index, link),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58, height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          alignment: Alignment.center,
                          child: Text(initial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                        ),
                        const SizedBox(height: 6),
                        Flexible(child: Text(link.title, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Extra padding at the bottom so the floating navbar doesn't cover the lowest elements
            const SizedBox(height: 85),
          ],
        ),
      ),
    );
  }
}

class MagicalStarsOverlay extends StatelessWidget {
  final double holdProgress;
  final Widget child;

  const MagicalStarsOverlay({super.key, required this.holdProgress, required this.child});

  @override
  Widget build(BuildContext context) {
    if (holdProgress <= 0.0) return child;

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MagicalStarsPainter(holdProgress: holdProgress),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _MagicalStarsPainter extends CustomPainter {
  final double holdProgress;

  _MagicalStarsPainter({required this.holdProgress});

  @override
  void paint(Canvas canvas, Size size) {
    if (holdProgress <= 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    const int totalStars = 24;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < totalStars; i++) {
      final double startT = (i / totalStars) * 0.55;
      if (holdProgress < startT) continue;

      final double angle = (i * 137.508) * (math.pi / 180.0);
      final double speedMultiplier = 1.0 + math.pow(holdProgress, 2.0) * 4.0;
      final double rawProgress = (holdProgress - startT) / (1.0 - startT);
      final double cycle = (rawProgress * speedMultiplier) % 1.0;

      const double minDistance = 46.0;
      final double travelDistance = 60.0 + (holdProgress * 130.0) + ((i % 4) * 25.0);
      final double distance = minDistance + (cycle * travelDistance);

      final double dx = center.dx + distance * math.cos(angle);
      final double dy = center.dy + distance * math.sin(angle);

      double opacity = 1.0;
      if (cycle < 0.15) {
        opacity = cycle / 0.15;
      } else if (cycle > 0.65) {
        opacity = (1.0 - cycle) / 0.35;
      }
      opacity = opacity.clamp(0.0, 1.0);

      paint.color = Colors.white.withValues(alpha: opacity);

      final double starRadius = (7.0 + (i % 3) * 3.0);
      final double rotation = cycle * math.pi * 2.0;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(rotation);

      final path = Path();
      const int points = 4;
      final double innerRadius = starRadius * 0.38;
      for (int p = 0; p < points * 2; p++) {
        final double r = (p % 2 == 0) ? starRadius : innerRadius;
        final double theta = p * math.pi / points;
        if (p == 0) {
          path.moveTo(r * math.cos(theta), r * math.sin(theta));
        } else {
          path.lineTo(r * math.cos(theta), r * math.sin(theta));
        }
      }
      path.close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MagicalStarsPainter oldDelegate) {
    return oldDelegate.holdProgress != holdProgress;
  }
}
