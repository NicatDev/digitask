import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added
import 'package:mobile/core/api/api_client.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart' as dio;
import 'package:mobile/core/constants.dart';
import 'dart:io'; 
import 'package:image_picker/image_picker.dart';

class SurveyModal extends StatefulWidget {
  final Map<String, dynamic> task;
  final List<dynamic> allServices;
  final VoidCallback onSuccess;

  const SurveyModal({
    super.key,
    required this.task,
    required this.allServices,
    required this.onSuccess,
  });

  @override
  State<SurveyModal> createState() => _SurveyModalState();
}

class _SurveyModalState extends State<SurveyModal> {
  // We need to merge available services (from allServices) 
  // with existing filled data (from task['task_services']).
  
  @override
  Widget build(BuildContext context) {
    // 1. Identify services linked to this task
    final List<int> linkedServiceIds = List<int>.from(widget.task['services'] ?? []);
    
    if (linkedServiceIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: Text('No services linked to this task.')),
      );
    }

    // 2. Filter full service objects
    final linkedServices = widget.allServices.where((s) => linkedServiceIds.contains(s['id'])).toList();

    // 3. Map of ServiceID -> Existing TaskService Data
    final existingDataMap = <int, Map<String, dynamic>>{};
    if (widget.task['task_services'] != null) {
      for (var ts in widget.task['task_services']) {
        if (ts['service'] != null) {
          existingDataMap[ts['service']] = ts;
        }
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4, 
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 20),
            ),
          ),
          const Text('Survey (Anket)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: linkedServices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final service = linkedServices[index];
                final existing = existingDataMap[service['id']];
                final isFilled = existing != null;

                return Card(
                  elevation: 0,
                  color: isFilled ? Colors.green.withOpacity(0.05) : Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isFilled ? Colors.green : Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isFilled ? Colors.green : Colors.blue,
                      child: Icon(
                        isFilled ? Icons.check : Icons.edit, 
                        color: Colors.white, size: 20
                      ),
                    ),
                    title: Text(service['name'] ?? 'Service', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isFilled ? 'Tap to edit' : 'Tap to fill'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceFormScreen(
                            task: widget.task,
                            service: service,
                            existingData: existing,
                            onSuccess: () {
                              widget.onSuccess();
                              Navigator.pop(context); // Close form
                              // Note: To refresh the list status, we might need to fetch task again?
                              // Or widget.onSuccess() triggers fetch in parent. 
                              // But parent logic needs to propagate down?
                              // For simple UI, we assume parent refresh updates the task object or we rely on close/reopen.
                              // Actually optimal is: onSuccess refreshes, but this modal might need closing to see changes.
                              // Or simply closing this modal is expected after filling?
                              // For now, let's keep list open. But we need to update `existingDataMap`.
                              // Since we receive `task` from parent, we can't easily update it here without callback.
                              // So I will close the Modal after Success to force refresh from parent.
                              Navigator.pop(context); // Close Modal
                            },
                          ),
                        ),
                      );
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
}

class ServiceFormScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final Map<String, dynamic> service;
  final Map<String, dynamic>? existingData;
  final VoidCallback onSuccess;

  const ServiceFormScreen({
    super.key,
    required this.task,
    required this.service,
    this.existingData,
    required this.onSuccess,
  });

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}



