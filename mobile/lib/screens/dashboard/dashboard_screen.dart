import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

List<String> eventImageUrls(dynamic event) {
  final imgs = event['images'];
  if (imgs is List && imgs.isNotEmpty) {
    final out = <String>[];
    for (final e in imgs) {
      if (e is Map && e['image'] != null) {
        out.add(e['image'].toString());
      }
    }
    if (out.isNotEmpty) return out;
  }
  if (event['image'] != null) return [event['image'].toString()];
  return [];
}

Future<void> showEventImagePreview(BuildContext context, List<String> urls, int initialIndex) async {
  if (urls.isEmpty) return;
  final safeIndex = initialIndex.clamp(0, urls.length - 1);
  final controller = PageController(initialPage: safeIndex);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: urls.length,
                itemBuilder: (_, idx) => InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(urls[idx], fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: Material(
                    color: Colors.black.withOpacity(0.65),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: 'Bağla',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  controller.dispose();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _events = [];
  List<dynamic> _topUsers = [];
  bool _isLoadingEvents = false;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _fetchStats();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      final response = await ApiClient().dio.get('/dashboard/events/?active_only=true');
      if (response.statusCode == 200) {
        setState(() {
          _events = response.data;
        });
      }
    } catch (e) {
      print('Failed to fetch events: $e');
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final response = await ApiClient().dio.get('/dashboard/stats/');
      if (response.statusCode == 200) {
        setState(() {
          _topUsers = response.data['tasks']['by_user'];
        });
      }
    } catch (e) {
      print('Failed to fetch stats: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _createEvent(dynamic data) async {
    try {
      dynamic payload;
      final images = data is Map<String, dynamic> ? data['images'] as List<XFile>? : null;
      if (images != null && images.isNotEmpty) {
        final formData = FormData.fromMap({
          'title': data['title'],
          'description': data['description'],
          'event_type': data['event_type'],
          'date': data['date'],
          'is_active': data['is_active'],
        });
        for (final x in images) {
          final MultipartFile mf;
          if (kIsWeb) {
            final bytes = await x.readAsBytes();
            mf = MultipartFile.fromBytes(bytes, filename: x.name);
          } else {
            mf = await MultipartFile.fromFile(x.path, filename: x.name);
          }
          formData.files.add(MapEntry('images', mf));
        }
        payload = formData;
      } else if (data is Map<String, dynamic> && data.containsKey('image') && data['image'] != null) {
        final XFile imageFile = data['image'];
        final MultipartFile multipartFile;
        if (kIsWeb) {
          final bytes = await imageFile.readAsBytes();
          multipartFile = MultipartFile.fromBytes(bytes, filename: imageFile.name);
        } else {
          multipartFile = await MultipartFile.fromFile(imageFile.path, filename: imageFile.name);
        }
        payload = FormData.fromMap({
          'title': data['title'],
          'description': data['description'],
          'event_type': data['event_type'],
          'date': data['date'],
          'is_active': data['is_active'],
          'image': multipartFile,
        });
      } else {
        payload = data;
      }
      await ApiClient().dio.post('/dashboard/events/', data: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Tədbir uğurla yaradıldı')),
        );
        _fetchEvents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Tədbir yaradıla bilmədi: $e')),
        );
      }
    }
  }

  void _showAddEventDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const AddEventForm(),
      ),
    ).then((result) {
      if (result != null) {
        _createEvent(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tədbirlər',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: _isLoadingEvents
                      ? const Center(child: CircularProgressIndicator())
                      : PageView.builder(
                          controller: PageController(viewportFraction: 0.85),
                          itemCount: _events.length + 1,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: index == 0
                                  ? _buildAddEventCard()
                                  : _buildEventCard(_events[index - 1]),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Ən yaxşı nəticə göstərənlər',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _isLoadingStats
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTopUsersList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopUsersList() {
    if (_topUsers.isEmpty) {
      return const Center(child: Text('Statistika mövcud deyil', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _topUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildUserTile(_topUsers[index], index + 1),
    );
  }

  Widget _buildUserTile(dynamic user, int rank) {
    final String fullName = '${user['assigned_to__first_name']} ${user['assigned_to__last_name']}';
    final int total = user['total_tasks'];
    final int done = user['done_tasks'];

    final String? avatarPath = user['assigned_to__avatar'];
    final String baseUrl = ApiClient().dio.options.baseUrl;
    // Remove /api suffix to get root URL for media
    final String rootUrl = baseUrl.endsWith('/api') 
        ? baseUrl.substring(0, baseUrl.length - 4) 
        : baseUrl;
    final String avatarUrl = avatarPath != null && avatarPath.isNotEmpty 
        ? '$rootUrl/media/$avatarPath' 
        : '';
    
    // debugPrint('Avatar info: $fullName -> $avatarUrl ($avatarPath)');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
        SizedBox(
          width: 30,
          child: Text(
            '#$rank',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty ? Text(
            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
            style: TextStyle(color: Colors.blue.shade800),
          ) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName.trim().isEmpty ? user['assigned_to__username'] : fullName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                user['assigned_to__group__name'] ?? 'Əməkdaş',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$done / $total',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Text(
              'Tamamlanan',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ],
      ),
    );
  }

  Widget _buildAddEventCard() {
    return GestureDetector(
      onTap: _showAddEventDialog,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
             BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.blue, size: 28),
            ),
            const SizedBox(height: 8),
            const Text(
               'Tədbir əlavə et',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEvent(int id) async {
    try {
      await ApiClient().dio.delete('/dashboard/events/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Tədbir uğurla silindi')),
        );
        _fetchEvents();
        Navigator.pop(context); // Close modal
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Tədbir silinə bilmədi: $e')),
        );
      }
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
         title: const Text('Tədbiri Sil'),
        content: const Text('Bu tədbiri silmək istədiyinizə əminsiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ləğv et'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              _deleteEvent(id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showEventDetailModal(dynamic event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event['event_type_display'] ?? 'Event',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(event['id']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                event['title'] ?? 'Başlıqsız',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                   const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                   const SizedBox(width: 8),
                   Text(
                     DateFormat('EEEE, d MMMM yyyy, HH:mm').format(DateTime.parse(event['date'])),
                     style: const TextStyle(color: Colors.grey, fontSize: 14),
                   ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Təsvir',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                event['description'] ?? 'Təsvir əlavə olunmayıb.',
                style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
              ),
              const SizedBox(height: 32),
              if (eventImageUrls(event).isNotEmpty) ...[
                _EventImageCollageDetail(urls: eventImageUrls(event)),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final DateTime date = DateTime.parse(event['date']);
    final String month = DateFormat('MMM').format(date);
    final String day = DateFormat('d').format(date);
    final String time = DateFormat('HH:mm').format(date);
    final urls = eventImageUrls(event);

    return InkWell(
      onTap: () => _showEventDetailModal(event),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 220, // Event + “əlavə et” kartları ilə eyni hündürlük
        padding: const EdgeInsets.all(4), // Padding creates the "border" effect
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (urls.isNotEmpty)
                _EventImageCollageCard(urls: urls)
              else
                Container(
                  color: Colors.grey[100],
                  child: const Center(
                    child: Icon(Icons.event, size: 48, color: Colors.grey),
                  ),
                ),
              // Dark gradient overlay for text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event['event_type_display'] ?? 'Event',
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Stroked Time Text
                        Stack(
                          children: [
                            Text(time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.black)),
                            Text(time, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stroked Title Text
                        Stack(
                          children: [
                            Text(
                              event['title'] ?? 'Başlıqsız',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.black),
                            ),
                            Text(
                              event['title'] ?? 'Başlıqsız',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            // Stroked Date Text
                            Stack(
                              children: [
                                Text('$day $month', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.black)),
                                Text('$day $month', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventImageCollageCard extends StatelessWidget {
  const _EventImageCollageCard({required this.urls});
  final List<String> urls;

  static Widget _cell(String url, {String? overlay}) {
    return Expanded(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(url, fit: BoxFit.cover),
          if (overlay != null)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Text(
                overlay,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return Image.network(urls[0], fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    if (urls.length == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(urls[0]),
          const SizedBox(height: 2),
          _cell(urls[1]),
        ],
      );
    }
    if (urls.length == 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(urls[0]),
          const SizedBox(height: 2),
          _cell(urls[1]),
          const SizedBox(height: 2),
          _cell(urls[2]),
        ],
      );
    }
    final more = urls.length > 4 ? '+${urls.length - 4}' : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cell(urls[0]),
        const SizedBox(height: 2),
        _cell(urls[1]),
        const SizedBox(height: 2),
        _cell(urls[2]),
        const SizedBox(height: 2),
        _cell(urls[3], overlay: more),
      ],
    );
  }
}

class _EventImageCollageDetail extends StatelessWidget {
  const _EventImageCollageDetail({required this.urls});
  final List<String> urls;

  Widget _tapCell(BuildContext context, int index, {String? overlay}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showEventImagePreview(context, urls, index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(urls[index], fit: BoxFit.cover),
              if (overlay != null)
                IgnorePointer(
                  child: Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Text(
                      overlay,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: InkWell(
            onTap: () => showEventImagePreview(context, urls, 0),
            child: Image.network(urls[0], fit: BoxFit.cover, width: double.infinity),
          ),
        ),
      );
    }
    if (urls.length == 2) {
      return SizedBox(
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _tapCell(context, 0)),
            const SizedBox(height: 6),
            Expanded(child: _tapCell(context, 1)),
          ],
        ),
      );
    }
    if (urls.length == 3) {
      return SizedBox(
        height: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _tapCell(context, 0)),
            const SizedBox(height: 6),
            Expanded(child: _tapCell(context, 1)),
            const SizedBox(height: 6),
            Expanded(child: _tapCell(context, 2)),
          ],
        ),
      );
    }
    final more = urls.length > 4 ? '+${urls.length - 4}' : null;
    return SizedBox(
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _tapCell(context, 0)),
          const SizedBox(height: 6),
          Expanded(child: _tapCell(context, 1)),
          const SizedBox(height: 6),
          Expanded(child: _tapCell(context, 2)),
          const SizedBox(height: 6),
          Expanded(child: _tapCell(context, 3, overlay: more)),
        ],
      ),
    );
  }
}

class AddEventForm extends StatefulWidget {
  const AddEventForm({super.key});

  @override
  State<AddEventForm> createState() => _AddEventFormState();
}

class _AddEventFormState extends State<AddEventForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _eventType = 'meeting'; // Default
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<XFile> _selectedImages = [];

  Future<void> _pickSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Qalereya (bir neçə)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickGalleryMultiple();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickGalleryMultiple() async {
    final picker = ImagePicker();
    final list = await picker.pickMultiImage(imageQuality: 85);
    if (list.isNotEmpty) {
      setState(() => _selectedImages.addAll(list));
    }
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) setState(() => _selectedImages.add(x));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Text('Yeni Tədbir Yarat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                   labelText: 'Başlıq',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Tələb olunur' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                   labelText: 'Təsvir',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickSourceSheet,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Şəkil əlavə et (qalereya / kamera)'),
              ),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final x = _selectedImages[i];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 88,
                              height: 88,
                              child: kIsWeb
                                  ? Image.network(x.path, fit: BoxFit.cover)
                                  : Image.file(File(x.path), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Material(
                              color: Colors.red,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => setState(() => _selectedImages.removeAt(i)),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _eventType,
                decoration: const InputDecoration(
                   labelText: 'Növ',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'meeting', child: Text('İclas')),
                  DropdownMenuItem(value: 'holiday', child: Text('Bayram')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Texniki işlər')),
                  DropdownMenuItem(value: 'announcement', child: Text('Elan')),
                  DropdownMenuItem(value: 'other', child: Text('Digər')),
                ],
                onChanged: (v) => setState(() => _eventType = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _selectedDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(_selectedTime.format(context)),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (t != null) setState(() => _selectedTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final dt = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        _selectedTime.hour,
                        _selectedTime.minute,
                      );
                      Navigator.pop(context, {
                        'title': _titleController.text,
                        'description': _descController.text,
                        'event_type': _eventType,
                        'date': dt.toIso8601String(),
                        'is_active': true,
                        if (_selectedImages.isNotEmpty) 'images': List<XFile>.from(_selectedImages),
                      });
                    }
                  },
                  child: const Text('Tədbir Yarat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
