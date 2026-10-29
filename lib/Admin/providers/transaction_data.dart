import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class TransactionData extends ChangeNotifier {
  List<TransactionModel> transactionDataList = [];
  bool isLoading = false;

  Future<void> getTransactions() async {
    isLoading = true;
    notifyListeners();
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref('transactions');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        transactionDataList.clear();

        Map<dynamic, dynamic> extractedData =
            snapshot.value as Map<dynamic, dynamic>;

        extractedData.forEach((key, value) {
          final transactionMap = Map<String, dynamic>.from(value);
          transactionDataList.add(
            TransactionModel.fromMap(transactionMap, key.toString()),
          );
        });
      } else {
        print(
          'DEBUG: Node "transactions" is empty or does not exist in Firebase.',
        );
      }
    } catch (e) {
      print('DEBUG ERROR: Failed to fetch data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
