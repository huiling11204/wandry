import 'package:cloud_firestore/cloud_firestore.dart';
/// Data structure for Terms & Privacy Policy
class LegalDocument {
  final String id;
  final String title;
  final String version;
  final DateTime effectiveDate;
  final DateTime updatedAt;
  final List<DocumentSection> sections;
  final String? lastEditedBy;

  LegalDocument({
    required this.id,
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.updatedAt,
    required this.sections,
    this.lastEditedBy,
  });

  /// Create from Firestore document
  factory LegalDocument.fromFirestore(Map<String, dynamic> data, String id) {
    return LegalDocument(
      id: id,
      title: data['title'] ?? '',
      version: data['version'] ?? '1.0.0',
      effectiveDate: (data['effectiveDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sections: (data['sections'] as List<dynamic>?)
          ?.map((s) => DocumentSection.fromMap(s as Map<String, dynamic>))
          .toList() ??
          [],
      lastEditedBy: data['lastEditedBy'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'version': version,
      'effectiveDate': Timestamp.fromDate(effectiveDate),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sections': sections.map((s) => s.toMap()).toList(),
      'lastEditedBy': lastEditedBy,
    };
  }

  /// Create a copy with updated fields
  LegalDocument copyWith({
    String? id,
    String? title,
    String? version,
    DateTime? effectiveDate,
    DateTime? updatedAt,
    List<DocumentSection>? sections,
    String? lastEditedBy,
  }) {
    return LegalDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      version: version ?? this.version,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      updatedAt: updatedAt ?? this.updatedAt,
      sections: sections ?? this.sections,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
    );
  }

  /// Get formatted last updated date
  String get formattedUpdatedAt {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[updatedAt.month - 1]} ${updatedAt.day}, ${updatedAt.year}';
  }
}

/// DocumentSection - Individual section within a legal document
class DocumentSection {
  final String title;
  final String content;
  final int order;

  DocumentSection({
    required this.title,
    required this.content,
    required this.order,
  });

  factory DocumentSection.fromMap(Map<String, dynamic> data) {
    return DocumentSection(
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'order': order,
    };
  }

  DocumentSection copyWith({
    String? title,
    String? content,
    int? order,
  }) {
    return DocumentSection(
      title: title ?? this.title,
      content: content ?? this.content,
      order: order ?? this.order,
    );
  }
}

/// DocumentVersion - Version history for legal documents
class DocumentVersion {
  final String id;
  final List<DocumentSection> content;
  final String version;
  final DateTime createdAt;
  final String createdBy;

  DocumentVersion({
    required this.id,
    required this.content,
    required this.version,
    required this.createdAt,
    required this.createdBy,
  });

  factory DocumentVersion.fromFirestore(Map<String, dynamic> data, String id) {
    return DocumentVersion(
      id: id,
      content: (data['content'] as List<dynamic>?)
          ?.map((s) => DocumentSection.fromMap(s as Map<String, dynamic>))
          .toList() ??
          [],
      version: data['version'] ?? '1.0.0',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content.map((s) => s.toMap()).toList(),
      'version': version,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}