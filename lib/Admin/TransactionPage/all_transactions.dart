import 'package:flutter/material.dart';

class AllTransactionsPage extends StatefulWidget {
  const new({super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(15),
              child: SearchBar(hintText: 'Search product, code or worker'),
            ),
          ],
        ),
      ),
    );
  }
}
