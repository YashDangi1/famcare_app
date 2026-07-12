import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/health/health_record.dart';
import '../../providers/health/records_provider.dart';
import 'record_upload_sheet.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? targetUserName;
  final bool hideAppBar;

  const RecordsScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
    this.hideAppBar = false,
  });

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'All', 'Prescription', 'Lab Report', 'Imaging', 'Discharge Summary', 'Doctor Note', 'Vaccine', 'Other'
  ];
  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchRecords());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecords() async {
    if (widget.targetUserId != null) {
      bool canView = false;
      try {
        final familyResponse = await Supabase.instance.client
            .from('family_members')
            .select('can_view_records')
            .eq('user_id', widget.targetUserId as Object)
            .limit(1);

        if (familyResponse.isNotEmpty) {
          canView = familyResponse.first['can_view_records'] == true;
        }
      } catch (e) {
        debugPrint('Error checking view permission: $e');
      }

      if (!canView) {
        if (mounted) {
          setState(() {
            _accessDenied = true;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _accessDenied = false;
      });
    }

    ref.read(recordsProvider.notifier).fetchRecords(
      userId: widget.targetUserId,
      category: _selectedCategory,
    );
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordUploadSheet(
        targetUserId: widget.targetUserId,
        currentCategoryFilter: _selectedCategory,
      ),
    );
  }

  Future<void> _deleteRecord(HealthRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Are you sure you want to delete "${record.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && record.id != null) {
      try {
        await ref.read(recordsProvider.notifier).deleteRecord(record.id!, targetUserId: widget.targetUserId, currentCategory: _selectedCategory);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record deleted')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsState = ref.watch(recordsProvider);
    final isViewingOther = widget.targetUserId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.hideAppBar ? null : AppBar(
        title: Text(widget.targetUserName != null ? "${widget.targetUserName}'s Records" : 'My Records', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: isViewingOther
          ? null
          : FloatingActionButton(
              heroTag: 'upload_record_fab',
              onPressed: _showUploadSheet,
              backgroundColor: const Color(0xFF0EA5E9),
              child: const Icon(LucideIcons.upload, color: Colors.white),
            ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterRow(),
          Expanded(
            child: _accessDenied
                ? const AccessDeniedWidget()
                : recordsState.when(
              loading: () => _buildSkeletonLoader(),
              error: (err, stack) {
                if (err.toString().contains('PERMISSION_DENIED')) {
                  return const AccessDeniedWidget();
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error loading records: $err'),
                      TextButton(onPressed: _fetchRecords, child: const Text('Retry')),
                    ],
                  ),
                );
              },
              data: (records) {
                // Filter locally by search query
                final filteredRecords = records.where((r) {
                  if (_searchQuery.isEmpty) return true;
                  return r.title.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredRecords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.folderHeart, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          isViewingOther ? 'No documents found' : 'No records found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isViewingOther ? 'This user has no uploaded documents matching your criteria.' : 'No records match your search or filter.',
                          style: TextStyle(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _fetchRecords(),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, index) {
                      return _buildRecordCard(filteredRecords[index], isViewingOther);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search records...',
          prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _categories.map((c) {
            final isSelected = _selectedCategory == c;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(c),
                selected: isSelected,
                onSelected: (val) {
                  if (val) {
                    setState(() => _selectedCategory = c);
                    _fetchRecords();
                  }
                },
                selectedColor: const Color(0xFF0EA5E9).withOpacity(0.15),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0EA5E9).withOpacity(0.5) : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecordCard(HealthRecord record, bool isViewingOther) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenImageViewer(
              imageUrl: record.fileUrl,
              title: record.title,
            ),
          ),
        );
      },
      onLongPress: isViewingOther ? null : () {
        _deleteRecord(record);
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.grey.shade100),
                  // Image
                  FutureBuilder<String>(
                    future: _resolveImageUrl(record.fileUrl),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(LucideIcons.imageOff, color: Colors.grey, size: 40)),
                      );
                    },
                  ),
                  // Category Badge
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        record.category.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.calendar, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        record.recordDate != null ? DateFormat('dd MMM yyyy').format(record.recordDate!) : 'Unknown',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Future<String> _resolveImageUrl(String imageUrl) async {
    try {
      final supabase = Supabase.instance.client;
      if (imageUrl.contains('/object/public/')) return imageUrl;
      
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final objectIndex = pathSegments.indexOf('object');
      if (objectIndex != -1 && objectIndex + 2 < pathSegments.length) {
        final bucket = pathSegments[objectIndex + 2];
        final filePath = pathSegments.sublist(objectIndex + 3).join('/');
        final signedUrl = await supabase.storage.from(bucket).createSignedUrl(filePath, 3600);
        return signedUrl;
      }
      return imageUrl;
    } catch (e) {
      return imageUrl;
    }
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;

  const FullScreenImageViewer({super.key, required this.imageUrl, required this.title});

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
      ),
      body: Center(
        child: _resolvedUrl == null
            ? const CircularProgressIndicator(color: Colors.white)
            : InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  _resolvedUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                ),
              ),
      ),
    );
  }
}

class AccessDeniedWidget extends StatelessWidget {
  const AccessDeniedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.lock, size: 80, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(fontSize: 18, color: Colors.red[600], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have permission to view these records.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
