import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:glamora/firebase_options.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/providers/ChatProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/HistoryProvider.dart';
import 'package:glamora/providers/HomeProvider.dart';
import 'package:glamora/providers/OrdersProvider.dart';
import 'package:glamora/providers/ProductDetailsProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/providers/RatingProvider.dart';
import 'package:glamora/providers/ReviewProvider.dart';
import 'package:glamora/providers/SearchProvider.dart';
import 'package:glamora/providers/TrackingProvider.dart';
import 'package:glamora/providers/UserDetailsProvider.dart';
import 'package:glamora/providers/UserProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/providers/aiChatBotProvider.dart';
import 'package:glamora/providers/onBoardingProvider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Services/LocationService.dart';
import 'Services/OnlineStatusHandlerService.dart';
import 'screens/Splash Screen/SplashScreen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  setupCustomerOnlineStatus(); // Call here
// Load environment variables
  await dotenv.load(fileName: "assets/.env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitDown,
    DeviceOrientation.portraitUp
  ]);
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => HomeProvider()),
          ChangeNotifierProvider(create: (context) => ProductDetailsProvider()),
          ChangeNotifierProvider(create: (context) => CartProvider()),
          ChangeNotifierProvider(create: (context) => WishListProvider()),
          ChangeNotifierProvider(create: (context) => UserDetailsProvider()),
          ChangeNotifierProvider(create: (context) => HistoryProvider()),
          ChangeNotifierProvider(create: (context) => RatingProvider()),
          ChangeNotifierProvider(create: (context) => UserProvider()),
          ChangeNotifierProvider(create: (context) => DarkModeProvider()),
          ChangeNotifierProvider(create: (context) => ProductListProvider()),
          ChangeNotifierProvider(create: (context) => ReviewProvider()),
          ChangeNotifierProvider(create: (context) => GenderCategoryProvider()),
          ChangeNotifierProvider(create: (context) => ChatProvider()),
          ChangeNotifierProvider(create: (context) => InputProvider()),
          ChangeNotifierProvider(create: (context) => SearchProvider()),
          ChangeNotifierProvider(create: (context) => AIChatBotProvider()),
          ChangeNotifierProvider(create: (context) => TrackingProvider()),
          ChangeNotifierProvider(create: (context) => OrdersProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SplashScreen(),
        )
    );
  }
}
