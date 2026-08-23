/// Document Model for Receipts, Sorting Reports & Delivery Notes
class DocumentModel {
  final String id;
  final String customerId;
  final String? customerName;
  final String? shipmentId;
  final String? batchId;
  final String docType; // 'receiving_receipt', 'sorting_report', 'delivery_note', 'boxes_receipt'
  final String title;
  final String fileName;
  final String? pdfBase64;
  final String? pdfUrl;
  final String? signatureBase64;
  final DateTime createdAt;

  DocumentModel({
    required this.id,
    required this.customerId,
    this.customerName,
    this.shipmentId,
    this.batchId,
    required this.docType,
    required this.title,
    required this.fileName,
    this.pdfBase64,
    this.pdfUrl,
    this.signatureBase64,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get docTypeAr {
    switch (docType) {
      case 'sorting_contract':
        return 'عقد فرز';
      case 'purchase_contract':
        return 'عقد شراء';
      case 'marketing_contract':
        return 'عقد تسويق';
      case 'receiving_receipt':
        return 'عقد فرز (سند استلام)';
      default:
        return 'عقد رسمي';
    }
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString(),
      shipmentId: json['shipment_id']?.toString(),
      batchId: json['batch_id']?.toString(),
      docType: json['doc_type']?.toString() ?? 'receiving_receipt',
      title: json['title']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? 'document.pdf',
      pdfBase64: json['pdf_base64']?.toString(),
      pdfUrl: json['pdf_url']?.toString(),
      signatureBase64: json['signature_base64']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'shipment_id': shipmentId,
      'batch_id': batchId,
      'doc_type': docType,
      'title': title,
      'file_name': fileName,
      'pdf_base64': pdfBase64,
      'pdf_url': pdfUrl,
      'signature_base64': signatureBase64,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
