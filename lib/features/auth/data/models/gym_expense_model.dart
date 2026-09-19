import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

/// Expense Category Definitions & Color Tokens
enum GymExpenseCategory {
  staffPayroll,
  equipmentUpkeep,
  facilityRent,
  powerUtilities,
  marketingOps,
  supplementsInventory,
  other;

  String get label {
    switch (this) {
      case GymExpenseCategory.staffPayroll:
        return 'Staff Payroll';
      case GymExpenseCategory.equipmentUpkeep:
        return 'Equipment & Upkeep';
      case GymExpenseCategory.facilityRent:
        return 'Facility & Rent';
      case GymExpenseCategory.powerUtilities:
        return 'Power & Utilities';
      case GymExpenseCategory.marketingOps:
        return 'Marketing & Ops';
      case GymExpenseCategory.supplementsInventory:
        return 'Supplements & Inventory';
      case GymExpenseCategory.other:
        return 'Other Expense';
    }
  }

  IconData get icon {
    switch (this) {
      case GymExpenseCategory.staffPayroll:
        return Icons.groups_rounded;
      case GymExpenseCategory.equipmentUpkeep:
        return Icons.fitness_center_rounded;
      case GymExpenseCategory.facilityRent:
        return Icons.storefront_rounded;
      case GymExpenseCategory.powerUtilities:
        return Icons.bolt_rounded;
      case GymExpenseCategory.marketingOps:
        return Icons.campaign_rounded;
      case GymExpenseCategory.supplementsInventory:
        return Icons.inventory_2_rounded;
      case GymExpenseCategory.other:
        return Icons.receipt_long_rounded;
    }
  }

  Color get color {
    switch (this) {
      case GymExpenseCategory.staffPayroll:
        return AppColors.accentViolet;
      case GymExpenseCategory.equipmentUpkeep:
        return AppColors.accentCyan;
      case GymExpenseCategory.facilityRent:
        return AppColors.accentOrange;
      case GymExpenseCategory.powerUtilities:
        return AppColors.accentAmber;
      case GymExpenseCategory.marketingOps:
        return AppColors.accentEmerald;
      case GymExpenseCategory.supplementsInventory:
        return const Color(0xFFEC4899); // Rose
      case GymExpenseCategory.other:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  static GymExpenseCategory fromString(String val) {
    for (final cat in GymExpenseCategory.values) {
      if (cat.label.toLowerCase() == val.toLowerCase() ||
          cat.name.toLowerCase() == val.toLowerCase()) {
        return cat;
      }
    }
    return GymExpenseCategory.other;
  }
}

/// Data model representing a gym operating expense transaction
class GymExpenseRecord {
  final String id;
  final String? tenantId;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String? notes;
  final String? recordedBy;

  const GymExpenseRecord({
    required this.id,
    this.tenantId,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.paymentMethod = 'UPI / Online',
    this.notes,
    this.recordedBy,
  });

  GymExpenseCategory get categoryEnum => GymExpenseCategory.fromString(category);
  IconData get icon => categoryEnum.icon;
  Color get color => categoryEnum.color;

  String get formattedAmount => '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
  String get formattedDate => DateFormat('dd MMM yyyy').format(date);
  String get formattedTime => DateFormat('hh:mm a').format(date);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'notes': notes,
      'recordedBy': recordedBy,
    };
  }

  factory GymExpenseRecord.fromJson(Map<String, dynamic> json, [String? fallbackId]) {
    DateTime parsedDate = DateTime.now();
    if (json['date'] != null) {
      if (json['date'] is String) {
        parsedDate = DateTime.tryParse(json['date'] as String) ?? DateTime.now();
      } else {
        try {
          parsedDate = (json['date'] as dynamic).toDate();
        } catch (_) {
          parsedDate = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
        }
      }
    }

    return GymExpenseRecord(
      id: json['id'] as String? ?? fallbackId ?? '',
      tenantId: json['tenantId'] as String?,
      title: json['title'] as String? ?? 'General Expense',
      category: json['category'] as String? ?? 'Other Expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate,
      paymentMethod: json['paymentMethod'] as String? ?? 'UPI / Online',
      notes: json['notes'] as String?,
      recordedBy: json['recordedBy'] as String?,
    );
  }

  GymExpenseRecord copyWith({
    String? id,
    String? tenantId,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    String? paymentMethod,
    String? notes,
    String? recordedBy,
  }) {
    return GymExpenseRecord(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      recordedBy: recordedBy ?? this.recordedBy,
    );
  }
}
