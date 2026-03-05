import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

/// Fetches available financial years from the API.
/// Called by both [FinancialYearDialog] and the bottom nav button.
Future<List<Map<String, String>>> fetchFinancialYears() async {
  final prefs = await SharedPreferences.getInstance();
  final String? url  = prefs.getString('url');
  final String? unid = prefs.getString('unid');
  final String? slex = prefs.getString('slex');

  if (url == null || unid == null || slex == null) return [];

  final response = await http.post(
    Uri.parse('$url/get_financial_year.php'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'unid': unid, 'slex': slex}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['result'] == '1') {
      final List<dynamic> list = data['runn_financial_year'] ?? [];
      return list
          .map<Map<String, String>>((e) => {
                'finid': e['finid']?.toString() ?? '',
                'financial_year': e['financial_year']?.toString() ?? '',
              })
          .toList();
    }
  }
  return [];
}

/// Shows the Financial Year dialog.
/// Pass [barrierDismissible] = false when it is a forced first-login prompt.
Future<void> showFinancialYearDialog(
  BuildContext context, {
  bool barrierDismissible = true,
}) {
  return showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (context) => WillPopScope(
      // Prevent back-button dismissal when forced
      onWillPop: () async => barrierDismissible,
      child: FinancialYearDialog(
        barrierDismissible: barrierDismissible,
      ),
    ),
  );
}

// ─── Dialog widget ────────────────────────────────────────────────────────────

class FinancialYearDialog extends StatefulWidget {
  /// When false the close (×) button is hidden and the dialog cannot be
  /// dismissed without confirming a year — used for the first-login prompt.
  final bool barrierDismissible;

  const FinancialYearDialog({
    super.key,
    this.barrierDismissible = true,
  });

  @override
  State<FinancialYearDialog> createState() => _FinancialYearDialogState();
}

class _FinancialYearDialogState extends State<FinancialYearDialog> {
  bool _isLoading    = true;
  bool _isConfirming = false;
  String? _errorMessage;

  List<Map<String, String>> _years = [];

  /// finid the user has tapped (pending — not yet confirmed)
  String? _pendingFinId;

  /// Human-readable label stored in SharedPreferences after last confirm
  String? _currentFinancialYear;

  /// finid stored in SharedPreferences after last confirm (for "Current" badge)
  String? _savedFinId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      // 'selected_financial_year' is the canonical key checked by home_page.
      // Fall back to 'current_financial_year' for backward compatibility.
      final savedFinancialYear = prefs.getString('selected_financial_year')
                              ?? prefs.getString('current_financial_year');
      final savedFinId         = prefs.getString('selected_finid');

      final years = await fetchFinancialYears();

      if (!mounted) return;
      setState(() {
        _years                = years;
        _isLoading            = false;
        _currentFinancialYear = savedFinancialYear;
        _savedFinId           = savedFinId;
        _pendingFinId         = savedFinId; // pre-highlight saved entry
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading    = false;
        _errorMessage = 'Failed to load financial years.';
      });
    }
  }

  // ── API call on Confirm ───────────────────────────────────────────────────

  Future<void> _confirmSelection() async {
    if (_pendingFinId == null) return;

    final selected = _years.firstWhere(
      (y) => y['finid'] == _pendingFinId,
      orElse: () => {},
    );
    if (selected.isEmpty) return;

    final selectedLabel = selected['financial_year'] ?? '';

    setState(() => _isConfirming = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? url  = prefs.getString('url');
      final String? unid = prefs.getString('unid');
      final String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        setState(() => _isConfirming = false);
        _showSnackBar('Session expired. Please login again.', isError: true);
        return;
      }

      final response = await http.post(
        Uri.parse('$url/action/financial-year.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'unid': unid,
          'slex': slex,
          'finid': _pendingFinId,
        }),
      );

      if (!mounted) return;
      setState(() => _isConfirming = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] == '1') {
          await prefs.setString('selected_financial_year', selectedLabel);
          await prefs.setString('current_financial_year', selectedLabel);
          await prefs.setString('selected_finid', _pendingFinId!);

          if (!mounted) return;
          Navigator.pop(context);
          _showSnackBar(
            data['message'] ?? 'Financial year set to $selectedLabel',
            isError: false,
          );
        } else {
          _showSnackBar(
            data['message'] ?? 'Failed to update financial year.',
            isError: true,
          );
        }
      } else {
        _showSnackBar('Server error: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildBody(),
            if (!_isLoading && _errorMessage == null) _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Financial Year',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                // Extra subtitle only when this is a forced prompt
                if (!widget.barrierDismissible)
                  const Text(
                    'Please select a financial year to continue',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Hide × when dialog is mandatory
          if (widget.barrierDismissible)
            GestureDetector(
              onTap: _isConfirming ? null : () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        CircularProgressIndicator(color: AppTheme.primaryColor),
        const SizedBox(height: 16),
        Text('Loading financial years...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Icon(Icons.error_outline, color: Colors.red.shade400, size: 40),
        const SizedBox(height: 8),
        Text(
          _errorMessage!,
          style: TextStyle(color: Colors.red.shade600, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Current Financial Year banner ──────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.event_available,
                  color: AppTheme.primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Current Financial Year:  ',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: _currentFinancialYear ?? 'Not set',
                        style: TextStyle(
                          color: _currentFinancialYear != null
                              ? AppTheme.primaryColor
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Select Financial Year',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),

        // ── Year list ──────────────────────────────────────────────────
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _years.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final year      = _years[index];
              final finId     = year['finid'] ?? '';
              final yearLabel = year['financial_year'] ?? '';

              final isPending = finId == _pendingFinId;
              final isSaved   = finId == _savedFinId;

              return GestureDetector(
                onTap: _isConfirming
                    ? null
                    : () => setState(() => _pendingFinId = finId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isPending
                        ? AppTheme.primaryColor
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPending
                          ? AppTheme.primaryColor
                          : isSaved
                              ? AppTheme.primaryColor.withOpacity(0.4)
                              : Colors.grey.shade300,
                      width: isPending || isSaved ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 18,
                        color: isPending
                            ? Colors.white
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          yearLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isPending
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isPending
                                ? Colors.white
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      if (isPending)
                        const Icon(Icons.check,
                            color: Colors.white, size: 18),
                      if (!isPending && isSaved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Row(
        children: [
          // Hide Cancel when dialog is mandatory
          if (widget.barrierDismissible) ...[
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isConfirming ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: (_isConfirming || _pendingFinId == null)
                  ? null
                  : _confirmSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primaryColor.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}