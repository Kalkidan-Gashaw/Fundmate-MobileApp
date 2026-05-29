import 'package:cloud_firestore/cloud_firestore.dart';

class NdaService {
  static CollectionReference<Map<String, dynamic>> get _signatures =>
      FirebaseFirestore.instance.collection('nda_signatures');

  static DocumentReference<Map<String, dynamic>> _doc(String investorId) =>
      _signatures.doc(investorId);

  static Stream<DocumentSnapshot<Map<String, dynamic>>> signatureStream(
    String investorId,
  ) {
    return _doc(investorId).snapshots();
  }

  static Future<bool> hasSigned(String investorId) async {
    final doc = await _doc(investorId).get();
    return doc.exists && (doc.data()?['signed'] == true);
  }

  static Future<void> signNda({
    required String investorId,
    required String investorName,
    required String investorEmail,
  }) async {
    await _doc(investorId).set({
      'investorId': investorId,
      'investorName': investorName,
      'investorEmail': investorEmail,
      'signed': true,
      'signedAt': FieldValue.serverTimestamp(),
    });
  }
}
