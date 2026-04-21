import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/history.dart';
import '../theme/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _all = [];
  String _filter = 'all';
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiService.getHistory();
      setState(() { _all = raw.map((e) => HistoryItem.fromJson(e)).toList(); _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  List<HistoryItem> get _filtered => _filter == 'all' ? _all : _all.where((i) => i.type == _filter).toList();

  Future<void> _delete(HistoryItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Delete item?'),
      content: Text('Delete "${item.title}"? Cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B), foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) { await ApiService.deleteHistory(item.id); setState(() => _all.removeWhere((i) => i.id == item.id)); }
  }

  IconData _icon(String type) { switch (type) { case 'summary': return Icons.description_outlined; case 'meeting': return Icons.mic_none; default: return Icons.email_outlined; } }
  Color   _iconColor(String type) { switch (type) { case 'summary': return AppColors.pdfColor; case 'meeting': return AppColors.meetingColor; default: return AppColors.emailColor; } }
  Color   _iconBg(String type)    { switch (type) { case 'summary': return const Color(0xFFD6EAF8); case 'meeting': return const Color(0xFFD5F5E3); default: return const Color(0xFFFDEBD0); } }

  String _fmt(String ts) {
    try {
      final dt = DateTime.parse(ts);
      final m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month-1];
      final h = dt.hour > 12 ? dt.hour-12 : (dt.hour==0?12:dt.hour);
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '$m ${dt.day}, ${dt.year} · $h:${dt.minute.toString().padLeft(2,'0')} $ap';
    } catch (_) { return ts.length > 16 ? ts.substring(0,16) : ts; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text('Your past documents & drafts', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ]),
        ),
        // Filter chips
        Container(
          color: AppColors.bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('all','All'), _chip('summary','PDF Summary'), _chip('meeting','Meeting Notes'), _chip('email','Email Draft'),
            ]),
          ),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _chip(String val, String label) {
    final active = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary : const Color(0xFFDDE1E7)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : AppColors.textGrey)),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)), TextButton(onPressed: _load, child: const Text('Retry'))]));
    if (_filtered.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history, size: 48, color: Colors.grey[300]), const SizedBox(height: 12), Text(_filter == 'all' ? 'No history yet.' : 'No items yet.', style: const TextStyle(color: AppColors.textGrey))]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _card(_filtered[i]),
      ),
    );
  }

  Widget _card(HistoryItem item) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))]),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: _iconBg(item.type), borderRadius: BorderRadius.circular(10)), child: Icon(_icon(item.type), color: _iconColor(item.type), size: 20)),
      title: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.access_time, size: 11, color: AppColors.textGrey), const SizedBox(width: 3), Text(_fmt(item.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textGrey))]),
        const SizedBox(height: 2),
        Text(item.content, style: const TextStyle(fontSize: 12, color: AppColors.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFC0392B), size: 20), onPressed: () => _delete(item)),
        const Icon(Icons.chevron_right, color: AppColors.textGrey, size: 20),
      ]),
      children: [const Divider(height: 1), const SizedBox(height: 10), SelectableText(item.content, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6))],
    ),
  );
}