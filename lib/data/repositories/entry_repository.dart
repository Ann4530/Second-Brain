import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/entry.dart';
import '../services/crypto_service.dart';

/// Stores journal entries. The interface keeps the UI independent of the
/// backend; the app picks Firestore when Firebase is configured, else
/// in-memory (dev).
abstract interface class EntryRepository {
  Future<List<Entry>> all();
  Future<Entry?> entryForLocalDate(String localDate);
  Future<int> countForLocalDate(String localDate);
  Future<void> save(Entry entry);
  Future<void> deleteAll();
}

/// Dev/default implementation — in-memory, lets the app run end-to-end before
/// Firebase is wired.
class InMemoryEntryRepository implements EntryRepository {
  final List<Entry> _entries = [];

  @override
  Future<List<Entry>> all() async =>
      List.unmodifiable(_entries.reversed.toList());

  @override
  Future<Entry?> entryForLocalDate(String localDate) async {
    for (final e in _entries) {
      if (e.localDate == localDate) return e;
    }
    return null;
  }

  @override
  Future<int> countForLocalDate(String localDate) async =>
      _entries.where((e) => e.localDate == localDate).length;

  @override
  Future<void> save(Entry entry) async => _entries.add(entry);

  @override
  Future<void> deleteAll() async => _entries.clear();
}

/// Production implementation: users/{uid}/entries/{id} with the entry text
/// AES-GCM-encrypted at rest (key never leaves the device keystore).
///
/// NOTE: also enforce the free daily cap server-side (Cloud Function / rules);
/// the client check in JournalController can be bypassed.
class FirestoreEntryRepository implements EntryRepository {
  FirestoreEntryRepository({
    required this.uid,
    required CryptoService crypto,
    FirebaseFirestore? firestore,
  })  : _crypto = crypto,
        _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final CryptoService _crypto;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('entries');

  Future<Entry> _decrypt(String id, Map<String, dynamic> json) async {
    final e = Entry.fromJson(id, json);
    return e.copyWith(text: await _crypto.decrypt(e.text));
  }

  @override
  Future<List<Entry>> all() async {
    final snap = await _col.orderBy('createdAtMs', descending: true).get();
    return Future.wait(snap.docs.map((d) => _decrypt(d.id, d.data())));
  }

  @override
  Future<Entry?> entryForLocalDate(String localDate) async {
    final snap =
        await _col.where('localDate', isEqualTo: localDate).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return _decrypt(d.id, d.data());
  }

  @override
  Future<int> countForLocalDate(String localDate) async {
    final agg =
        await _col.where('localDate', isEqualTo: localDate).count().get();
    return agg.count ?? 0;
  }

  @override
  Future<void> save(Entry entry) async {
    final json = entry.toJson();
    json['text'] = await _crypto.encrypt(entry.text);
    await _col.doc(entry.id).set(json);
  }

  @override
  Future<void> deleteAll() async {
    final snap = await _col.get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
