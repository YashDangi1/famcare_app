import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'utils/snackbar_utils.dart';
import 'services/activity_service.dart';

class VaultScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const VaultScreen({super.key, this.targetUserId, this.targetUserName});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _prescriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchPrescriptions();
  }

  Future<void> _fetchPrescriptions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = widget.targetUserId ?? _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('prescriptions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) setState(() => _prescriptions = data);
    } catch (e) {
      debugPrint("Vault Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPrescription() async {
    final picker = ImagePicker();
    final titleController = TextEditingController();
    File? pickedImage;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Document', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(LucideIcons.camera),
                              title: const Text('Camera'),
                              onTap: () => Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(LucideIcons.image),
                              title: const Text('Gallery'),
                              onTap: () => Navigator.pop(context, ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (source != null) {
                      final image = await picker.pickImage(source: source, imageQuality: 50);
                      if (image != null) {
                        setDialogState(() => pickedImage = File(image.path));
                      }
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: pickedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.imagePlus, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to select image', style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(pickedImage!, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Document Title',
                    hintText: 'e.g., Blood Test Report',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (titleController.text.isEmpty || pickedImage == null) {
                  AppSnackBar.showError(context, 'Please provide title and image');
                  return;
                }

                // Show global loading if possible, or just wait
                Navigator.pop(dialogContext); // Close dialog
                _saveToSupabase(titleController.text, pickedImage!);
              },
              child: const Text('Save Document'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToSupabase(String title, File imageFile) async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 1. Upload to Storage
      await _supabase.storage.from('prescriptions').upload(fileName, imageFile);
      
      // 2. Get Public URL
      final imageUrl = _supabase.storage.from('prescriptions').getPublicUrl(fileName);

      // 3. Insert into Database
      await _supabase.from('prescriptions').insert({
        'user_id': user.id,
        'title': title,
        'image_url': imageUrl,
      });

      // Log activity for new vault document
      try {
        await ActivityService.log(
          actionType: 'VITALS_ADDED', // Vault is considered part of vitals/health records here
          description: 'Uploaded a new document: $title',
        );
      } catch (e) {
        debugPrint('Log error: $e');
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Document saved to vault!');
        _fetchPrescriptions();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Resolves a public URL to a signed URL if needed (for non-public buckets).
  Future<String> _resolveImageUrl(String imageUrl) async {
    try {
      // If the URL contains '/object/public/', it's already a public URL
      if (imageUrl.contains('/object/public/')) {
        return imageUrl;
      }
      // Extract the file path from the URL (after the bucket name)
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      // Find the bucket path — typically after 'object/sign/' or 'object/public/'
      final objectIndex = pathSegments.indexOf('object');
      if (objectIndex != -1 && objectIndex + 2 < pathSegments.length) {
        // pathSegments: [..., 'object', 'public' or 'sign', 'bucket', ...filePath]
        final bucket = pathSegments[objectIndex + 2];
        final filePath = pathSegments.sublist(objectIndex + 3).join('/');
        final signedUrl = await _supabase.storage.from(bucket).createSignedUrl(filePath, 3600);
        return signedUrl;
      }
      return imageUrl;
    } catch (e) {
      debugPrint('Image URL resolve error: $e');
      return imageUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isViewingOther = widget.targetUserId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.targetUserName != null ? "${widget.targetUserName}'s Vault" : "My Vault", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prescriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.folderHeart, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(isViewingOther ? 'No documents found' : 'Your vault is empty',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(isViewingOther ? 'This user has no uploaded documents yet' : 'Securely store your medical reports here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _prescriptions.length,
                  itemBuilder: (context, index) {
                    final doc = _prescriptions[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageViewer(
                            imageUrl: doc['image_url'],
                            title: doc['title'] ?? 'Untitled',
                          ),
                        ),
                      ),
                      child: Card(
                        elevation: 4,
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                child: FutureBuilder<String>(
                                  future: _resolveImageUrl(doc['image_url']),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                    }
                                    return Image.network(
                                      snapshot.data!,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                        const Center(child: Icon(LucideIcons.imageOff, color: Colors.grey)),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                doc['title'] ?? 'Untitled',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: isViewingOther ? null : FloatingActionButton(
        heroTag: 'vault_fab',
        onPressed: _uploadPrescription,
        backgroundColor: const Color(0xFF0EA5E9),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final _supabase = Supabase.instance.client;
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  Future<void> _resolveUrl() async {
    try {
      if (widget.imageUrl.contains('/object/public/')) {
        setState(() => _resolvedUrl = widget.imageUrl);
        return;
      }
      final uri = Uri.parse(widget.imageUrl);
      final pathSegments = uri.pathSegments;
      final objectIndex = pathSegments.indexOf('object');
      if (objectIndex != -1 && objectIndex + 2 < pathSegments.length) {
        final bucket = pathSegments[objectIndex + 2];
        final filePath = pathSegments.sublist(objectIndex + 3).join('/');
        final signedUrl = await _supabase.storage.from(bucket).createSignedUrl(filePath, 3600);
        if (mounted) setState(() => _resolvedUrl = signedUrl);
      } else {
        if (mounted) setState(() => _resolvedUrl = widget.imageUrl);
      }
    } catch (e) {
      debugPrint('Full image URL resolve error: $e');
      if (mounted) setState(() => _resolvedUrl = widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: _resolvedUrl == null
            ? const CircularProgressIndicator(color: Colors.white)
            : InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  _resolvedUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(LucideIcons.imageOff, color: Colors.white, size: 50)),
                ),
              ),
      ),
    );
  }
}
