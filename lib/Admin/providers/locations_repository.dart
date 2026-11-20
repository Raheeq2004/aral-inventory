import 'package:firebase_database/firebase_database.dart';

class LocationsRepository {
  final DatabaseReference _locationsRef = FirebaseDatabase.instance.ref(
    'locations',
  );

  /// Returns true if [locationCode] (e.g. "WH1-A1-02") exists in `locations`.
  Future<bool> locationExists(String locationCode) async {
    final snap = await _locationsRef
        .orderByChild('Location Code')
        .equalTo(locationCode)
        .limitToFirst(1)
        .get();
    return snap.exists;
  }
}
