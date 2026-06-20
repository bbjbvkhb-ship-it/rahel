import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/download_controller.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String _formatStatus(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return 'في قائمة الانتظار';
      case DownloadStatus.analyzing:
        return 'جاري التحليل...';
      case DownloadStatus.downloading:
        return 'جاري التحميل...';
      case DownloadStatus.converting:
        return 'جاري معالجة الملف...';
      case DownloadStatus.completed:
        return 'مكتمل';
      case DownloadStatus.failed:
        return 'فشل';
      default:
        return '';
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return const Color(0xffcbc3d7);
      case DownloadStatus.analyzing:
        return const Color(0xff89ceff);
      case DownloadStatus.downloading:
        return const Color(0xff89ceff);
      case DownloadStatus.converting:
        return const Color(0xffd0bcff);
      case DownloadStatus.completed:
        return const Color(0xff4ade80);
      case DownloadStatus.failed:
        return const Color(0xfffb7185);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadController = Provider.of<DownloadController>(context);

    // Active tasks: queued, analyzing, downloading, converting
    final activeTasks = downloadController.tasks;
    // History tasks: completed, failed
    final historyTasks = downloadController.history;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0b1326),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('قسم التنزيلات'),
          centerTitle: true,
          actions: [
            if (historyTasks.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Color(0xfffb7185)),
                tooltip: 'مسح السجل',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        backgroundColor: const Color(0xff171f33),
                        title: const Text('مسح سجل التنزيلات', style: TextStyle(color: Color(0xffdae2fd))),
                        content: const Text('هل أنت متأكد من رغبتك في مسح سجل التنزيلات بالكامل؟ (لن يتم حذف الملفات المحملة من الهاتف).', style: TextStyle(color: Color(0xffcbc3d7))),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
                          ),
                          TextButton(
                            onPressed: () {
                              downloadController.clearHistory();
                              Navigator.pop(context);
                            },
                            child: const Text('مسح', style: TextStyle(color: Color(0xfffb7185), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
          ],
        ),
        body: activeTasks.isEmpty && historyTasks.isEmpty
            ? _buildEmptyState()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (activeTasks.isNotEmpty) ...[
                    const Text(
                      'التنزيلات النشطة والقائمة',
                      style: TextStyle(color: Color(0xffdae2fd), fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...activeTasks.map((task) => _buildActiveTaskCard(task)),
                    const SizedBox(height: 24),
                  ],
                  if (historyTasks.isNotEmpty) ...[
                    const Text(
                      'سجل التنزيلات السابقة',
                      style: TextStyle(color: Color(0xffdae2fd), fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...historyTasks.map((task) => _buildHistoryTaskCard(task)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff171f33),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: const Icon(Icons.download_for_offline, color: Color(0xffcbc3d7), size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد تنزيلات حالية',
              style: TextStyle(color: Color(0xffdae2fd), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'اذهب لتبويب المتصفح وابحث عن أي فيديو يوتيوب لتنزيله وسيظهر تقدمه هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xffcbc3d7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTaskCard(DownloadTask task) {
    final statusColor = _getStatusColor(task.status);
    final pctText = task.status == DownloadStatus.downloading && task.progress > 0
        ? ' (${(task.progress * 100).toStringAsFixed(0)}%)'
        : '';

    return Card(
      color: const Color(0xff171f33),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.02)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.isAudio ? Icons.music_note : Icons.videocam,
                  color: const Color(0xffcbc3d7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xffdae2fd), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatStatus(task.status)}$pctText',
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  task.size.isNotEmpty ? task.size : 'غير معروف',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (task.status == DownloadStatus.downloading && task.progress > 0)
                    ? task.progress
                    : (task.status == DownloadStatus.queued ? 0.0 : null),
                minHeight: 5,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTaskCard(DownloadTask task) {
    final isSuccess = task.status == DownloadStatus.completed;
    final statusColor = _getStatusColor(task.status);

    return Card(
      color: const Color(0xff171f33).withOpacity(0.4),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.01)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            isSuccess 
                ? (task.isAudio ? Icons.audiotrack : Icons.movie) 
                : Icons.error_outline,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xffdae2fd), fontSize: 13, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              isSuccess 
                  ? 'تم الحفظ كـ ${task.isAudio ? "MP3" : "MP4"} • ${task.size}'
                  : 'فشل: ${task.errorMessage}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isSuccess ? Colors.white30 : const Color(0xfffb7185).withOpacity(0.7), fontSize: 11),
            ),
          ],
        ),
        trailing: Text(
          '${task.dateAdded.hour}:${task.dateAdded.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Colors.white12, fontSize: 10),
        ),
      ),
    );
  }
}
