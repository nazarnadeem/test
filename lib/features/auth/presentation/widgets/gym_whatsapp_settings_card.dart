import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/widgets/custom_text_field.dart';

/// Optional WhatsApp sender fields for super admin gym create and edit.
class GymWhatsAppSettingsControllers {
  final TextEditingController phoneNumberId = TextEditingController();
  final TextEditingController accessToken = TextEditingController();
  final TextEditingController templates = TextEditingController(
    text: 'welcome_member, membership_expired_reminder, membership_expiry_reminder',
  );

  bool get hasPhoneNumber => phoneNumberId.text.trim().isNotEmpty;

  void apply(GymWhatsAppSettings settings) {
    phoneNumberId.text = settings.phoneNumberId;
    templates.text = settings.templatesText;
  }

  void dispose() {
    phoneNumberId.dispose();
    accessToken.dispose();
    templates.dispose();
  }
}

/// Editable WhatsApp block. Leave the phone number blank to keep using the platform number.
class GymWhatsAppSettingsFields extends StatelessWidget {
  final GymWhatsAppSettingsControllers controllers;
  final bool tokenSaved;

  const GymWhatsAppSettingsFields({
    super.key,
    required this.controllers,
    this.tokenSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Production WhatsApp number for this gym. Leave the phone number blank to keep WhatsApp off for this gym. The access token is stored on the server and is not shown again.',
          style: GoogleFonts.inter(color: AppColors.textSecondaryDark, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: controllers.phoneNumberId,
          label: 'WhatsApp phone number ID',
          hint: 'From Meta API Setup',
          prefixIcon: Icons.tag_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: controllers.accessToken,
          label: 'WhatsApp access token',
          hint: tokenSaved ? 'Saved. Leave blank to keep it.' : 'Permanent token',
          prefixIcon: Icons.key_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: controllers.templates,
          label: 'Templates',
          hint: 'welcome_member, membership_expired_reminder, membership_expiry_reminder',
          helperText: 'Comma separated, in order: welcome, membership expired, membership expiry.',
          prefixIcon: Icons.list_alt_rounded,
          keyboardType: TextInputType.multiline,
          maxLines: 2,
          textInputAction: TextInputAction.newline,
        ),
      ],
    );
  }
}
