// The 3-button export panel shown below the summary

import 'package:flutter/material.dart';
import '../services/export_service.dart';

class ExportPanel extends StatefulWidget {
  final String summary;
  final String filename;   // original PDF filename

  const ExportPanel({
    super.key,
    required this.summary,
    required this.filename,
  });

  @override
  State<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends State<ExportPanel> {
  String? _exporting;   // 'word', 'pdf', or 'txt'
  String? _successMsg;
  String? _error;

  Future<void> _export(String format) async {
    setState(() {
      _exporting = format;
      _successMsg = null;
      _error = null;
    });

    try {
      switch (format) {
        case 'word':
          await ExportService.exportAsWord(
            summary: widget.summary,
            filename: widget.filename,
          );
          setState(() => _successMsg = 'Word file saved and opened!');
          break;
        case 'pdf':
          await ExportService.exportAsPdf(
            summary: widget.summary,
            filename: widget.filename,
          );
          setState(() => _successMsg = 'PDF saved and opened!');
          break;
        case 'txt':
          await ExportService.exportAsText(
            summary: widget.summary,
            filename: widget.filename,
          );
          setState(() => _successMsg = 'Text file ready to share!');
          break;
      }
    } catch (e) {
      setState(() => _error = 'Export failed: ${e.toString()}');
    } finally {
      setState(() => _exporting = null);
    }
  }

  Widget _btn(String format, String label, IconData icon, Color color) {
    final loading = _exporting == format;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _exporting != null ? null : () => _export(format),
          icon: loading
              ? const SizedBox(width:18, height:18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────
          const Row(children: [
            Icon(Icons.download_rounded, size: 20,
                color: Color(0xFF1F4E79)),
            SizedBox(width: 8),
            Text('Export Summary As',
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F4E79))),
          ]),
          const SizedBox(height: 6),

          // File label
          Text('Source: ${widget.filename}',
              style: TextStyle(fontSize: 12,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 14),

          // ── 3 Export Buttons ────────────────────
          Row(children: [
            _btn('word', 'Word',
                Icons.description_rounded,
                const Color(0xFF1F4E79)),
            _btn('pdf',  'PDF',
                Icons.picture_as_pdf_rounded,
                const Color(0xFFC0392B)),
            _btn('txt',  'Text',
                Icons.text_snippet_rounded,
                const Color(0xFF117A65)),
          ]),

          // ── Success message ──────────────────────
          if (_successMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF1B5E20), size: 18),
                const SizedBox(width: 8),
                Text(_successMsg!, style: const TextStyle(
                    color: Color(0xFF1B5E20), fontSize: 13)),
              ]),
            ),
          ],

          // ── Error message ───────────────────────
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFB71C1C), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFB71C1C), fontSize: 13))),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

