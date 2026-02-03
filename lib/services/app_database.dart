import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AppDatabase {
  static final FirebaseFirestore _instance = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  static FirebaseFirestore get instance => _instance;
}
