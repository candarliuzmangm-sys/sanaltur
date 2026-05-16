import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/navigation.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/property_provider.dart';

/// Property creation wizard — 3 adım:
/// 1) Kategori
/// 2) Yapısal bilgiler (kat sayısı + oda sayıları)
/// 3) İsim + adres
class CreatePropertyPage extends ConsumerStatefulWidget {
  const CreatePropertyPage({super.key});

  @override
  ConsumerState<CreatePropertyPage> createState() => _CreatePropertyPageState();
}

enum _CreateStep { category, structure, naming }

class _CreatePropertyPageState extends ConsumerState<CreatePropertyPage> {
  final PageController _pageController = PageController();
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();

  _CreateStep _step = _CreateStep.category;
  String _category = 'APARTMENT';
  int _floorCount = 1;
  final Map<String, int> _roomCounts = {
    'LIVING_ROOM': 1,
    'BEDROOM': 1,
    'KITCHEN': 1,
    'BATHROOM': 1,
    'BALCONY': 0,
  };
  bool _loading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _goTo(_CreateStep step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      _CreateStep.values.indexOf(step),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    final idx = _CreateStep.values.indexOf(_step);
    if (idx < _CreateStep.values.length - 1) {
      _goTo(_CreateStep.values[idx + 1]);
    }
  }

  void _back() {
    final idx = _CreateStep.values.indexOf(_step);
    if (idx > 0) {
      _goTo(_CreateStep.values[idx - 1]);
    } else {
      context.pop();
    }
  }

  String get _defaultTitle {
    switch (_category) {
      case 'APARTMENT':
        final bed = _roomCounts['BEDROOM'] ?? 0;
        final liv = _roomCounts['LIVING_ROOM'] ?? 0;
        if (bed > 0 && liv > 0) return '$bed+$liv Daire';
        return 'Daire';
      case 'VILLA':
        return 'Villa';
      case 'OFFICE':
        return 'Ofis';
      case 'STORE':
        return 'Mağaza';
      case 'SHOP':
        return 'Dükkan';
      default:
        return 'Mülk';
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim().isEmpty
        ? _defaultTitle
        : _titleController.text.trim();
    setState(() => _loading = true);
    try {
      final cleanedCounts =
          Map<String, int>.from(_roomCounts)..removeWhere((_, v) => v <= 0);
      final property = await ref.read(propertyActionsProvider).create(
            title: title,
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            category: _category,
            floorCount: _floorCount,
            roomCounts: cleanedCounts,
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
      backgroundColor: const Color(0xFF0A0E0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: const Text('Yeni Mülk'),
        actions: const [HomeToolbarAction()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: _StepperBar(
            current: _CreateStep.values.indexOf(_step),
            total: _CreateStep.values.length,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _categoryStep(),
                  _structureStep(),
                  _namingStep(),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  // ---------- STEP 1: CATEGORY ----------

  Widget _categoryStep() {
    final cats = const [
      ('APARTMENT', 'Daire', Icons.apartment_outlined, 'Konut'),
      ('VILLA', 'Villa', Icons.villa_outlined, 'Müstakil ev'),
      ('OFFICE', 'Ofis', Icons.business_center_outlined, 'İş yeri'),
      ('STORE', 'Mağaza', Icons.storefront_outlined, 'Perakende'),
      ('SHOP', 'Dükkan', Icons.store_outlined, 'Küçük dükkan'),
      ('OTHER', 'Diğer', Icons.category_outlined, 'Özel'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            title: 'Hangi tipte bir mülk?',
            subtitle: 'Kategoriyi seç — sonraki adımları sana göre özelleştirelim.',
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final c = cats[i];
                final selected = _category == c.$1;
                return _CategoryCard(
                  title: c.$2,
                  hint: c.$4,
                  icon: c.$3,
                  selected: selected,
                  onTap: () => setState(() => _category = c.$1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- STEP 2: STRUCTURE ----------

  Widget _structureStep() {
    final items = const [
      ('LIVING_ROOM', 'Salon', Icons.weekend_outlined),
      ('BEDROOM', 'Yatak odası', Icons.bed_outlined),
      ('KITCHEN', 'Mutfak', Icons.kitchen_outlined),
      ('BATHROOM', 'Banyo / WC', Icons.bathtub_outlined),
      ('DINING_ROOM', 'Yemek odası', Icons.dining_outlined),
      ('OFFICE', 'Çalışma odası', Icons.work_outline),
      ('BALCONY', 'Balkon / Teras', Icons.balcony_outlined),
      ('HALLWAY', 'Antre', Icons.meeting_room_outlined),
      ('GARAGE', 'Garaj', Icons.garage_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        const _StepHeader(
          title: 'Mülk yapısı',
          subtitle: 'Kaç katlı? Hangi odalardan kaç tane var?',
        ),
        const SizedBox(height: 20),
        _GlassCard(
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.layers_outlined, color: Colors.white70),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Kat sayısı',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  _Counter(
                    value: _floorCount,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() => _floorCount = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...items.map((it) {
          final count = _roomCounts[it.$1] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(it.$3, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      it.$2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _Counter(
                    value: count,
                    min: 0,
                    max: 20,
                    onChanged: (v) =>
                        setState(() => _roomCounts[it.$1] = v),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        _SummaryPill(
          total: _roomCounts.values.fold<int>(0, (a, b) => a + b),
          floorCount: _floorCount,
        ),
      ],
    );
  }

  // ---------- STEP 3: NAMING ----------

  Widget _namingStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const _StepHeader(
          title: 'Son rötuşlar',
          subtitle: 'İsim ve adresi gir. Adres opsiyonel.',
        ),
        const SizedBox(height: 20),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mülk adı',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: _defaultTitle,
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adres (opsiyonel)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _addressController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Örn: Kadıköy / İstanbul',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Color(0xFF22C55E), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Oluşturduğunda ${_roomCounts.values.fold<int>(0, (a, b) => a + b)} oda otomatik eklenecek. Direkt çekime başlayabilirsin.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- BOTTOM BAR ----------

  Widget _bottomBar() {
    final isLast = _step == _CreateStep.naming;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E0D),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (_step != _CreateStep.category)
            Expanded(
              flex: 1,
              child: TextButton(
                onPressed: _loading ? null : _back,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Geri'),
              ),
            ),
          if (_step != _CreateStep.category) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _loading ? null : (isLast ? _submit : _next),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isLast ? 'Oluştur ve Çekime Başla' : 'Devam',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ WIDGETS ============

class _StepperBar extends StatelessWidget {
  const _StepperBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: List.generate(total, (i) {
          final filled = i <= current;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
              height: 3,
              decoration: BoxDecoration(
                color: filled
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.28),
                    AppTheme.primary.withValues(alpha: 0.10),
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (selected
                        ? AppTheme.primary
                        : Colors.white.withValues(alpha: 0.10))
                    .withValues(alpha: selected ? 0.20 : 1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: selected ? AppTheme.primary : Colors.white70,
                size: 22,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 20,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CounterBtn(
          icon: Icons.remove,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _CounterBtn(
          icon: Icons.add,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _CounterBtn extends StatelessWidget {
  const _CounterBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.primary.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppTheme.primary : Colors.white24,
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.total, required this.floorCount});
  final int total;
  final int floorCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF22C55E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              floorCount > 1
                  ? '$floorCount kat · toplam $total oda hazır'
                  : '$total oda otomatik eklenecek',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
