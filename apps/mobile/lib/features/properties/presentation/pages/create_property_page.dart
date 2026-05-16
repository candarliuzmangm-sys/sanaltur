import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/navigation.dart';
import '../providers/property_provider.dart';

class CreatePropertyPage extends ConsumerStatefulWidget {
  const CreatePropertyPage({super.key});

  @override
  ConsumerState<CreatePropertyPage> createState() => _CreatePropertyPageState();
}

class _CreatePropertyPageState extends ConsumerState<CreatePropertyPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final property = await ref.read(propertyActionsProvider).create(
            title: _titleController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
          );
      ref.read(propertyActionsProvider).invalidate(property.id);
      if (mounted) context.push('/properties/${property.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const NavigationLeading(),
        title: const Text('Yeni Mülk'),
        actions: const [HomeToolbarAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Mülk adı',
                  hintText: 'Örn: Kadıköy 3+1 Daire',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Mülk adı gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Adres (opsiyonel)'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Oluştur ve Çekime Başla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
