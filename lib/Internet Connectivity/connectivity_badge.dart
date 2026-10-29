import 'dart:async';

import 'package:flutter/material.dart';

import 'connectivity_service.dart';

class ConnectivityBadge extends StatefulWidget {
  const ConnectivityBadge({super.key});

  @override
  State<ConnectivityBadge> createState() => _ConnectivityBadgeState();
}

class _ConnectivityBadgeState extends State<ConnectivityBadge> {
  bool _isOnline = true;
  final ConnectivityService _connectivityService = ConnectivityService();
  late StreamSubscription<bool> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnection();

    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen((isOnline) {
          if (mounted) {
            setState(() {
              _isOnline = isOnline;
            });
          }
        });
  }

  Future<void> _initConnection() async {
    bool initialStatus = await _connectivityService.checkInitialConnection();
    if (mounted) {
      setState(() {
        _isOnline = initialStatus;
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isOnline
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color: _isOnline ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: _isOnline ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
