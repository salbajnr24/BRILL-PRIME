import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/payment_methods_provider.dart';
import '../../models/payment_method_model.dart';
import 'package:flutter/services.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaymentMethodsProvider()..getPaymentMethods(context: context),
      child: Consumer<PaymentMethodsProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payment Methods')),
            body: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (provider.errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(provider.errorMessage, style: const TextStyle(color: Colors.red)),
                        ),
                      Expanded(
                        child: provider.paymentMethods.isEmpty
                            ? const Center(child: Text('No saved cards.'))
                            : ListView.builder(
                                itemCount: provider.paymentMethods.length,
                                itemBuilder: (context, index) {
                                  final card = provider.paymentMethods[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: ListTile(
                                      leading: _brandIcon(card.brand),
                                      title: Row(
                                        children: [
                                          Text('**** **** **** ${card.last4}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          if (card.isDefault)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text('Default', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text('${card.brand}  Exp: ${card.expiryMonth}/${card.expiryYear}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!card.isDefault)
                                            IconButton(
                                              icon: const Icon(Icons.star_border, color: Colors.orange),
                                              tooltip: 'Set as Default',
                                              onPressed: () async {
                                                final success = await provider.setDefaultCard(context: context, cardId: card.id);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(success ? 'Set as default' : provider.errorMessage)),
                                                );
                                              },
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              await provider.deletePaymentMethod(context: context, cardId: card.id);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(provider.errorMessage.isEmpty ? 'Card deleted' : provider.errorMessage)),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Card'),
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (context) => _AddCardDialog(provider: provider),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

Widget _brandIcon(String brand) {
  switch (brand.toLowerCase()) {
    case 'visa':
      return const Icon(Icons.credit_card, color: Colors.blue);
    case 'mastercard':
      return const Icon(Icons.credit_card, color: Colors.red);
    case 'verve':
      return const Icon(Icons.credit_card, color: Colors.green);
    default:
      return const Icon(Icons.credit_card, color: Colors.grey);
  }
}

class _AddCardDialog extends StatefulWidget {
  final PaymentMethodsProvider provider;
  const _AddCardDialog({required this.provider});

  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cardHolderNameController = TextEditingController();
  String? _selectedBrand;
  final List<String> _brands = ['Visa', 'MasterCard', 'Verve'];

  String? _validateCardNumber(String? value) {
    if (value == null || value.length < 12 || value.length > 19) return 'Enter valid card number';
    if (!RegExp(r'^\d+ $').hasMatch(value)) return 'Numbers only';
    if (!_luhnCheck(value)) return 'Invalid card number';
    return null;
  }

  String? _validateExpiryMonth(String? value) {
    if (value == null || value.length != 2) return 'MM';
    final month = int.tryParse(value);
    if (month == null || month < 1 || month > 12) return 'MM';
    return null;
  }

  String? _validateExpiryYear(String? value) {
    if (value == null || value.length != 2) return 'YY';
    final now = DateTime.now();
    final year = int.tryParse(value);
    if (year == null) return 'YY';
    final fullYear = 2000 + year;
    if (fullYear < now.year || fullYear > now.year + 20) return 'YY';
    // Check not expired
    if (fullYear == now.year) {
      final month = int.tryParse(_expiryMonthController.text);
      if (month != null && month < now.month) return 'Expired';
    }
    return null;
  }

  String? _validateCardHolderName(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (!RegExp(r'^[A-Za-z ]+ $').hasMatch(value)) return 'Letters only';
    return null;
  }

  String? _validateBrand(String? value) {
    if (value == null || value.isEmpty) return 'Select brand';
    return null;
  }

  bool _luhnCheck(String number) {
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Card'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _cardNumberController,
                decoration: const InputDecoration(labelText: 'Card Number'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateCardNumber,
                maxLength: 19,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryMonthController,
                      decoration: const InputDecoration(labelText: 'MM'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateExpiryMonth,
                      maxLength: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _expiryYearController,
                      decoration: const InputDecoration(labelText: 'YY'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateExpiryYear,
                      maxLength: 2,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _cardHolderNameController,
                decoration: const InputDecoration(labelText: 'Cardholder Name'),
                validator: _validateCardHolderName,
              ),
              DropdownButtonFormField<String>(
                value: _selectedBrand,
                items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setState(() => _selectedBrand = v),
                decoration: const InputDecoration(labelText: 'Brand'),
                validator: _validateBrand,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final cardData = {
                'cardNumber': _cardNumberController.text,
                'expiryMonth': _expiryMonthController.text,
                'expiryYear': _expiryYearController.text,
                'cardHolderName': _cardHolderNameController.text,
                'brand': _selectedBrand ?? '',
                'last4': _cardNumberController.text.substring(_cardNumberController.text.length - 4),
                'cardType': 'credit',
              };
              final success = await widget.provider.addPaymentMethod(context: context, cardData: cardData);
              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card added')));
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
} 