import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';
import '../../core/models/hook_script.dart';
import 'sync_manager_sheet.dart';

class ScriptManagerSheet extends StatelessWidget {
  const ScriptManagerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    final scripts = state.hookScripts;

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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text('Local JS Hooking', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Workspace Sync',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.sync_alt, color: Colors.tealAccent, size: 22),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const SyncManagerSheet(),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => _showScriptEditor(context, null, null),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Hook', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: scripts.isEmpty
                ? const Center(
                    child: Text('No hook scripts defined', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    itemCount: scripts.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final script = scripts[index];
                      return Card(
                        color: const Color(0xFF2C2C2C),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      script.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Switch(
                                    value: script.isActive,
                                    activeThumbColor: Colors.tealAccent,
                                    onChanged: (val) => state.toggleHookScript(index, val),
                                  ),

                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Pattern: ${script.targetPattern}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.tealAccent),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                                    onPressed: () => _showScriptEditor(context, script, index),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit'),
                                  ),
                                  if (script.isDeletable)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                      onPressed: () => state.removeHookScript(index),
                                      icon: const Icon(Icons.delete, size: 16),
                                      label: const Text('Delete'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    ));
  }

  void _showScriptEditor(BuildContext context, HookScript? script, int? index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScriptEditorSheet(existingScript: script, index: index),
    );
  }
}

class _ScriptEditorSheet extends StatefulWidget {
  final HookScript? existingScript;
  final int? index;

  const _ScriptEditorSheet({this.existingScript, this.index});

  @override
  State<_ScriptEditorSheet> createState() => _ScriptEditorSheetState();
}

class _ScriptEditorSheetState extends State<_ScriptEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _patternController;
  late TextEditingController _codeController;
  final FocusNode _codeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingScript?.name ?? '');
    _patternController = TextEditingController(text: widget.existingScript?.targetPattern ?? '.*');
    _codeController = TextEditingController(
      text: widget.existingScript?.code ?? '// Write your JavaScript here\nconsole.log("Hooked!");',
    );
    _codeFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _saveScript(BrowserState state) {
    if (_nameController.text.isNotEmpty && _codeController.text.isNotEmpty) {
      final script = HookScript(
        id: widget.existingScript?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        targetPattern: _patternController.text.isEmpty ? '.*' : _patternController.text,
        code: _codeController.text,
        isActive: widget.existingScript?.isActive ?? true,
        isDeletable: widget.existingScript?.isDeletable ?? true,
      );

      if (widget.existingScript == null) {
        state.addHookScript(script);
      } else if (widget.index != null) {
        state.updateHookScript(widget.index!, script);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<BrowserState>();
    final bottomInsets = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInsets > 80;
    final isCodeEditing = isKeyboardOpen && _codeFocusNode.hasFocus;

    return Material(
      color: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        padding: EdgeInsets.only(
          bottom: bottomInsets + 12,
          left: 20, right: 20, top: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingScript == null ? 'Create JS Hook' : 'Edit JS Hook',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _saveScript(state),
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isCodeEditing)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code, size: 16, color: Colors.tealAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_nameController.text.isEmpty ? "Untitled Hook" : _nameController.text} (${_patternController.text.isEmpty ? ".*" : _patternController.text})',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _codeFocusNode.unfocus(),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Text('Edit Metadata', style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Script Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _patternController,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.tealAccent),
                decoration: const InputDecoration(
                  labelText: 'Target Pattern (Regex, Fixed Text, or Glob e.g. example.com/*.js)',
                  labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text('JS CODE (AT_DOCUMENT_START)', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Copy All',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.copy, size: 16, color: Colors.tealAccent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _codeController.text));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                      },
                    ),
                    IconButton(
                      tooltip: 'Paste',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.paste, size: 16, color: Colors.amberAccent),
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _codeController.text = data!.text!;
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Format',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.auto_fix_high, size: 16, color: Colors.blueAccent),
                      onPressed: () => setState(() => _codeController.text = _codeController.text.trim()),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCodeEditing ? Colors.tealAccent : Colors.white24),
                ),
                child: TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4, color: Colors.greenAccent),
                  decoration: const InputDecoration.collapsed(
                    hintText: '// Write or paste JavaScript code here...',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