// ... (SurveyModal class remains same)

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formValues = {}; // key: column_id (as string), value: dynamic (String, int, XFile)
  final TextEditingController _noteCtrl = TextEditingController();
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _noteCtrl.text = widget.existingData?['note'] ?? '';
    
    // Pre-fill existing values
    if (widget.existingData != null && widget.existingData!['values'] != null) {
      for (var val in widget.existingData!['values']) {
        if (val['column'] != null) {
           // For images, value might be full URL string
           // 'value' is generic getter from backend
           _formValues[val['column'].toString()] = val['value'];
        }
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> valuesJson = [];
      final Map<String, dynamic> fileMap = {}; // key: file_colId, value: MultipartFile

      // Prepare values
      for (var col in widget.service['columns']) {
        final colId = col['id'].toString();
        final type = col['field_type'];
        final val = _formValues[colId];

        if (val != null) {
          // If Image/File and is XFile -> It's a new file upload
          if ((type == 'image' || type == 'file') && val is XFile) {
            // Add to fileMap using bytes (Web compatible)
            final bytes = await val.readAsBytes();
            String fileName = val.name;
            fileMap['file_$colId'] = dio.MultipartFile.fromBytes(bytes, filename: fileName);
            
            // Add entry to valuesJson so backend knows to process this column
            valuesJson.add({'column': col['id']}); 
          } 
          // If Image and is String -> Existing URL, just ignore or re-send?
          // Backend doesn't need re-send of existing image.
          else if ((type == 'image' || type == 'file') && val is String) {
             // Do nothing for existing image
          }
          // Normal fields
          else {
            valuesJson.add({
              'column': col['id'],
              ..._mapValueToField(col, val)
            });
          }
        }
      }

      // Construct FormData
      final formData = dio.FormData.fromMap({
        'task': widget.task['id'],
        'service': widget.service['id'],
        'note': _noteCtrl.text,
        'values_json': jsonEncode(valuesJson), // Send as string for FormData
        ...fileMap
      });

      final client = ApiClient().dio;
      if (widget.existingData != null) {
        await client.patch('/tasks/task-services/${widget.existingData!['id']}/', data: formData);
      } else {
        await client.post('/tasks/task-services/', data: formData);
      }

      if (mounted) {
        widget.onSuccess();
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Map<String, dynamic> _mapValueToField(dynamic column, dynamic value) {
    final type = column['field_type'];
    if (value == null) return {};

    switch (type) {
      case 'string': return {'charfield_value': value};
      case 'text': return {'text_value': value};
      case 'integer': return {'number_value': int.tryParse(value.toString())};
      case 'decimal': return {'decimal_value': double.tryParse(value.toString())};
      case 'boolean': return {'boolean_value': value};
      case 'date': return {'date_value': value};
      case 'datetime': return {'datetime_value': value};
      default: return {'charfield_value': value};
    }
  }

  Widget _buildField(dynamic col) {
    final colId = col['id'].toString();
    final label = col['name'];
    final type = col['field_type'];
    final required = col['required'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildInputByType(colId, label, type, required),
    );
  }

  Widget _buildInputByType(String key, String label, String type, bool required) {
    if (type == 'image') {
      final val = _formValues[key];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              try {
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() => _formValues[key] = image);
                }
              } catch (e) {
                // Handle permission?
              }
            },
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: val != null
                  ? (val is XFile 
                      ? (kIsWeb 
                          ? Image.network(val.path, fit: BoxFit.cover) 
                          : Image.file(File(val.path), fit: BoxFit.cover))
                      : Image.network(_resolveImageUrl(val.toString()), fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image)))
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.grey, size: 40),
                        Text('Tap to upload', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
            ),
          ),
        ],
      );
    }

    switch (type) {
      case 'string':
      case 'text':
        return TextFormField(
          initialValue: _formValues[key]?.toString(),
          decoration: InputDecoration(
            labelText: label, 
            border: const OutlineInputBorder(),
            helperText: required ? 'Required (Optional warning)' : null,
            helperStyle: const TextStyle(color: Colors.orange), // Orange as it is non-blocking
          ),
          maxLines: type == 'text' ? 3 : 1,
          // validator: required ? (v) => v!.isEmpty ? 'Required' : null : null, // Removed per request
          onSaved: (v) => _formValues[key] = v,
          onChanged: (v) => _formValues[key] = v,
        );
      case 'integer':
      case 'decimal':
        return TextFormField(
          initialValue: _formValues[key]?.toString(),
          decoration: InputDecoration(
             labelText: label, 
             border: const OutlineInputBorder(),
             helperText: required ? 'Required (Optional warning)' : null,
             helperStyle: const TextStyle(color: Colors.orange),
          ),
          keyboardType: TextInputType.number,
          // validator: required ? (v) => v!.isEmpty ? 'Required' : null : null, // Removed
          onChanged: (v) => _formValues[key] = v,
        );
      case 'boolean':
        return SwitchListTile(
          title: Text(label),
          value: _formValues[key] == true,
          onChanged: (v) => setState(() => _formValues[key] = v),
        );
      case 'date':
        return InkWell(
          onTap: () async {
             final d = await showDatePicker(
               context: context, 
               initialDate: DateTime.now(), 
               firstDate: DateTime(2000), 
               lastDate: DateTime(2100)
             );
             if (d != null) {
               setState(() => _formValues[key] = DateFormat('yyyy-MM-dd').format(d));
             }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label, 
              border: const OutlineInputBorder(),
              helperText: required ? 'Required (Optional warning)' : null,
              helperStyle: const TextStyle(color: Colors.orange),
            ),
            child: Text(_formValues[key] ?? 'Select Date'),
          ),
        );
      case 'datetime':
        return InkWell(
          onTap: () async {
             final now = DateTime.now();
             final d = await showDatePicker(
               context: context, 
               initialDate: now, 
               firstDate: DateTime(2000), 
               lastDate: DateTime(2100)
             );
             if (d != null) {
               final t = await showTimePicker(
                 // ignore: use_build_context_synchronously
                 context: context,
                 initialTime: TimeOfDay.fromDateTime(now),
               );
               if (t != null) {
                 final full = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                 setState(() => _formValues[key] = DateFormat('yyyy-MM-dd HH:mm').format(full));
               }
             }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label, 
              border: const OutlineInputBorder(),
              helperText: required ? 'Required (Optional warning)' : null,
              helperStyle: const TextStyle(color: Colors.orange),
            ),
            child: Text(_formValues[key] ?? 'Select Date & Time'),
          ),
        );
      default:
        return Text('Unsupported type: $type for $label');
    }
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http')) return url;
    final domain = AppConstants.baseUrl.replaceAll('/api', '');
    return '$domain$url';
  }

  @override
  Widget build(BuildContext context) {
    final columns = List<dynamic>.from(widget.service['columns'] as List<dynamic>? ?? []);
    columns.sort((a, b) {
      final oA = a['order'];
      final oB = b['order'];
      if (oA == null && oB == null) return 0;
      if (oA == null) return 1;
      if (oB == null) return -1;
      return (oA as int).compareTo(oB as int);
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.service['name'])),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Service Note', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            const Text('Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (columns.isEmpty) const Text('No custom fields for this service.'),
            ...columns.map((c) => _buildField(c)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16)
                ),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
