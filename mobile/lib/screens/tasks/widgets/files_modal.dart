import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:mobile/core/api/api_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart' as dio;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/constants.dart';
import 'dart:io'; 

class FilesModal extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onSuccess; // To refresh task data parent

  const FilesModal({super.key, required this.task, required this.onSuccess});

  @override
  State<FilesModal> createState() => _FilesModalState();
}

class _FilesModalState extends State<FilesModal> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  // Local list to reflect immediate changes before parent refresh
  // Actually simpler to rely on parent refresh, but for smooth UI we might want local updates?
  // Let's rely on widget.task['task_documents'] re-rendering after onSuccess called.
  // Wait, if onSuccess triggers parent refresh, does parent rebuild THIS modal? 
  // ONLY if this modal is rebuilt by parent. 
  // `showModalBottomSheet` builder is usually independent unless parent updates it.
  // We might need to fetch documents ourselves OR close modal on success.
  // User said "dussun siyahiya" (fall into list).
  // Better to FETCH documents inside this modal or rely on `onSuccess` doing a quick refresh if possible.
  // But usually `showModalBottomSheet` context usage with `fetch` in parent...
  // Safest: Use local state for list, initialized from task, and fetch updates locally.
  
  List<dynamic> _documents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _documents = List.from(widget.task['task_documents'] ?? []);
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    try {
      // Fetch task details again to get fresh documents
      // Or fetch /tasks/task-documents/?task=... if filtering supported.
      // TaskViewSet retrieve is best source.
      final client = ApiClient().dio;
      final res = await client.get('/tasks/tasks/${widget.task['id']}/');
      if (mounted) {
        setState(() {
          _documents = res.data['task_documents'] ?? [];
          _isLoading = false;
        });
        widget.onSuccess(); // Notify parent too
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddFileDisconnectWrapper(
         taskId: widget.task['id'],
         onSuccess: () {
           Navigator.pop(context); // Close dialog
           _fetchDocuments();
         },
      ),
    );
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    // Resolve URL if needed (backend serializer usually gives full absolute URI now?)
    // TaskDocumentSerializer: `return request.build_absolute_uri(obj.file.url)`
    // So it should be absolute.
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Try resolving manually if backend failed
      // Or show error
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
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
              const Text('Files', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28))
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty 
                    ? const Center(child: Text('No files attached.'))
                    : ListView.separated(
                        itemCount: _documents.length,
                        separatorBuilder: (_,__) => const Divider(),
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)
                              ),
                              child: const Icon(Icons.description, color: Colors.blue),
                            ),
                            title: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(doc['created_at']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteDocument(doc['id']),
                            ),
                            onTap: () => _openFile(doc['file_url']),
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
  final int taskId;
  final VoidCallback onSuccess;

  const _AddFileDisconnectWrapper({required this.taskId, required this.onSuccess});

  @override
  State<_AddFileDisconnectWrapper> createState() => _AddFileDisconnectWrapperState();
}

class _AddFileDisconnectWrapperState extends State<_AddFileDisconnectWrapper> {
  final _titleCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      // Or pickVideo if needed? 
      // For general "docs", maybe allow user to choose? 
      // ImagePicker only does image/video.
      if (file != null) {
        setState(() => _selectedFile = file);
      }
    } catch(e) {
      //
    }
  }
  
  Future<void> _upload() async {
    if (_titleCtrl.text.isEmpty || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and File are required')));
      return;
    }
    
    setState(() => _isUploading = true);
    
    try {
      dio.MultipartFile multipartFile;
      if (kIsWeb) {
         final bytes = await _selectedFile!.readAsBytes();
         multipartFile = dio.MultipartFile.fromBytes(bytes, filename: _selectedFile!.name);
      } else {
         multipartFile = await dio.MultipartFile.fromFile(_selectedFile!.path, filename: _selectedFile!.name);
      }
      
      final formData = dio.FormData.fromMap({
        'task': widget.taskId,
        'title': _titleCtrl.text,
        'file': multipartFile,
      });
      
      final client = ApiClient().dio;
      await client.post('/documents/documents/', data: formData);
      
      if (mounted) widget.onSuccess();
      
    } catch(e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Document'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8)
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedFile?.name ?? 'Select Image/Document')),
                ],
              ),
            ),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isUploading ? null : _upload, 
          child: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add')
        ),
      ],
    );
  }
}
