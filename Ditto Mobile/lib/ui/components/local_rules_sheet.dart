import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';
import '../../core/models/local_rule.dart';
import 'sync_manager_sheet.dart';

class LocalRulesSheet extends StatelessWidget {
  const LocalRulesSheet({super.key});

  Color _getActionBadgeColor(String actionType) {
    switch (actionType) {
      case 'BLOCK':
        return Colors.redAccent;
      case 'REDIRECT':
        return Colors.orangeAccent;
      case 'HEADER_INJECT':
        return Colors.purpleAccent;
      case 'MATCH_REPLACE':
        return Colors.tealAccent;
      case 'BODY_REPLACE':
        return Colors.blueAccent;
      default:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    final rules = state.localRules;

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
                  child: Text('Local Rule Engine', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                      onPressed: () => _showRuleEditor(context, null, null),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: rules.isEmpty
                ? const Center(
                    child: Text('No local rules defined', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    itemCount: rules.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      final badgeColor = _getActionBadgeColor(rule.actionType);

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
                                      rule.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Switch(
                                    value: rule.isActive,
                                    activeThumbColor: Colors.tealAccent,
                                    onChanged: (val) => state.toggleLocalRule(index, val),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withAlpha(51),
                                      border: Border.all(color: badgeColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      rule.actionType,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Phase: ${rule.phase}',
                                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Method: ${rule.method}',
                                      style: const TextStyle(fontSize: 10, color: Colors.amberAccent),
                                    ),
                                  ),

                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Pattern: ${rule.targetPattern}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.tealAccent),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.white70),
                                    onPressed: () => _showRuleEditor(context, rule, index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                    onPressed: () => state.removeLocalRule(index),
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
        ],
      ),
    ));
  }

  void _showRuleEditor(BuildContext context, LocalRule? existingRule, int? index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocalRuleEditorDialog(existingRule: existingRule, index: index),
    );
  }
}

class _LocalRuleEditorDialog extends StatefulWidget {
  final LocalRule? existingRule;
  final int? index;

  const _LocalRuleEditorDialog({this.existingRule, this.index});

  @override
  State<_LocalRuleEditorDialog> createState() => _LocalRuleEditorDialogState();
}

