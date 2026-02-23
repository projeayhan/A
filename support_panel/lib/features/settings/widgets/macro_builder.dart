import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MacroBuilderDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const MacroBuilderDialog({super.key, this.existing});

  @override
  State<MacroBuilderDialog> createState() => _MacroBuilderDialogState();
}

class _MacroBuilderDialogState extends State<MacroBuilderDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  late List<Map<String, dynamic>> _actions;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?['name'] ?? '');
    _descCtrl = TextEditingController(text: widget.existing?['description'] ?? '');
    _category = widget.existing?['category'] ?? 'general';
    _actions = widget.existing?['actions'] != null
        ? List<Map<String, dynamic>>.from((widget.existing!['actions'] as List).map((a) => Map<String, dynamic>.from(a)))
        : [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Makro' : 'Makroyu Duzenle'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Makro Adi', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Aciklama (opsiyonel)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'greeting', child: Text('Selamlama')),
                  DropdownMenuItem(value: 'order', child: Text('Siparis')),
                  DropdownMenuItem(value: 'delivery', child: Text('Teslimat')),
                  DropdownMenuItem(value: 'complaint', child: Text('Sikayet')),
                  DropdownMenuItem(value: 'general', child: Text('Genel')),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'general'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Aksiyonlar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addAction,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Aksiyon Ekle'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_actions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('Henuz aksiyon eklenmedi', style: TextStyle(color: textMuted, fontSize: 13))),
                )
              else
                ..._actions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final action = entry.value;
                  return _buildActionCard(i, action, textMuted);
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
        ElevatedButton(
          onPressed: _nameCtrl.text.trim().isEmpty || _actions.isEmpty
              ? null
              : () {
                  Navigator.pop(context, {
                    'name': _nameCtrl.text.trim(),
                    'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                    'category': _category,
                    'actions': _actions,
                  });
                },
          child: Text(widget.existing == null ? 'Olustur' : 'Kaydet'),
        ),
      ],
    );
  }

  Widget _buildActionCard(int index, Map<String, dynamic> action, Color textMuted) {
    final type = action['type'] as String? ?? 'send_message';
    final value = action['value'] as String? ?? '';
    final content = action['content'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${index + 1}.', style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: type,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.textPrimary : AppColors.lightTextPrimary, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'send_message', child: Text('Mesaj Gonder')),
                    DropdownMenuItem(value: 'change_status', child: Text('Durum Degistir')),
                    DropdownMenuItem(value: 'change_priority', child: Text('Oncelik Degistir')),
                    DropdownMenuItem(value: 'add_tag', child: Text('Tag Ekle')),
                    DropdownMenuItem(value: 'add_note', child: Text('Ic Not Ekle')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      action['type'] = v;
                      action.remove('value');
                      action.remove('content');
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _actions.removeAt(index)),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (type == 'send_message' || type == 'add_note')
            TextField(
              controller: TextEditingController(text: content),
              decoration: InputDecoration(
                labelText: type == 'send_message' ? 'Mesaj icerigi' : 'Not icerigi',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (v) => action['content'] = v,
            )
          else if (type == 'change_status')
            DropdownButtonFormField<String>(
              value: value.isEmpty ? 'resolved' : value,
              decoration: const InputDecoration(labelText: 'Yeni Durum', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Acik')),
                DropdownMenuItem(value: 'assigned', child: Text('Atandi')),
                DropdownMenuItem(value: 'pending', child: Text('Beklemede')),
                DropdownMenuItem(value: 'waiting_customer', child: Text('Musteri Bekleniyor')),
                DropdownMenuItem(value: 'resolved', child: Text('Cozuldu')),
                DropdownMenuItem(value: 'closed', child: Text('Kapandi')),
              ],
              onChanged: (v) => setState(() => action['value'] = v),
            )
          else if (type == 'change_priority')
            DropdownButtonFormField<String>(
              value: value.isEmpty ? 'normal' : value,
              decoration: const InputDecoration(labelText: 'Yeni Oncelik', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Dusuk')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'high', child: Text('Yuksek')),
                DropdownMenuItem(value: 'urgent', child: Text('Acil')),
              ],
              onChanged: (v) => setState(() => action['value'] = v),
            )
          else if (type == 'add_tag')
            TextField(
              controller: TextEditingController(text: value),
              decoration: const InputDecoration(labelText: 'Tag adi', border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => action['value'] = v,
            ),
        ],
      ),
    );
  }

  void _addAction() {
    setState(() {
      _actions.add({'type': 'send_message', 'content': ''});
    });
  }
}
