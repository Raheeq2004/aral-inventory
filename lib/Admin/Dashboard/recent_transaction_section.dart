import 'package:flutter/material.dart';

class RecentTransactionsSection extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent transactions'),
            TextButton(onPressed: () {}, child: Text('See all')),
          ],
        ),
        SizedBox(height: 20),
        // ListView.builder(
        //   itemCount: 1,
        //   itemBuilder: (context, index) {
        //     return Card(child: ListTile(title: Text("GHI")));
        //   },
        // ),
      ],
    );
  }
}
