import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/providers/vendor_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/services/manage_http_response.dart';
import 'package:kurskart/services/upload_service.dart';
import 'package:kurskart/views/widgets/labelled_field.dart';

/// Adds a product, or edits one the vendor already sells.
///
/// The image is picked from the device and uploaded before the form is saved,
/// so the product itself still stores nothing but a URL. Pasting a link is kept
/// as a fallback: the seeded catalogue is all URLs, and it is the only way to
/// set an image on a device with no usable camera or gallery.
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

  /// Belongs to the "paste a link" dialog, but lives for as long as the screen
  /// does — see [_pasteLink].
  final _link = TextEditingController();

  bool _isSaving = false;

  /// The image as it will be stored: always a URL, whether it came from an
  /// upload or was pasted in. Null means the product has no image.
  String? _imageUrl;
  bool _isUploading = false;

  /// An image uploaded during this visit that no product refers to yet. If it
  /// is replaced, removed, or the vendor leaves without saving, it has to be
  /// deleted from Cloudinary — nothing else would ever point at it.
  ///
  /// Cleared on save, at which point the product owns it and the server takes
  /// over responsibility for cleaning it up.
  String? _unsavedUpload;

  /// Kept so the cleanup can still run from [dispose], where reading the token
  /// asynchronously is no longer possible.
  String? _token;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : '${p.price}');
    _category = TextEditingController(text: p?.category ?? '');
    _stock = TextEditingController(text: p == null ? '' : '${p.stock}');
    _imageUrl = p?.primaryImage;
  }

  @override
  void dispose() {
    // Leaving without saving: whatever was uploaded here is now unreachable.
    _discardUnsavedUpload();

    for (final c in [_name, _description, _price, _category, _stock, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Releases the pending upload, if there is one. Deliberately not awaited —
  /// it runs from [dispose] as well, and the vendor should never wait on it.
  void _discardUnsavedUpload() {
    final url = _unsavedUpload;
    final token = _token;
    _unsavedUpload = null;

    if (url == null || token == null) return;
    const UploadService().discardUpload(token, url);
  }

  /// Picks an image and uploads it straight away, so by the time the vendor
  /// saves there is nothing left to wait for. Downscaling happens in the picker
  /// rather than after: a full-resolution tablet photo is several megabytes,
  /// and none of that detail survives a product thumbnail.
  Future<void> _pickImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      // Thrown when the camera or gallery permission was refused, and on
      // emulators with no camera at all.
      if (mounted) showSnackBar(context, e.message ?? 'Could not open the picker.');
      return;
    }

    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const ApiException('Please sign in again.');
      _token = token;

      final url = await ref
          .read(uploadServiceProvider)
          .uploadProductImage(token, File(picked.path));

      // Whatever was uploaded a moment ago is now unreachable.
      _discardUnsavedUpload();

      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _unsavedUpload = url;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Image uploaded')));
    } on ApiException catch (e) {
      if (mounted) showSnackBar(context, e.message);
    } catch (_) {
      if (mounted) showSnackBar(context, 'Could not upload that image.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pasteLink() async {
    // Owned by the screen rather than the dialog. Disposing it as soon as
    // showDialog returns crashes the closing animation, which goes on
    // rebuilding the TextField for a few frames after the result is in.
    final controller = _link..text = _imageUrl ?? '';

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Image link', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Use link'),
          ),
        ],
      ),
    );

    if (url == null) return;

    // A pasted link replaces any upload made here, stranding it.
    _discardUnsavedUpload();
    setState(() => _imageUrl = url.isEmpty ? null : url);
  }

  void _showImageOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Paste a link instead'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pasteLink();
              },
            ),
            if (_imageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove image', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _discardUnsavedUpload();
                  setState(() => _imageUrl = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(myProductsProvider.notifier);

    final url = _imageUrl?.trim() ?? '';
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
      // Saved, so the product owns the image now and the server is responsible
      // for it — dispose must not delete what was just stored.
      _unsavedUpload = null;

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
    final url = _imageUrl?.trim() ?? '';

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
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(
                      'Photo',
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  _ImageTile(
                    url: url.isEmpty ? null : url,
                    isUploading: _isUploading,
                    onTap: _isUploading ? null : _showImageOptions,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 47, 255),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      // Disabled mid-upload so a quick save cannot beat the
                      // image to the server and store the product without it.
                      onPressed: _isSaving || _isUploading ? null : _save,
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

/// The product photo, or an invitation to add one. Tapping anywhere opens the
/// same sheet, so there is no separate control to hunt for once an image is set.
class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.url, required this.isUploading, this.onTap});

  final String? url;
  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _Placeholder(
                    icon: Icons.broken_image_outlined,
                    label: 'Could not load that image',
                  ),
                )
              else
                const _Placeholder(
                  icon: Icons.add_a_photo_outlined,
                  label: 'Add a photo',
                ),
              if (isUploading)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 34, color: Colors.black38),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.nunitoSans(color: Colors.black45)),
      ],
    );
  }
}
