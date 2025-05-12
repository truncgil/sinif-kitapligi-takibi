import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../services/backup/backup_service.dart';
import '../../providers/library_provider.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  bool _isLoading = false;
  List<FileSystemEntity> _backups = [];
  List<FileSystemEntity> _downloadBackups = [];

  @override
  void initState() {
    super.initState();
    _loadBackupsList();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      // Depolama izni iste
      final status = await Permission.storage.request();

      if (status.isGranted) {
        _loadDownloadBackups();
      } else {
        _showErrorSnackbar('Depolama izni olmadan yerel yedeklere erişilemez.');
      }
    } catch (e) {
      // İzin isteği başarısız olursa
      _showErrorSnackbar('İzin kontrolü sırasında hata oluştu: $e');
    }
  }

  Future<void> _loadBackupsList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final backups = await _backupService.listBackups();
      setState(() {
        _backups = backups;
      });
    } catch (e) {
      _showErrorSnackbar('Yedekler yüklenirken hata oluştu: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDownloadBackups() async {
    try {
      final backups = await _backupService.listDownloadFolderBackups();
      setState(() {
        _downloadBackups = backups;
      });
    } catch (e) {
      _showErrorSnackbar('İndirilenler klasörü yedekleri yüklenirken hata: $e');
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final backupPath = await _backupService.backupDatabase();
      _loadBackupsList();
      _showSuccessSnackbar('Yedekleme başarılı: ${path.basename(backupPath)}');
    } catch (e) {
      _showErrorSnackbar('Yedekleme sırasında hata oluştu: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToDownloadFolder(String backupPath) async {
    try {
      final status = await Permission.storage.request();

      if (!status.isGranted) {
        _showErrorSnackbar('Depolama izni verilmedi. Yedek dışa aktarılamadı.');
        return;
      }

      final downloadPath =
          await _backupService.exportToLocalStorage(backupPath);
      _loadDownloadBackups();
      _showSuccessSnackbar(
          'Yedek dosyası başarıyla cihaz belleğine kaydedildi: ${path.basename(downloadPath)}');
    } catch (e) {
      _showErrorSnackbar('Dışa aktarma sırasında hata oluştu: $e');
    }
  }

  Future<void> _restoreBackup(String backupPath) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Veritabanı Geri Yükleme'),
        content: const Text(
            'Bu işlem mevcut veritabanınızı silecek ve yerine seçtiğiniz yedeği geri yükleyecektir.\n\n'
            'Bu işlemi yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _backupService.restoreDatabase(backupPath);

      // Veritabanı güncellendiği için Provider'ı da güncelle
      if (mounted) {
        final provider = Provider.of<LibraryProvider>(context, listen: false);
        await provider.refreshBorrowedBooks();
      }

      _showSuccessSnackbar('Veritabanı başarıyla geri yüklendi.');

      // Kısa bir süre bekleyip ana sayfaya dön
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        // Ana sayfaya dön
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showErrorSnackbar('Geri yükleme sırasında hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteBackup(String backupPath) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedeği Sil'),
        content: const Text(
          'Bu yedeği silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _backupService.deleteBackup(backupPath);
      _loadBackupsList();
      _showSuccessSnackbar('Yedek başarıyla silindi.');
    } catch (e) {
      _showErrorSnackbar('Yedek silinirken hata oluştu: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  String _formatFileDate(FileSystemEntity entity) {
    try {
      final stat = (entity as File).statSync();
      return DateFormat('dd.MM.yyyy HH:mm').format(stat.modified);
    } catch (_) {
      return 'Tarih bilinmiyor';
    }
  }

  String _formatFileSize(FileSystemEntity entity) {
    try {
      final file = File(entity.path);
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return 'Boyut bilinmiyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veri Yedekleme ve Geri Yükleme'),
        actions: [
          IconButton(
            onPressed: () {
              _loadBackupsList();
              _loadDownloadBackups();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Uygulama Yedekleri'),
                        Tab(text: 'Dış Yedekler'),
                      ],
                      labelColor: Colors.black,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildAppBackupsTab(),
                          _buildDownloadFolderTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAppBackupsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Veri yedekleme ve geri yükleme işlemleri, kitaplık veritabanınızı yedeklemenizi ve gerektiğinde geri yüklemenizi sağlar.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton.icon(
            onPressed: _createBackup,
            icon: const Icon(Icons.backup),
            label: const Text('Yeni Yedek Oluştur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Text(
                'Mevcut Yedekler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '${_backups.length} yedek',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: _backups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.backup_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz yedek oluşturulmamış',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Verilerinizi korumak için yedek oluşturun',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _backups.length,
                  itemBuilder: (context, index) {
                    final backup = _backups[index];
                    final fileName = path.basename(backup.path);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: ListTile(
                        title: Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatFileDate(backup)} - ${_formatFileSize(backup)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: const Icon(Icons.storage),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'Geri Yükle',
                              onPressed: () => _restoreBackup(backup.path),
                            ),
                            IconButton(
                              icon: const Icon(Icons.save_alt),
                              tooltip: 'Cihaz Belleğine Kaydet',
                              onPressed: () =>
                                  _exportToDownloadFolder(backup.path),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Sil',
                              onPressed: () => _deleteBackup(backup.path),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDownloadFolderTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Bu sayfada cihazınızdaki uygulama belleğine kaydedilen yedeklerinizi görüntüleyebilir ve geri yükleyebilirsiniz.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Text(
                'Cihaz Belleğindeki Yedekler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '${_downloadBackups.length} yedek',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: _downloadBackups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Cihaz belleğinde yedek bulunamadı',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yedeklerinizi ilk sekmede "Cihaz Belleğine Kaydet" seçeneği ile dışa aktarabilirsiniz',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _downloadBackups.length,
                  itemBuilder: (context, index) {
                    final backup = _downloadBackups[index];
                    final fileName = path.basename(backup.path);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: ListTile(
                        title: Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatFileDate(backup)} - ${_formatFileSize(backup)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: const Icon(Icons.download_done),
                        trailing: IconButton(
                          icon: const Icon(Icons.restore),
                          tooltip: 'Geri Yükle',
                          onPressed: () => _restoreBackup(backup.path),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
