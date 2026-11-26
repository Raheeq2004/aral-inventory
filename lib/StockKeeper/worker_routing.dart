import 'package:aral_project/SharedComponents/end_drawer_menu.dart';
import 'package:aral_project/connectivity/connectivity_badge.dart';
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
          Builder(
            builder: (buttonContext) {
              return IconButton(
                onPressed: () {
                  Scaffold.of(buttonContext).openEndDrawer();
                },
                icon: const Icon(Icons.menu_rounded),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      endDrawer: EndDrawerMenu(),

      body: widget.child,
    );
  }
}
