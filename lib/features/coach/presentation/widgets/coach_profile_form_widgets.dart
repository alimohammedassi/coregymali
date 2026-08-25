import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';

// ── Shared coach profile form widgets ─────────────────────────────────────────
// Extracted from CoachProfileSetupScreen and CoachEditProfileScreen, which
// previously maintained two ~85%-identical copies of these builders.

/// Eyebrow-style section label ("PERSONAL INFO", "PRICING", ...).
class CoachFormSectionTitle extends StatelessWidget {
  final String title;
  const CoachFormSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppText.labelMd.copyWith(
        color: AppColors.tertiary,
        letterSpacing: 2,
      ),
    );
  }
}

/// Labelled text input used across every coach profile section.
class CoachFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const CoachFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: AppText.bodyMd.copyWith(color: AppColors.onSurface),
          validator: validator,
          decoration: _inputDecoration(hint: hint).copyWith(
            focusedBorder: _focusedBorder(),
            errorBorder: _errorBorder(),
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration({String? hint, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.bodyMd.copyWith(color: AppColors.outline),
    filled: true,
    fillColor: AppColors.surfaceContainer,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.all(16),
    suffixIcon: suffix,
  );
}

InputDecoration _bioDecoration(String hint) {
  return _inputDecoration(hint: hint).copyWith(
    focusedBorder: _focusedBorder(),
    errorBorder: _errorBorder(),
  );
}

OutlineInputBorder _focusedBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.tertiary, width: 1.5),
    );

OutlineInputBorder _errorBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    );

/// Male / Female segmented selector bound to 'male' / 'female' values.
class CoachGenderSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const CoachGenderSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style:
              AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _segment('Male', 'male')),
            const SizedBox(width: 12),
            Expanded(child: _segment('Female', 'female')),
          ],
        ),
      ],
    );
  }

  Widget _segment(String label, String val) {
    final selected = value == val;
    return GestureDetector(
      onTap: () => onChanged(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tertiary.withValues(alpha: 0.15)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.tertiary
                : AppColors.outline.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.labelMd.copyWith(
              color: selected
                  ? AppColors.tertiary
                  : AppColors.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled integer slider row (years of experience, max clients).
class CoachSliderRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const CoachSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppText.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              '$value',
              style: AppText.titleMd.copyWith(color: AppColors.tertiary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.tertiary,
            inactiveTrackColor: AppColors.surfaceContainer,
            thumbColor: AppColors.tertiary,
            overlayColor: AppColors.tertiary.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

/// Selectable pill chip for specializations / languages.
class CoachSelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CoachSelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tertiary.withValues(alpha: 0.15)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.tertiary
                : AppColors.outline.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Icon(Icons.check_rounded,
                  color: AppColors.tertiary, size: 14),
            if (selected) const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: AppText.labelMd.copyWith(
                color: selected
                    ? AppColors.tertiary
                    : AppColors.onSurfaceVariant,
                letterSpacing: 0.5,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular avatar picker with camera badge.
class CoachPhotoPicker extends StatelessWidget {
  /// Local picked-file path (takes precedence when set).
  final String? localPath;
  /// Existing uploaded avatar URL shown when no new file is picked.
  final String? networkUrl;
  final VoidCallback onPick;

  const CoachPhotoPicker({
    super.key,
    this.localPath,
    this.networkUrl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Choose profile photo',
      child: GestureDetector(
        onTap: onPick,
        child: Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.surfaceContainer,
                backgroundImage: localPath != null
                    ? FileImage(File(localPath!))
                    : (networkUrl != null
                            ? NetworkImage(networkUrl!)
                            : null)
                        as ImageProvider?,
                child: localPath == null && networkUrl == null
                    ? const Icon(Icons.person_rounded,
                        color: AppColors.onSurfaceVariant, size: 40)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.surfaceLowest, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.black, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free-text multi-line bio input with the standard length validation.
class CoachBioField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const CoachBioField({
    super.key,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Short Bio',
              style: AppText.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Text(
              '*Required',
              style: AppText.labelSm.copyWith(color: AppColors.tertiary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          style: AppText.bodyMd.copyWith(color: AppColors.onSurface),
          validator: (v) {
            if (v?.trim().isEmpty ?? true) return 'Bio is required';
            if (v!.trim().length > 500) return 'Max 500 characters';
            return null;
          },
          decoration: _bioDecoration(hint),
        ),
      ],
    );
  }
}

/// Certification list with an inline "add" field.
class CoachCertificationsEditor extends StatelessWidget {
  final List<String> certifications;
  final TextEditingController addController;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const CoachCertificationsEditor({
    super.key,
    required this.certifications,
    required this.addController,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Certifications',
          style:
              AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ...List.generate(certifications.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(certifications[i],
                          style: AppText.bodyMd
                              .copyWith(color: AppColors.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => onRemove(i),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.error, size: 18),
                  ),
                ],
              ),
            )),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: addController,
                style: AppText.bodyMd.copyWith(color: AppColors.onSurface),
                decoration: _inputDecoration(hint: 'Add certification'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onAdd,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.add_rounded, color: Colors.black, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
