import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

final researchHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) {
    return Stream<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('research')
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['job_id'] = (data['job_id'] ?? doc.id).toString();
            data['created_at'] = (data['created_at'] ?? data['createdAt'] ?? '').toString();
            return data;
          }).toList(growable: false));
});
