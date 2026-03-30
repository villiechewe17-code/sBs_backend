import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'backend_api_service.dart';

/// Updated Admin Panel that uses the Backend API Service
/// 
/// This replaces the Cloudflare Worker service with direct backend API calls.
/// The workflow is:
/// 1. Admin selects file
/// 2. App calls backend to get presigned URL
/// 3. App uploads directly to R2 using presigned URL
/// 4. App creates content metadata in Supabase via backend
class UpdatedAdminPanel extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final BackendApiService apiService;

  const UpdatedAdminPanel({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.apiService,
  });

  @override
  State<UpdatedAdminPanel> createState() => _UpdatedAdminPanelState();
}

class _UpdatedAdminPanelState extends State<UpdatedAdminPanel> {
  late BackendApiService _apiService;
  
  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _externalUrlController = TextEditingController();
  final _textContentController = TextEditingController();

  String _selectedType = 'folder';
  String _accessLevel = 'free';
  bool _isLoading = false;
  List<Map<String, dynamic>> _contentItems = [];

  // File upload tracking
  String? _selectedFilePath;
  String? _uploadedFileKey;
  int? _uploadedFileSize;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService;
    _loadContent();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _externalUrlController.dispose();
    _textContentController.dispose();
    super.dispose();
  }

  /// Load all content for this category
  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      // Parse categoryId as int (assuming it's numeric)
      final categoryIdInt = int.tryParse(widget.categoryId) ?? 1;
      final items = await _apiService.getContentByCategory(categoryIdInt);
      setState(() {
        _contentItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading content: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - ${widget.categoryName.toUpperCase()}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _contentItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            'No content here yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _contentItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _buildContentTile(_contentItems[index]),
                    ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_external_link',
            onPressed: () => _showAddLinkDialog(),
            backgroundColor: Colors.deepPurple,
            icon: const Icon(Icons.link, color: Colors.white),
            label: const Text('Add Link', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_file',
            onPressed: () => _showAddContentDialog(),
            backgroundColor: const Color(0xFF6B4E3D),
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text('Upload Content', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Build a tile for displaying content item
  Widget _buildContentTile(Map<String, dynamic> item) {
    final String contentType = item['contentType'] ?? 'text';
    final String accessLevel = item['accessLevel'] ?? 'free';
    final String title = item['title'] ?? 'Untitled';
    final bool isActive = item['isActive'] ?? true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(
          _getIconForType(contentType),
          color: const Color(0xFF6B4E3D),
        ),
        title: Text(title),
        subtitle: Text(
          '$contentType • ${accessLevel.toUpperCase()}',
          style: TextStyle(
            color: accessLevel == 'free' ? Colors.green : Colors.orange[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditDialog(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteContent(item['id']),
            ),
          ],
        ),
      ),
    );
  }

  /// Get icon for content type
  IconData _getIconForType(String type) {
    switch (type) {
      case 'folder':
        return Icons.folder;
      case 'image':
        return Icons.image;
      case 'link':
        return Icons.link;
      case 'text':
        return Icons.description;
      default:
        return Icons.file_present;
    }
  }

  /// Show dialog to add external link
  void _showAddLinkDialog() {
    _resetControllers();
    _selectedType = 'link';
    _accessLevel = 'free';
    _uploadedFileKey = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add External Link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _externalUrlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _accessLevel,
                  items: ['free', 'paid']
                      .map((level) =>
                          DropdownMenuItem(value: level, child: Text(level)))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => _accessLevel = val ?? 'free'),
                  decoration: const InputDecoration(labelText: 'Access Level'),
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
              onPressed: () {
                Navigator.pop(context);
                _saveLink();
              },
              child: const Text('Save Link'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to add file content
  void _showAddContentDialog() {
    _resetControllers();
    _selectedType = 'folder';
    _accessLevel = 'free';
    _uploadedFileKey = null;
    _selectedFilePath = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload Content'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: ['folder', 'image', 'text']
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => _selectedType = val ?? 'folder'),
                  decoration: const InputDecoration(labelText: 'Content Type'),
                ),
                const SizedBox(height: 12),
                if (_selectedType == 'text')
                  TextField(
                    controller: _textContentController,
                    decoration: const InputDecoration(labelText: 'Text Content'),
                    maxLines: 5,
                  )
                else
                  Column(
                    children: [
                      if (_uploadedFileKey == null)
                        ElevatedButton.icon(
                          onPressed: () =>
                              _pickAndUploadFile(setDialogState),
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Select & Upload File'),
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'File uploaded: $_uploadedFileKey',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _accessLevel,
                  items: ['free', 'paid']
                      .map((level) =>
                          DropdownMenuItem(value: level, child: Text(level)))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => _accessLevel = val ?? 'free'),
                  decoration: const InputDecoration(labelText: 'Access Level'),
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
              onPressed: (_selectedType != 'text' && _uploadedFileKey == null)
                  ? null
                  : () {
                      Navigator.pop(context);
                      _saveContent();
                    },
              child: const Text('Save Content'),
            ),
          ],
        ),
      ),
    );
  }

  /// Pick file and upload to R2
  Future<void> _pickAndUploadFile(StateSetter setDialogState) async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileSize = file.lengthSync();

      setState(() => _isLoading = true);

      // Step 1: Get presigned URL from backend
      final presignedData = await _apiService.getUploadPresignedUrl(
        fileName: fileName,
        contentType: _getMimeType(fileName),
        fileSize: fileSize,
      );

      // Step 2: Upload directly to R2
      final success = await _apiService.uploadFileToR2(
        file: file,
        presignedUrl: presignedData['presignedUrl'],
        contentType: _getMimeType(fileName),
      );

      if (success) {
        setDialogState(() {
          _uploadedFileKey = presignedData['fileKey'];
          _uploadedFileSize = fileSize;
          _selectedFilePath = file.path;
          if (_titleController.text.isEmpty) {
            _titleController.text = fileName;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded to R2 successfully!')),
          );
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  /// Save link to database
  Future<void> _saveLink() async {
    if (_titleController.text.isEmpty || _externalUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and URL are required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final categoryIdInt = int.tryParse(widget.categoryId) ?? 1;
      await _apiService.createContent(
        categoryId: categoryIdInt,
        title: _titleController.text,
        contentType: 'link',
        description: _descriptionController.text,
        accessLevel: _accessLevel,
        externalUrl: _externalUrlController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link saved successfully!')),
        );
      }

      _loadContent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving link: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  /// Save content to database
  Future<void> _saveContent() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    if (_selectedType != 'text' && _uploadedFileKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File upload required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final categoryIdInt = int.tryParse(widget.categoryId) ?? 1;
      await _apiService.createContent(
        categoryId: categoryIdInt,
        title: _titleController.text,
        contentType: _selectedType,
        description: _descriptionController.text,
        accessLevel: _accessLevel,
        r2FileKey: _uploadedFileKey,
        fileSize: _uploadedFileSize,
        mimeType: _selectedType != 'text' ? _getMimeType(_uploadedFileKey!) : null,
        textContent: _selectedType == 'text' ? _textContentController.text : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content saved successfully!')),
        );
      }

      _loadContent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving content: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  /// Show edit dialog
  void _showEditDialog(Map<String, dynamic> item) {
    _titleController.text = item['title'] ?? '';
    _descriptionController.text = item['description'] ?? '';
    _accessLevel = item['accessLevel'] ?? 'free';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Content'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _accessLevel,
                  items: ['free', 'paid']
                      .map((level) =>
                          DropdownMenuItem(value: level, child: Text(level)))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => _accessLevel = val ?? 'free'),
                  decoration: const InputDecoration(labelText: 'Access Level'),
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
              onPressed: () {
                Navigator.pop(context);
                _updateContent(item['id']);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  /// Update content
  Future<void> _updateContent(int contentId) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.updateContent(
        id: contentId,
        title: _titleController.text,
        description: _descriptionController.text,
        accessLevel: _accessLevel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content updated successfully!')),
        );
      }

      _loadContent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating content: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  /// Delete content
  Future<void> _deleteContent(int contentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Content?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.deleteContent(contentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content deleted successfully!')),
        );
      }

      _loadContent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting content: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  /// Reset all controllers
  void _resetControllers() {
    _titleController.clear();
    _descriptionController.clear();
    _externalUrlController.clear();
    _textContentController.clear();
  }

  /// Get MIME type from file extension
  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final mimeTypes = {
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'txt': 'text/plain',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }
}
