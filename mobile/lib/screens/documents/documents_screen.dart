import 'package:mobile/core/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
         Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Documents'),
              Tab(text: 'Archive'),
              Tab(text: 'Shelves'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              ActiveDocumentsTab(),
              ArchiveDocumentsTab(),
              ShelvesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class ActiveDocumentsTab extends StatefulWidget {
  const ActiveDocumentsTab({super.key});

  @override
  State<ActiveDocumentsTab> createState() => _ActiveDocumentsTabState();
}

class _ActiveDocumentsTabState extends State<ActiveDocumentsTab> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _documents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _currentPage = 1;
  bool _hasNextPage = true;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasNextPage = true;
        _isLoading = true;
        _documents = [];
      });
    } else {
      setState(() => _isLoading = true);
    }
    
    try {
      final response = await ApiClient().dio.get(
        '/documents/documents/',
        queryParameters: {
          'search': _searchQuery,
          'confirmed': 'false',
          'page': _currentPage,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          
          if (data is Map && data.containsKey('results')) {
            _documents = data['results'];
            _hasNextPage = data['next'] != null;
          } else if (data is List) {
            _documents = data;
            _hasNextPage = false;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePage(int page) async {
    setState(() {
      _currentPage = page;
      _isLoading = true;
      _documents = [];
    });
    await _fetchDocuments();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _fetchDocuments(refresh: true);
  }

  void _showArchiveModal(dynamic doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ArchiveModal(documentId: doc['id'], onSuccess: () => _fetchDocuments(refresh: true)),
    );
  }

  void _showAddDocumentModal() {
    showDialog(
      context: context,
      builder: (ctx) => AddDocumentModal(onSuccess: () => _fetchDocuments(refresh: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDocumentModal,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: _documents.isEmpty
                            ? const Center(child: Text('No documents found'))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _documents.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, index) {
                                  return DocumentCard(
                                    doc: _documents[index], 
                                    onArchive: () => _showArchiveModal(_documents[index]),
                                    showArchiveBtn: true,
                                  );
                                },
                              ),
                      ),
                      // Pagination Controls
                      if (_documents.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back, size: 18),
                                    SizedBox(width: 8),
                                    Text('Prev'),
                                  ],
                                ),
                              ),
                              Text('Page $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ElevatedButton(
                                onPressed: _hasNextPage ? () => _changePage(_currentPage + 1) : null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Next'),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class ArchiveDocumentsTab extends StatefulWidget {
  const ArchiveDocumentsTab({super.key});

  @override
  State<ArchiveDocumentsTab> createState() => _ArchiveDocumentsTabState();
}

class _ArchiveDocumentsTabState extends State<ArchiveDocumentsTab> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _documents = [];
  List<dynamic> _shelves = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int? _selectedShelfId;
  int _currentPage = 1;
  bool _hasNextPage = true;

  @override
  void initState() {
    super.initState();
    _fetchShelves();
    _fetchDocuments();
  }

  Future<void> _fetchShelves() async {
    try {
      final response = await ApiClient().dio.get('/documents/shelves/');
      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
           if (data is Map && data.containsKey('results')) {
            _shelves = data['results'];
          } else if (data is List) {
            _shelves = data;
          }
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _fetchDocuments({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasNextPage = true;
        _isLoading = true;
        _documents = [];
      });
    } else {
      setState(() => _isLoading = true);
    }
    
    try {
      final params = <String, dynamic>{
        'search': _searchQuery,
        'confirmed': 'true',
        'page': _currentPage,
      };
      if (_selectedShelfId != null) {
        params['shelf'] = _selectedShelfId.toString();
      }

      final response = await ApiClient().dio.get(
        '/documents/documents/',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          
          if (data is Map && data.containsKey('results')) {
            _documents = data['results'];
            _hasNextPage = data['next'] != null;
          } else if (data is List) {
            _documents = data;
            _hasNextPage = false;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePage(int page) async {
    setState(() {
      _currentPage = page;
      _isLoading = true;
      _documents = [];
    });
    await _fetchDocuments();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _fetchDocuments(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search archive...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedShelfId,
                decoration: InputDecoration(
                  labelText: 'Filter by Shelf',
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                isExpanded: true,
                items: [
                   const DropdownMenuItem<int>(value: null, child: Text('All Shelves')),
                   ..._shelves.map((s) => DropdownMenuItem<int>(
                    value: s['id'],
                    child: Text(s['name'] ?? 'Shelf ${s['id']}'),
                  )).toList(),
                ],
                onChanged: (val) {
                  setState(() => _selectedShelfId = val);
                  _fetchDocuments(refresh: true);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: _documents.isEmpty
                          ? const Center(child: Text('No archived documents found'))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _documents.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, index) {
                                return DocumentCard(
                                  doc: _documents[index], 
                                  showArchiveBtn: false,
                                );
                              },
                            ),
                    ),
                    // Pagination Controls
                    if (_documents.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_back, size: 18),
                                  SizedBox(width: 8),
                                  Text('Prev'),
                                ],
                              ),
                            ),
                            Text('Page $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ElevatedButton(
                              onPressed: _hasNextPage ? () => _changePage(_currentPage + 1) : null,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Next'),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class ShelvesTab extends StatefulWidget {
  const ShelvesTab({super.key});

  @override
  State<ShelvesTab> createState() => _ShelvesTabState();
}

class _ShelvesTabState extends State<ShelvesTab> {
  List<dynamic> _shelves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShelves();
  }

  Future<void> _fetchShelves() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.get('/documents/shelves/');
       if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('results')) {
            _shelves = data['results'];
          } else if (data is List) {
            _shelves = data;
          } else {
            _shelves = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showShelfModal({Map<String, dynamic>? shelf}) {
    showDialog(
      context: context,
      builder: (ctx) => ShelfModal(
        shelf: shelf,
        onSuccess: _fetchShelves,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherit from parent
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showShelfModal(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shelves.isEmpty
              ? const Center(child: Text('No shelves found'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shelves.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final shelf = _shelves[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shelves, color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shelf['name'] ?? 'Unnamed Shelf',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (shelf['location'] != null && shelf['location'].toString().isNotEmpty)
                                  Text(
                                    shelf['location'],
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showShelfModal(shelf: shelf),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class DocumentCard extends StatelessWidget {
  final dynamic doc;
  final VoidCallback? onArchive;
  final bool showArchiveBtn;

  const DocumentCard({super.key, required this.doc, this.onArchive, this.showArchiveBtn = false});

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(doc['created_at'] ?? '');
    final dateStr = date != null ? DateFormat('dd.MM.yyyy HH:mm').format(date) : '';
    
    // Operation logic: action OR task_title OR '-'
    String operation = '-';
    if (doc['action'] != null && doc['action'].toString().isNotEmpty) {
      operation = doc['action'];
    } else if (doc['task_title'] != null && doc['task_title'].toString().isNotEmpty) {
      operation = doc['task_title'];
    }

    return InkWell(
      onTap: () {
        if (doc['file_url'] != null) {
          _launchUrl(doc['file_url']);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
            boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc['title'] ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                   // Operation Field
                  Row(
                    children: [
                      const Icon(Icons.compare_arrows, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          operation,
                          style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  if (doc['confirmed'] == true && doc['shelf_name'] != null)
                     Padding(
                       padding: const EdgeInsets.only(top: 4.0),
                       child: Text(
                        '${doc['shelf_name']}', // Display only Ref name
                        style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                         ),
                     ),
                ],
              ),
            ),
            if (showArchiveBtn)
              IconButton(
                icon: const Icon(Icons.archive_outlined, color: Colors.orange),
                onPressed: () {
                  // Do not open URL when clicking archive
                  // Event bubbling might be an issue, but IconButton handles its own tap
                  if (onArchive != null) onArchive!();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class ArchiveModal extends StatefulWidget {
  final int documentId;
  final VoidCallback onSuccess;

  const ArchiveModal({super.key, required this.documentId, required this.onSuccess});

  @override
  State<ArchiveModal> createState() => _ArchiveModalState();
}

class _ArchiveModalState extends State<ArchiveModal> {
  List<dynamic> _shelves = [];
  bool _isLoadingShelves = true;
  int? _selectedShelfId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchShelves();
  }

  Future<void> _fetchShelves() async {
    try {
      final response = await ApiClient().dio.get('/documents/shelves/');
      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('results')) {
            _shelves = data['results'];
          } else if (data is List) {
             _shelves = data;
          }
          _isLoadingShelves = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingShelves = false);
      }
    }
  }

  Future<void> _archiveDocument() async {
    if (_selectedShelfId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shelf')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ApiClient().dio.post(
        '/documents/documents/${widget.documentId}/archive/',
        data: {'shelf': _selectedShelfId},
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document archived successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Move to Archive',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _isLoadingShelves
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<int>(
                  value: _selectedShelfId,
                  decoration: const InputDecoration(
                    labelText: 'Select Shelf',
                    border: OutlineInputBorder(),
                  ),
                  items: _shelves.map<DropdownMenuItem<int>>((shelf) {
                    return DropdownMenuItem<int>(
                      value: shelf['id'],
                      child: Text(shelf['name'] ?? 'Shelf ${shelf['id']}'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedShelfId = val),
                ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _archiveDocument,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}

class ShelfModal extends StatefulWidget {
  final Map<String, dynamic>? shelf;
  final VoidCallback onSuccess;

  const ShelfModal({super.key, this.shelf, required this.onSuccess});

  @override
  State<ShelfModal> createState() => _ShelfModalState();
}

class _ShelfModalState extends State<ShelfModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.shelf != null) {
      _nameController.text = widget.shelf!['name'] ?? '';
      _locationController.text = widget.shelf!['location'] ?? '';
    }
  }

  Future<void> _saveShelf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'name': _nameController.text,
        'location': _locationController.text,
      };

      if (widget.shelf == null) {
        await ApiClient().dio.post('/documents/shelves/', data: data);
      } else {
        await ApiClient().dio.patch('/documents/shelves/${widget.shelf!['id']}/', data: data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.shelf == null ? 'Shelf created' : 'Shelf updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.shelf == null ? 'Create Shelf' : 'Edit Shelf'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Store Name'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location (Optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveShelf,
           child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class AddDocumentModal extends StatefulWidget {
  final VoidCallback onSuccess;

  const AddDocumentModal({super.key, required this.onSuccess});

  @override
  State<AddDocumentModal> createState() => _AddDocumentModalState();
}

class _AddDocumentModalState extends State<AddDocumentModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isSaving = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true, // Important for web - loads bytes into memory
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      MultipartFile multipartFile;
      
      // Use bytes for web, path for mobile
      if (_selectedFile!.bytes != null) {
        multipartFile = MultipartFile.fromBytes(
          _selectedFile!.bytes!,
          filename: _selectedFile!.name,
        );
      } else if (_selectedFile!.path != null) {
        multipartFile = await MultipartFile.fromFile(
          _selectedFile!.path!,
          filename: _selectedFile!.name,
        );
      } else {
        throw Exception('No file data available');
      }

      final formData = FormData.fromMap({
        'title': _titleController.text,
        'action': _actionController.text,
        'file': multipartFile,
      });

      await ApiClient().dio.post('/documents/documents/', data: formData);

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Document'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _actionController,
              decoration: const InputDecoration(
                labelText: 'Action / Process',
                hintText: 'e.g. Warehouse receipt, Sales invoice...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.check_circle : Icons.upload_file,
                      color: _selectedFile != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _selectedFile?.name ?? 'Select File',
                        style: TextStyle(
                          color: _selectedFile != null ? Colors.black : Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveDocument,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
