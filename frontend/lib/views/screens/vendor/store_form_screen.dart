import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/store.dart';
import 'package:kurskart/providers/vendor_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/services/manage_http_response.dart';
import 'package:kurskart/views/widgets/labelled_field.dart';

/// Opens a store, or edits the one the vendor already has. Passing [existing]
/// switches it to edit mode.
class StoreFormScreen extends ConsumerStatefulWidget {
  const StoreFormScreen({super.key, this.existing});

  final Store? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends ConsumerState<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _logoUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _description = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _logoUrl = TextEditingController(text: widget.existing?.logoUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(myStoreProvider.notifier);

    setState(() => _isSaving = true);
    try {
      if (widget.isEditing) {
        await notifier.updateStore(
          name: _name.text.trim(),
          description: _description.text.trim(),
          logoUrl: _logoUrl.text.trim(),
        );
      } else {
        await notifier.createStore(
          name: _name.text.trim(),
          description: _description.text.trim(),
          logoUrl: _logoUrl.text.trim(),
        );
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Store updated' : 'Your store is open',
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Edit Store' : 'Open Your Store',
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
                  if (!widget.isEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Give your store a name and it will appear on every '
                        'product you list.',
                        style: GoogleFonts.nunitoSans(color: Colors.black54),
                      ),
                    ),
                  LabelledField(
                    controller: _name,
                    label: 'Store name',
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Store name is required'
                        : null,
                  ),
                  LabelledField(
                    controller: _description,
                    label: 'Description (optional)',
                    maxLines: 3,
                  ),
                  LabelledField(
                    controller: _logoUrl,
                    label: 'Logo image URL (optional)',
                    hint: 'https://…',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
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
                              widget.isEditing ? 'Save Changes' : 'Open Store',
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
