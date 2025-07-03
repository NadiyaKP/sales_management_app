import 'package:intl/intl.dart';

class Helpers {
  // Generate UNID in the format "YYYYMMDDHHmmss"
  static String generateUNID() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMddHHmmss');
    return formatter.format(now);
  }
  
  // You can add more helper methods here as needed
}
