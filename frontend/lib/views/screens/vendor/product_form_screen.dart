import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/providers/vendor_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/services/manage_http_response.dart';
import 'package:kurskart/views/widgets/labelled_field.dart';

/// Adds a product, or edits one the vendor already sells.
///
/// Images are entered as URLs for now — there is no upload pipeline yet, and
/// the seeded catalogue uses URLs too.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.existing});

  final Product? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _category;
  late final TextEditingController _stock;
  late final TextEditingController _imageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : '${p.price}');
    _category = TextEditingController(text: p?.category ?? '');
    _stock = TextEditingController(text: p == null ? '' : '${p.stock}');
    _imageUrl = TextEditingController(text: p?.primaryImage ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _price,
      _category,
      _stock,
      _imageUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(myProductsProvider.notifier);

    final url = _imageUrl.text.trim();
    final images = url.isEmpty ? <String>[] : [url];

    setState(() => _isSaving = true);
    try {
      if (widget.isEditing) {
        await notifier.updateProduct(
          widget.existing!.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: int.parse(_price.text.trim()),
          category: _category.text.trim(),
          stock: int.parse(_stock.text.trim()),
          images: images,
        );
      } else {
        await notifier.create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: int.parse(_price.text.trim()),
          category: _category.text.trim(),
          stock: int.parse(_stock.text.trim()),
          images: images,
        );
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Product updated' : 'Product added'),
        ),
      );
      navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnackBar(context, e.message);
    } catch (_) {
      if (mounted) {
        showSnackBar(context, 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _wholeNumber(String? value, String label, {required int min}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '$label is required';
    final parsed = int.tryParse(text);
    if (parsed == null) return '$label must be a whole number';
    if (parsed < min) return '$label cannot be less than $min';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Edit Product' : 'Add Product',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  LabelledField(
                    controller: _name,
                    label: 'Product name',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Name is required' : null,
                  ),
                  LabelledField(
                    controller: _description,
                    label: 'Description',
                    maxLines: 3,
                  ),
                  LabelledField(
                    controller: _category,
                    label: 'Category',
                    hint: 'Electronics, Fashion, Home…',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Category is required'
                        : null,
                  ),
                  LabelledField(
                    controller: _price,
                    label: 'Price (₹)',
                    keyboardType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _wholeNumber(v, 'Price', min: 0),
                  ),
                  LabelledField(
                    controller: _stock,
                    label: 'Stock',
                    keyboardType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _wholeNumber(v, 'Stock', min: 0),
                  ),
                  LabelledField(
                    controller: _imageUrl,
                    label: 'Image URL',
                    hint: 'https://…',
                    keyboardType: TextInputType.url,
                    // Rebuilds so the preview below follows what was typed.
                    validator: (_) => null,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Preview image'),
                    ),
                  ),
                  if (url.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey.shade100,
                              child: Center(
                                child: Text(
                                  'Could not load that image',
                                  style: GoogleFonts.nunitoSans(
                                    color: Colors.black45,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 47, 255),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.isEditing ? 'Save Changes' : 'Add Product',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
