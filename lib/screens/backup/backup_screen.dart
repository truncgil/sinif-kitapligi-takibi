import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../../services/backup/backup_service.dart';
import '../../providers/library_provider.dart';
import '../../constants/colors.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  bool _isLoading = false;
  List<FileSystemEntity> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackupsList();
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

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final backupPath = await _backupService.backupDatabase();
      _loadBackupsList();
      _showSuccessSnackbar('Yedekleme başarılı: ${path.basename(backupPath)}');

      // Veritabanı güncellendiği için Provider'ı da güncelle
      if (mounted) {
        final provider = Provider.of<LibraryProvider>(context, listen: false);
        await provider.refreshBorrowedBooks();
      }

      // Kısa bir süre bekleyip ana sayfaya dön
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        // Ana sayfaya dön
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showErrorSnackbar('Yedekleme sırasında hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareBackup(String backupPath) async {
    try {
      await _backupService.shareBackup(backupPath);
    } catch (e) {
      _showErrorSnackbar('Yedek paylaşılırken hata oluştu: $e');
    }
  }

  Future<void> _deleteBackup(String backupPath) async {
    try {
      await _backupService.deleteBackup(backupPath);
      _loadBackupsList();
    } catch (e) {
      _showErrorSnackbar('Yedek silinirken hata oluştu: $e');
    }
  }

  Future<void> _restoreBackup(String backupPath) async {
    // Onay dialolu göster
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedeği Geri Yükle'),
        content: const Text(
            'Bu işlem mevcut veritabanınızı yedek ile değiştirecek. Mevcut verileriniz kaybolacak. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
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
      final success = await _backupService.restoreDatabase(backupPath);
      if (success) {
        _showSuccessSnackbar('Yedek başarıyla geri yüklendi');

        // Veritabanı değiştiği için Provider'ı güncelle
        if (mounted) {
          final provider = Provider.of<LibraryProvider>(context, listen: false);
          await provider.refreshBorrowedBooks();
        }

        // Kısa bir süre bekleyip ana sayfaya dön
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          // Ana sayfaya dön
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        _showErrorSnackbar('Geri yükleme başarısız oldu');
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

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _formatFileDate(FileSystemEntity entity) {
    try {
      final file = File(entity.path);
      final modified = file.lastModifiedSync();
      return DateFormat('dd.MM.yyyy HH:mm').format(modified);
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
        backgroundColor: AppColors.backup,
        centerTitle: true,
        title: const Text(
          'Veri Yedekleme ve Geri Yükleme',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _loadBackupsList();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: _buildBackupsScreen(),
            ),
    );
  }

  Widget _buildBackupsScreen() {
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
          child: Row(
            children: [
              Expanded(
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
            ],
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

                    return Dismissible(
                      key: Key(backup.path),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      secondaryBackground: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(
                          Icons.share,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // Paylaşma işlemi
                          await _shareBackup(backup.path);
                          return false;
                        } else {
                          // Silme işlemi onayı
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Yedeği Sil'),
                              content: Text(
                                  '$fileName dosyasını silmek istiyor musunuz?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                          return result ?? false;
                        }
                      },
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          try {
                            await _deleteBackup(backup.path);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$fileName başarıyla silindi'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Yedek silinirken bir hata oluştu: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Card(
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
                                icon: const Icon(Icons.share),
                                tooltip: 'Paylaş',
                                onPressed: () => _shareBackup(backup.path),
                              ),
                              IconButton(
                                icon: const Icon(Icons.restore),
                                tooltip: 'Geri Yükle',
                                onPressed: () => _restoreBackup(backup.path),
                              ),
                            ],
                          ),
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
