import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart' as dio;

class StockMovementFilesModal extends StatefulWidget {
  final Map<String, dynamic> stockMovement;
  final VoidCallback onSuccess;

  const StockMovementFilesModal({super.key, required this.stockMovement, required this.onSuccess});

  @override
  State<StockMovementFilesModal> createState() => _StockMovementFilesModalState();
}

class _StockMovementFilesModalState extends State<StockMovementFilesModal> {
  List<dynamic> _documents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient().dio;
      final res = await client.get('/documents/documents/', queryParameters: {
        'stock_movement': widget.stockMovement['id'],
      });
      if (mounted) {
        setState(() {
          if (res.data is Map && res.data.containsKey('results')) {
            _documents = res.data['results'];
          } else if (res.data is List) {
            _documents = res.data;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDocument(int id) async {
    try {
      final client = ApiClient().dio;
      await client.delete('/documents/documents/$id/');
      await _fetchDocuments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sənəd silindi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xəta baş verdi')));
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddFileDisconnectWrapper(
        stockMovementId: widget.stockMovement['id'],
        onSuccess: () {
          Navigator.pop(context);
          _fetchDocuments();
        },
      ),
    );
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faylı açmaq mümkün olmadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 20),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sənədlər', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28))
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? const Center(child: Text('Sənəd yoxdur.'))
                    : ListView.separated(
                        itemCount: _documents.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.description, color: Colors.blue),
                            ),
                            title: Text(doc['title'] ?? 'Adsız', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(doc['created_at']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteDocument(doc['id']),
                            ),
                            onTap: () => _openFile(doc['file']), // 'file' field usually contains URL in DRF
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }
}

class _AddFileDisconnectWrapper extends StatefulWidget {
  final int stockMovementId;
  final VoidCallback onSuccess;

  const _AddFileDisconnectWrapper({required this.stockMovementId, required this.onSuccess});

  @override
  State<_AddFileDisconnectWrapper> createState() => _AddFileDisconnectWrapperState();
}

class _AddFileDisconnectWrapperState extends State<_AddFileDisconnectWrapper> {
  final _titleCtrl = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() => _selectedFile = result.files.first);
      }
    } catch (e) {
      //
    }
  }

  Future<void> _upload() async {
    if (_titleCtrl.text.isEmpty || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Başlıq və Fayl mütləqdir')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      dio.MultipartFile multipartFile;
      if (kIsWeb) {
        if (_selectedFile!.bytes != null) {
             multipartFile = dio.MultipartFile.fromBytes(_selectedFile!.bytes!, filename: _selectedFile!.name);
        } else {
             throw Exception("Web file bytes empty");
        }
      } else {
        if (_selectedFile!.path != null) {
             multipartFile = await dio.MultipartFile.fromFile(_selectedFile!.path!, filename: _selectedFile!.name);
        } else {
             throw Exception("File path empty");
        }
      }

      final formData = dio.FormData.fromMap({
        'stock_movement': widget.stockMovementId,
        'title': _titleCtrl.text,
        'file': multipartFile,
      });

      final client = ApiClient().dio;
      await client.post('/documents/documents/', data: formData);

      if (mounted) widget.onSuccess();

    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yükləmə xətası')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sənəd Əlavə Et'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Başlıq', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedFile?.name ?? 'Fayl Seçin')),
                ],
              ),
            ),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv et')),
        ElevatedButton(
          onPressed: _isUploading ? null : _upload,
          child: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Əlavə et'),
        ),
      ],
    );
  }
}
