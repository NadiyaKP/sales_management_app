import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'permission.dart';

class ApiServices {
  /// General method to fetch data from the API
  Future<Map<String, dynamic>?> fetchData(String endpoint) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');
      if (url == null || unid == null || slex == null) {
        return null;
      }
      final response = await http.post(
        Uri.parse('$url/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
        }),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['result'] == '1') {
          return data;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetch Customer Data
  Future<List<Map<String, String>>> fetchCustomers() async {
    final data = await fetchData('get_customers.php');
    if (data == null || !data.containsKey('customerdet')) return [];
    return (data['customerdet'] as List<dynamic>)
        .map((e) => {
      "cust_name": e['cust_name'].toString(),  // Explicitly convert to String
      "custid": e['custid'].toString(),
      "outstand_amt": e['outstand_amt'].toString(),
    })
        .toList();
  }

  /// Fetch Wallet Data
  Future<List<Map<String, String>>> fetchWallets() async {
    final data = await fetchData('get_wallets.php');
    if (data == null || !data.containsKey('walletdet')) return [];
    return (data['walletdet'] as List<dynamic>)
        .map((e) => {
      "wlt_name": e['wlt_name'].toString(),
      "wltid": e['wltid'].toString(),
    })
        .toList();
  }

  /// Fetch customer type Data
  Future<List<Map<String, String>>> fetchCustomersType() async {
    final data = await fetchData('get_customer_types.php');
    if (data == null || !data.containsKey('customertypesdet')) return [];
    return (data['customertypesdet'] as List<dynamic>)
        .map((e) => {
      "custtype_name": e['custtype_name'].toString(),
      "custtypeid": e['custtypeid'].toString(),
    })
        .toList();
  }

  /// Fetch Routes Data
  Future<List<Map<String, String>>> fetchRoutes() async {
    final data = await fetchData('get_routes.php');
    if (data == null || !data.containsKey('routedet')) return [];
    return (data['routedet'] as List<dynamic>)
        .map((e) => {
      "route_name": e['route_name'].toString(),
      "rtid": e['rtid'].toString(),
    })
        .toList();
  }
  /// Fetch Company Details
  Future<Map<String, dynamic>?> fetchCompanyDetails() async {
    final data = await fetchData('company_full_details.php');
    if (data == null) return null;
    return data;
  }

  /// Fetch Permission Details
  Future<PermissionResponse?> fetchPermissionDetails() async {
    final data = await fetchData('sales-executive-permission.php');
    if (data == null) return null;
    return PermissionResponse.fromJson(data);
  }

  /// Fetch product Details
  Future<List<Map<String, String>>> fetchProducts() async {
    final data = await fetchData('get_products.php');
    if (data == null || !data.containsKey('productdet')) return [];
    return (data['productdet'] as List<dynamic>)
        .map((e) => {
      "prd_name": e['prd_name'].toString(),
      "prd_id": e['prd_id'].toString(),
    })
        .toList();
  }

}







