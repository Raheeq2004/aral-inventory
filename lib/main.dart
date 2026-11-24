import 'package:aral_project/Admin/providers/filter_provider.dart';
import 'package:aral_project/Admin/providers/items_repository.dart';
import 'package:aral_project/Admin/providers/locations_repository.dart';
import 'package:aral_project/Admin/providers/transactions_repository.dart';
import 'package:aral_project/Landing/landing_page.dart';
import 'package:aral_project/StockKeeper/providers/scan_flow_provider.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:aral_project/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase FIRST before running the app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        // ONE shared items / locations repository for the whole app
        // (TransactionData and the Reports page use the same instances).
        Provider(create: (_) => ItemsRepository()),
        Provider(create: (_) => LocationsRepository()),
        ChangeNotifierProvider(
          create: (context) => TransactionData(
            itemsRepo: context.read<ItemsRepository>(),
            locationsRepo: context.read<LocationsRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => TransactionFilterProvider(),
        ),
        // STOCK KEEPER: the scan flow (Step 1 product → Step 2 location →
        // Step 3 quantity). Uses the SAME items repository as the admin.
        ChangeNotifierProvider(
          create: (context) => ScanFlowProvider(
            itemsRepo: context.read<ItemsRepository>(),
            locationsRepo: context.read<LocationsRepository>(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aral Inventory',
      theme: AppTheme.lightTheme,
      //worker routing:
      // initialRoute: '/LandingPage', // Must match an entry in routes map
      // routes: {
      //   '/LandingPage': (context) => const LandingPage(),
      //   '/quantity': (context) =>
      //       const WorkerRouting(title: 'Quantity', child: QuantityPage()),
      // },
               home: const LandingPage(),
    );
  }
}