// ─────────────────────────────────────────────────────────────────────────────
// HOW TO USE — paste this logic wherever you navigate to the return screen
// (e.g. in your OrderDetailsScreen or order list tile's onTap)
// ─────────────────────────────────────────────────────────────────────────────

// 1. Make sure listenToMyReturns(uid) is called ONCE when the customer
//    section loads (e.g. in your orders screen's initState or after login).
//    This keeps _myReturns always up-to-date in the provider.
//
//    Example — in OrdersScreen initState:
//
//      @override
//      void initState() {
//        super.initState();
//        final uid = FirebaseAuth.instance.currentUser!.uid;
//        // read() so we don't listen here, provider handles the stream
//        context.read<ReturnProvider>().listenToMyReturns(uid);
//      }

// ─────────────────────────────────────────────────────────────────────────────

// 2. Replace your current "Return" button / onTap with this:
import 'package:flutter/material.dart';
import 'package:http/http.dart';

import '../../providers/returnProvider.dart';
import 'ReturnOrder.dart';
import 'ReturnStatusScreen.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Imports needed in the file where you use _navigateToReturn:
//
// import 'package:provider/provider.dart';
// import '../../providers/returnProvider.dart';
// import 'customer_return_screen.dart';   // your existing file
// import 'return_status_screen.dart';     // new file
// ─────────────────────────────────────────────────────────────────────────────