import 'package:flutter/services.dart';

class WatchSyncService {
  static const MethodChannel _channel = MethodChannel('pocketplan/watch');

  Future<void> sendSummaryToWatch(Map<String, dynamic> summary) async {
    try {
      await _channel.invokeMethod('sendSummaryToWatch', summary);
    } catch (_) {
      // Su Android/Web o se il Watch non è disponibile, non blocchiamo l'app.
    }
  }
}