class _LocalRuleEditorDialogState extends State<_LocalRuleEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _patternController;
  late TextEditingController _matchController;
  late TextEditingController _replaceController;

  String _selectedPhase = 'Both';
  String _selectedAction = 'BLOCK';
  String _selectedMethod = 'ALL';
  bool _isRegex = false;

  final List<String> _phases = ['Request', 'Response', 'Both'];
  final List<String> _methods = ['ALL', 'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'];
  final List<String> _actions = ['BLOCK', 'REDIRECT', 'HEADER_INJECT', 'MATCH_REPLACE', 'BODY_REPLACE'];

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _patternController = TextEditingController(text: rule?.targetPattern ?? '.*');
    _selectedPhase = rule?.phase ?? 'Both';
    _selectedAction = rule?.actionType ?? 'BLOCK';
    _selectedMethod = rule?.method ?? 'ALL';
    _isRegex = rule?.isRegex ?? false;

    if (_selectedAction == 'HEADER_INJECT' && rule?.replaceString != null) {
      final parts = rule!.replaceString!.split(':');
      if (parts.length >= 2) {
        _matchController = TextEditingController(text: parts[0].trim());
        _replaceController = TextEditingController(text: parts.sublist(1).join(':').trim());
      } else {
        _matchController = TextEditingController(text: '');
        _replaceController = TextEditingController(text: rule.replaceString ?? '');
      }
    } else {
      _matchController = TextEditingController(text: rule?.matchString ?? '');
      _replaceController = TextEditingController(text: rule?.replaceString ?? '');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    _matchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<BrowserState>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final showMatchField = _selectedAction == 'MATCH_REPLACE';
    final showHeaderInjectFields = _selectedAction == 'HEADER_INJECT';
    final showReplaceField = _selectedAction == 'REDIRECT' || _selectedAction == 'MATCH_REPLACE' || _selectedAction == 'BODY_REPLACE';

    String replaceLabel = 'Replace Content';
    String replaceHint = 'Enter replacement string';
    if (_selectedAction == 'REDIRECT') {
      replaceLabel = 'Target Redirection URL';
      replaceHint = 'https://example.com';
    } else if (_selectedAction == 'BODY_REPLACE') {
      replaceLabel = 'New Response Body Payload';
      replaceHint = '{"status": "ok"} or <html>...</html>';
    }

    return Material(
      color: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88 + bottomInset * 0.3,
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.existingRule == null ? 'Create Local Rule' : 'Edit Local Rule', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Rule Name'),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('e.g. Block Analytics'),
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel('Target Pattern (Regex, Fixed Text, or Smart Glob)'),
                    TextField(
                      controller: _patternController,
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.tealAccent),
                      decoration: _buildInputDecoration('e.g. example.com/*.js or *analytics*'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Method'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedMethod,
                                dropdownColor: const Color(0xFF2C2C2C),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _buildInputDecoration(''),
                                items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (val) => setState(() => _selectedMethod = val!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Phase'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedPhase,
                                dropdownColor: const Color(0xFF2C2C2C),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _buildInputDecoration(''),
                                items: _phases.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                onChanged: (val) => setState(() => _selectedPhase = val!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel('Action Type'),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAction,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildInputDecoration(''),
                      items: _actions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedAction = val!;
                          if (_selectedAction == 'BODY_REPLACE' || _selectedAction == 'MATCH_REPLACE') {
                            _selectedPhase = 'Response';
                          } else if (_selectedAction == 'BLOCK' || _selectedAction == 'REDIRECT') {
                            _selectedPhase = 'Request';
                          } else if (_selectedAction == 'HEADER_INJECT') {
                            _selectedPhase = 'Both';
                          }
                        });
                      },
                    ),
                    if (showHeaderInjectFields) ...[
                      const SizedBox(height: 16),
                      _buildInputLabel('Header Name (Key to Add or Modify)'),
                      TextField(
                        controller: _matchController,
                        style: const TextStyle(fontFamily: 'monospace', color: Colors.amberAccent),
                        decoration: _buildInputDecoration('e.g. User-Agent or X-Custom-Auth'),
                      ),
                      const SizedBox(height: 16),
                      _buildInputLabel('Header Value'),
                      TextField(
                        controller: _replaceController,
                        style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent),
                        decoration: _buildInputDecoration('e.g. Mozilla/5.0 ...'),
                      ),
                    ],
                    if (showMatchField) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInputLabel('Match Target String'),
                          Row(
                            children: [
                              const Text('Regex Match', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Checkbox(
                                value: _isRegex,
                                activeColor: Colors.tealAccent,
                                checkColor: Colors.black,
                                onChanged: (val) => setState(() => _isRegex = val ?? false),
                              ),
                            ],
                          ),
                        ],
                      ),
                      TextField(
                        controller: _matchController,
                        style: const TextStyle(fontFamily: 'monospace', color: Colors.amberAccent),
                        decoration: _buildInputDecoration(_isRegex ? 'Regex pattern (e.g. <title>.*?</title>)' : 'Exact substring to find'),
                      ),
                    ],
                    if (showReplaceField) ...[
                      const SizedBox(height: 16),
                      _buildInputLabel(replaceLabel),
                      (_selectedAction == 'BODY_REPLACE' || _selectedAction == 'MATCH_REPLACE')
                          ? _buildRichCodeEditor(_replaceController, replaceHint)
                          : TextField(
                              controller: _replaceController,
                              style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent),
                              decoration: _buildInputDecoration(replaceHint),
                            ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final name = _nameController.text.trim().isEmpty ? 'Unnamed Rule' : _nameController.text.trim();
                          final pattern = _patternController.text.trim().isEmpty ? '.*' : _patternController.text.trim();

                          String? matchStr = showMatchField ? _matchController.text : null;
                          String? replaceStr = showReplaceField ? _replaceController.text : null;
                          if (_selectedAction == 'HEADER_INJECT') {
                            replaceStr = '${_matchController.text.trim()}: ${_replaceController.text.trim()}';
                          }

                          final newRule = LocalRule(
                            id: widget.existingRule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            targetPattern: pattern,
                            phase: _selectedPhase,
                            actionType: _selectedAction,
                            matchString: matchStr,
                            replaceString: replaceStr,
                            isActive: widget.existingRule?.isActive ?? true,
                            isRegex: _isRegex,
                            method: _selectedMethod,
                          );

                          if (widget.existingRule != null && widget.index != null) {
                            state.updateLocalRule(widget.index!, newRule);
                          } else {
                            state.addLocalRule(newRule);
                          }
                          Navigator.pop(context);
                        },
                        child: Text(widget.existingRule == null ? 'Save Rule' : 'Update Rule', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichCodeEditor(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414), // IDE pitch black
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text('PAYLOAD EDITOR', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copy All',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.copy, size: 16, color: Colors.tealAccent),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: controller.text));
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
                        controller.text = data!.text!;
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Format',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.auto_fix_high, size: 16, color: Colors.blueAccent),
                    onPressed: () {
                      try {
                        final parsed = jsonDecode(controller.text);
                        controller.text = const JsonEncoder.withIndent('  ').convert(parsed);
                      } catch (_) {
                        controller.text = controller.text.trim();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white12),
          TextField(
            controller: controller,
            minLines: 6,
            maxLines: 16,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4, color: Colors.greenAccent),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }
}

