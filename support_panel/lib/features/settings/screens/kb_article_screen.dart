import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class KbArticleDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const KbArticleDialog({super.key, this.existing});

  @override
  State<KbArticleDialog> createState() => _KbArticleDialogState();
}

class _KbArticleDialogState extends State<KbArticleDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _tagsCtrl;
  late String _category;
  late String? _serviceType;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?['title'] ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?['content'] ?? '');
    final tags = (widget.existing?['tags'] as List?)?.cast<String>() ?? [];
    _tagsCtrl = TextEditingController(text: tags.join(', '));
    _category = widget.existing?['category'] ?? 'faq';
    _serviceType = widget.existing?['service_type'];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return AlertDialog(
      title: Text(isNew ? 'Yeni Makale' : 'Makaleyi Duzenle'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Baslik', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Icerik',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                minLines: 5,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'faq', child: Text('SSS')),
                        DropdownMenuItem(value: 'policy', child: Text('Politika')),
                        DropdownMenuItem(value: 'procedure', child: Text('Prosedur')),
                        DropdownMenuItem(value: 'troubleshooting', child: Text('Sorun Giderme')),
                        DropdownMenuItem(value: 'guide', child: Text('Kilavuz')),
                      ],
                      onChanged: (v) => setState(() => _category = v ?? 'faq'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _serviceType,
                      decoration: const InputDecoration(labelText: 'Servis Tipi', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Genel')),
                        DropdownMenuItem(value: 'food', child: Text('Yemek')),
                        DropdownMenuItem(value: 'grocery', child: Text('Market')),
                        DropdownMenuItem(value: 'taxi', child: Text('Taksi')),
                        DropdownMenuItem(value: 'courier', child: Text('Kurye')),
                        DropdownMenuItem(value: 'rental', child: Text('Kiralama')),
                        DropdownMenuItem(value: 'emlak', child: Text('Emlak')),
                        DropdownMenuItem(value: 'car_sales', child: Text('Arac Satis')),
                      ],
                      onChanged: (v) => setState(() => _serviceType = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Etiketler (virgul ile ayirin)',
                  border: OutlineInputBorder(),
                  hintText: 'ornegin: iade, siparis, gecikme',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.pop(context, {'_delete': true}),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ElevatedButton(
          onPressed: _titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty
              ? null
              : () {
                  final tags = _tagsCtrl.text
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();

                  Navigator.pop(context, {
                    'title': _titleCtrl.text.trim(),
                    'content': _contentCtrl.text.trim(),
                    'category': _category,
                    'service_type': _serviceType,
                    'tags': tags,
                  });
                },
          child: Text(isNew ? 'Olustur' : 'Kaydet'),
        ),
      ],
    );
  }
}
