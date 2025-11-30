// lib/widget/trip_essentials_tab.dart
// Trip Essentials Tab - Emergency info, currency converter, phrases, packing list
// All customized based on destination country

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/trip_essentials_controller.dart';
import '../utilities/country_data_helper.dart';
import '../utilities/currency_converter.dart';
import 'sweet_alert_dialog.dart';

class TripEssentialsTab extends StatefulWidget {
  final String tripId;
  final String destinationCity;
  final String destinationCountry;
  final String? destinationCurrency;

  const TripEssentialsTab({
    super.key,
    required this.tripId,
    required this.destinationCity,
    required this.destinationCountry,
    this.destinationCurrency,
  });

  @override
  State<TripEssentialsTab> createState() => _TripEssentialsTabState();
}

class _TripEssentialsTabState extends State<TripEssentialsTab> {
  final TripEssentialsController _controller = TripEssentialsController();
  late CountryEssentials _essentials;
  List<PackingItem> _packingList = [];
  bool _isLoadingPacking = true;

  // Currency converter state
  final TextEditingController _amountController = TextEditingController(text: '100');
  String _fromCurrency = 'MYR';
  String _toCurrency = 'USD';
  CurrencyResult? _conversionResult;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _essentials = _controller.getCountryEssentials(widget.destinationCountry);
    _toCurrency = widget.destinationCurrency ?? _essentials.currencyCode;
    _loadPackingList();
    _convertCurrency();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadPackingList() async {
    final items = await _controller.getPackingList(widget.tripId);
    if (mounted) {
      setState(() {
        _packingList = items;
        _isLoadingPacking = false;
      });
    }
  }

