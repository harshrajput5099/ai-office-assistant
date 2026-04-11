import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/export_panel.dart';

class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key});
  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen>
    with SingleTickerProviderStateMixin {
  bool _useMistral = false;
  bool _isLoading = false;
  String? _summary;
  int? _chunkCount;
  String? _modelUsed;
  String? _error;
  String? _selectedFileName;
  String? _docType;
  String? _fileName;
  late AnimationController _resultController;
  late Animation<double> _resultAnim;

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _resultAnim =
        CurvedAnimation(parent: _resultController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSummarize() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // ← required for web: loads bytes directly
    );
    if (result == null) return;

    final fileName = result.files.single.name;
    final fileBytes = result.files.single.bytes; // Uint8List — works on web & mobile

    if (fileBytes == null) {
      setState(() => _error = 'Could not read file. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _summary = null;
      _selectedFileName = fileName;
      _fileName = fileName;
    });

    try {
      final response = await ApiService.summarizePdf(
        fileBytes,
        fileName,
        useMistral: _useMistral,
      );
      setState(() {
        _summary    = response['summary'] as String?;
        _docType    = response['doc_type'] as String? ?? 'document';
        _chunkCount = response['chunk_count'] as int?;
        _modelUsed  = response['model_used'] as String?;
        _isLoading  = false;
      });
      _resultController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('PDF Summarizer',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A5276), Color(0xFF2471A3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadBox(),
            const SizedBox(height: 16),
            _buildModelSelector(),
            const SizedBox(height: 16),
            _buildSummarizeButton(),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              _buildLoadingCard(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _resultAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_resultAnim),
                  child: _buildResultCard(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _isLoading ? null : _pickAndSummarize,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: _selectedFileName != null
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.uploadBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedFileName != null
                ? AppColors.primary
                : AppColors.secondary,
            width: 1.5,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _selectedFileName != null
                ? Icons.picture_as_pdf_rounded
                : Icons.upload_rounded,
            size: 48,
            color: _selectedFileName != null
                ? AppColors.primary
                : AppColors.secondary,
          ),
          const SizedBox(height: 12),
          Text(
            _selectedFileName ?? 'Tap to select PDF',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _selectedFileName != null
                  ? AppColors.primary
                  : AppColors.secondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text('Supports PDF files up to 20 pages',
              style:
              GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
        ]),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('AI Model',
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _ModelButton(
                label: 'Small Summary',
                isSelected: !_useMistral,
                onTap: () => setState(() => _useMistral = false))),
        const SizedBox(width: 12),
        Expanded(
            child: _ModelButton(
                label: 'Large Summary',
                isSelected: _useMistral,
                onTap: () => setState(() => _useMistral = true))),
      ]),
      const SizedBox(height: 6),
      Text(
        _useMistral
            ? '⚡ Better quality. Requires Ollama running.'
            : '🚀 Fast and fully offline.',
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
      ),
    ]);
  }

  Widget _buildSummarizeButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (_isLoading || _selectedFileName == null)
            ? null
            : _pickAndSummarize,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          _selectedFileName == null ? 'Select a PDF first' : 'Summarize PDF',
          style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          _useMistral
              ? 'Mistral is thinking... (may take 30-60s)'
              : 'T5 is summarizing your PDF...',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_error!,
                style:
                GoogleFonts.inter(fontSize: 13, color: AppColors.error))),
      ]),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header row: icon + title + copy button ───────────────
        Row(children: [
          const Icon(Icons.summarize_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text('Summary',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_rounded,
                color: AppColors.textLight, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _summary!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Copied!', style: GoogleFonts.inter()),
                backgroundColor: AppColors.accent,
                duration: const Duration(seconds: 2),
              ));
            },
          ),
        ]),

        const Divider(height: 16),

        // ── Doc type badge ───────────────────────────────────────
        if (_docType != null && _docType!.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Text(
              _docType!.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],

        // ── Summary text ─────────────────────────────────────────
        Text(_summary!,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textDark, height: 1.6)),

        const SizedBox(height: 12),

        // ── Chips: chunk count + model used ─────────────────────
        Wrap(spacing: 8, children: [
          _Chip(
              label: '${_chunkCount ?? 0} chunks',
              color: AppColors.primary),
          _Chip(
              label: _modelUsed ?? 't5-small',
              color: AppColors.accent),
        ]),

        // ── Export Panel ─────────────────────────────────────────
        if (_fileName != null) ...[
          const SizedBox(height: 16),
          ExportPanel(
            summary: _summary!,
            filename: _fileName!,
          ),
        ],

      ]),
    );
  }
}

class _ModelButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ModelButton(
      {required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textLight.withOpacity(0.3)),
          boxShadow: isSelected
              ? [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]
              : [],
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textDark)),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }
}