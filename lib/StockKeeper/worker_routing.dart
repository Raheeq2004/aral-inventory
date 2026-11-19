import 'package:aral_project/Internet%20Connectivity/connectivity_badge.dart';
import 'package:flutter/material.dart';

class WorkerRouting extends StatefulWidget {
  final String title;
  final Widget child;
  const WorkerRouting({super.key, required this.title, required this.child});

  @override
  State<WorkerRouting> createState() => _WorkerRoutingState();
}

class _WorkerRoutingState extends State<WorkerRouting> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(widget.title),
        actions: [
          const ConnectivityBadge(),
          const SizedBox(width: 8),
          IconButton(onPressed: () {}, icon: const Icon(Icons.history_rounded)),
          const SizedBox(width: 10),
        ],
      ),
      body: widget.child,
    );
  }
}