  Future<void> _convertCurrency() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _isConverting = true);

    final result = await _controller.convertCurrency(
      amount: amount,
      fromCurrency: _fromCurrency,
      toCurrency: _toCurrency,
    );

    if (mounted) {
      setState(() {
        _conversionResult = result;
        _isConverting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        _buildHeader(),
        const SizedBox(height: 20),

        // Emergency Contacts
        _buildEmergencySection(),
        const SizedBox(height: 20),

        // Currency Converter
        _buildCurrencyConverterSection(),
        const SizedBox(height: 20),

        // Quick Info
        _buildQuickInfoSection(),
        const SizedBox(height: 20),

        // Useful Phrases
        _buildPhrasesSection(),
        const SizedBox(height: 20),

        // Quick Links
        _buildQuickLinksSection(),
        const SizedBox(height: 20),

        // Packing Checklist
        _buildPackingSection(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[400]!, Colors.teal[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _essentials.flag,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trip Essentials',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.destinationCity}, ${widget.destinationCountry}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white.withOpacity(0.9), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Essential information customized for ${_essentials.country}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.emergency, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildEmergencyItem(
                  'Emergency',
                  _essentials.emergencyNumber,
                  Icons.warning_amber,
                  Colors.red,
                ),
                const SizedBox(height: 10),
                _buildEmergencyItem(
                  'Police',
                  _essentials.policeNumber,
                  Icons.local_police,
                  Colors.blue,
                ),
                const SizedBox(height: 10),
                _buildEmergencyItem(
                  'Ambulance',
                  _essentials.ambulanceNumber,
                  Icons.medical_services,
                  Colors.green,
                ),
                const SizedBox(height: 10),
                _buildEmergencyItem(
                  'Fire',
                  _essentials.fireNumber,
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                if (_essentials.touristPolice != null) ...[
                  const SizedBox(height: 10),
                  _buildEmergencyItem(
                    'Tourist Hotline',
                    _essentials.touristPolice!,
                    Icons.support_agent,
                    Colors.purple,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyItem(String label, String number, IconData icon, Color color) {
    return InkWell(
      onTap: () => _makeCall(number),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.call, color: color, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyConverterSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.currency_exchange, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Currency Converter',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (_conversionResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _conversionResult!.isLive ? Colors.green[600] : Colors.orange[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _conversionResult!.isLive ? 'LIVE' : 'OFFLINE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Amount input
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (_) => _convertCurrency(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _fromCurrency,
                            isExpanded: true,
                            items: CurrencyConverter.getSupportedCurrencies()
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _fromCurrency = value);
                                _convertCurrency();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Swap button
                Center(
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        final temp = _fromCurrency;
                        _fromCurrency = _toCurrency;
                        _toCurrency = temp;
                      });
                      _convertCurrency();
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.swap_vert, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Result
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _toCurrency,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            _isConverting
                                ? const SizedBox(
                              height: 28,
                              width: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : Text(
                              _conversionResult?.formattedConverted ?? '---',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _toCurrency,
                            items: CurrencyConverter.getSupportedCurrencies()
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _toCurrency = value);
                                _convertCurrency();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_conversionResult != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _conversionResult!.rateDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lightbulb, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Quick Info',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow('🕐', 'Timezone', _essentials.timezone),
                _buildInfoRow('🗣️', 'Language', _essentials.language),
                _buildInfoRow('💵', 'Currency', '${_essentials.currencyName} (${_essentials.currencySymbol})'),
                _buildInfoRow('🔌', 'Power Plug', _essentials.electricPlug),
                _buildInfoRow('⚡', 'Voltage', _essentials.voltage),
                _buildInfoRow('🚗', 'Driving Side', _essentials.drivingSide),
                _buildInfoRow('💰', 'Tipping', _essentials.tippingCustom),
                _buildInfoRow('💧', 'Water', _essentials.waterSafety),
                _buildInfoRow('💉', 'Vaccinations', _essentials.vaccinations),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhrasesSection() {
    if (_essentials.phrases.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.translate, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Useful Phrases',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _essentials.language,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _essentials.phrases.map((phrase) {
                return _buildPhraseItem(phrase);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhraseItem(PhraseItem phrase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: phrase.local));
          SweetAlertDialog.success(
            context: context,
            title: 'Copied!',
            subtitle: '"${phrase.local}" copied to clipboard',
          );
        },
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phrase.english,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phrase.local,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (phrase.pronunciation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '(${phrase.pronunciation})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.copy, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLinksSection() {
    if (_essentials.quickLinks.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Quick Links',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _essentials.quickLinks.map((link) {
                return _buildQuickLinkChip(link);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkChip(QuickLink link) {
    return InkWell(
      onTap: () => _launchUrl(link.url),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(link.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              link.title,
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 14, color: Colors.orange[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildPackingSection() {
    final progress = _controller.getPackingProgress(_packingList);
    final checkedCount = _packingList.where((item) => item.isChecked).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.checklist, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Packing Checklist',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '$checkedCount/${_packingList.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.indigo[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo[600]!),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress >= 1.0
                      ? '✅ All packed! You\'re ready to go!'
                      : '${(progress * 100).toInt()}% packed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.indigo[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingPacking)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _buildPackingList(),

          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addCustomItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo[700],
                      side: BorderSide(color: Colors.indigo[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetPackingList,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackingList() {
    // Group by category
    final grouped = <String, List<PackingItem>>{};
    for (final item in _packingList) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Column(
      children: grouped.entries.map((entry) {
        return ExpansionTile(
          title: Row(
            children: [
              Icon(_getCategoryIcon(entry.key), size: 20, color: Colors.indigo[600]),
              const SizedBox(width: 8),
              Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const Spacer(),
              Text(
                '${entry.value.where((i) => i.isChecked).length}/${entry.value.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          children: entry.value.asMap().entries.map((itemEntry) {
            final globalIndex = _packingList.indexOf(itemEntry.value);
            return _buildPackingItem(itemEntry.value, globalIndex);
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildPackingItem(PackingItem item, int index) {
    return Dismissible(
      key: Key('${item.name}_$index'),
      direction: item.isCustom ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        final items = await _controller.removePackingItem(widget.tripId, _packingList, index);
        setState(() => _packingList = items);
      },
      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (_) async {
            final items = await _controller.togglePackingItem(widget.tripId, _packingList, index);
            setState(() => _packingList = items);
          },
          activeColor: Colors.indigo[600],
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? Colors.grey : Colors.black87,
          ),
        ),
        trailing: item.isCustom
            ? Icon(Icons.person, size: 16, color: Colors.grey[400])
            : null,
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Documents':
        return Icons.folder;
      case 'Electronics':
        return Icons.devices;
      case 'Toiletries':
        return Icons.shower;
      case 'Clothing':
        return Icons.checkroom;
      case 'Miscellaneous':
        return Icons.category;
      default:
        return Icons.check_box;
    }
  }

  Future<void> _addCustomItem() async {
    final nameController = TextEditingController();
    String selectedCategory = 'Miscellaneous';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Documents', 'Electronics', 'Toiletries', 'Clothing', 'Miscellaneous']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final items = await _controller.addPackingItem(
        widget.tripId,
        _packingList,
        nameController.text,
        selectedCategory,
      );
      setState(() => _packingList = items);
    }

    nameController.dispose();
  }

  Future<void> _resetPackingList() async {
    final confirm = await SweetAlertDialog.confirm(
      context: context,
      title: 'Reset Packing List?',
      subtitle: 'This will reset all items to unchecked and remove custom items.',
      confirmText: 'Reset',
      cancelText: 'Cancel',
    );

    if (confirm == true) {
      final items = await _controller.resetPackingList(widget.tripId);
      setState(() => _packingList = items);
    }
  }

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Ignore
    }
  }
}