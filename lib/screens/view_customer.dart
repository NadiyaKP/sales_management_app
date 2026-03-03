import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../screens/customers_page.dart';

class ViewCustomer extends StatelessWidget {
  final Customers customer;

  const ViewCustomer({Key? key, required this.customer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          // Call button - only show if phone number exists
          if (customer.phoneNo.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () => _makePhoneCall(customer.phoneNo),
              tooltip: 'Call Customer',
            ),
          // Email button - only show if email exists
          if (customer.email.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.email),
              onPressed: () => _sendEmail(customer.email),
              tooltip: 'Send Email',
            ),
          const SizedBox(width: 8), // Add some spacing from the edge
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailCard(),
            const SizedBox(height: 20),
            _buildStatusSection(),
          ],
        ),
      ),
    );
  }

  // Function to make phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'Could not launch phone dialer';
      }
    } catch (e) {
      print('Error launching phone dialer: $e');
      // You can add a SnackBar or dialog to show error to user
    }
  }

  // Function to send email
  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Regarding Your Account&body=Dear ${customer.name},%0A%0A',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      print('Error launching email client: $e');
      // You can add a SnackBar or dialog to show error to user
    }
  }

  Widget _buildDetailCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Basic Information'),
            const Divider(),
            _buildDetailRow('Name', customer.name),
            _buildDetailRow('Customer Type', '${customer.typeName} (${customer.typeofCustomer})'),
            _buildDetailRow('Status', customer.status.toUpperCase(), 
              isStatus: true, isActive: customer.status == "active"),
            
            const SizedBox(height: 20),
            _buildSectionHeader('Contact Information'),
            const Divider(),
            _buildDetailRow('Phone Number', customer.phoneNo),
            if (customer.landPhone.isNotEmpty) 
              _buildDetailRow('Landline', customer.landPhone),
            if (customer.email.isNotEmpty)
              _buildDetailRow('Email', customer.email),
            
            const SizedBox(height: 20),
            _buildSectionHeader('Address & Tax Information'),
            const Divider(),
            _buildDetailRow('Address', customer.address),
            _buildDetailRow('State', customer.state),
            if (customer.stateCode.isNotEmpty)
              _buildDetailRow('State Code', customer.stateCode),
            if (customer.gstNo.isNotEmpty)
              _buildDetailRow('GST Number', customer.gstNo),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Financial Information'),
            const Divider(),
            _buildDetailRow('Current Balance', '₹${customer.balance}'),
            _buildDetailRow('Opening Balance', '₹${customer.openBalance}'),
            _buildDetailRow('Balance Type', customer.openAccount.toUpperCase()),
            if (customer.noOfCreditsDays.isNotEmpty)
              _buildDetailRow('Credit Days', '${customer.noOfCreditsDays} days'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false, bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: isStatus
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: isActive ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}