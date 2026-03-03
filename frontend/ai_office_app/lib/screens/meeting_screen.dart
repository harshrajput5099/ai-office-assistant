import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});
  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _transcript;
  String? _summary;
  String? _error;
  String? _selectedFileName;
  late AnimationController _resultController;
  late Animation<double> _resultAnim;

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _resultAnim =
        CurvedAnimation(parent: _resultController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _pickAndTranscribe() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg'],
    );
    if (result == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _transcript = null;
      _summary = null;
      _selectedFileName = result.files.single.name;
    });
    try {
      File file = File(result.files.single.path!);
      final response = await ApiService.transcribeMeeting(file);
      setState(() {
        _transcript = response['transcript'] as String?;
        _summary = response['summary'] as String?;
        _isLoading = false;
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
        title: Text('Meeting Notes',
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
            _buildTranscribeButton(),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              _buildLoadingCard(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
            if (_transcript != null || _summary != null) ...[
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _resultAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_resultAnim),
                  child: Column(children: [
                    if (_transcript != null) _buildTranscriptCard(),
                    if (_summary != null) ...[
                      const SizedBox(height: 12),
                      _buildSummaryCard(),
                    ],
                  ]),
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
      onTap: _isLoading ? null : _pickAndTranscribe,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: _selectedFileName != null
              ? AppColors.accent.withOpacity(0.05)
              : AppColors.uploadBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedFileName != null
                ? AppColors.accent
                : AppColors.secondary,
            width: 1.5,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _selectedFileName != null
                ? Icons.audio_file_rounded
                : Icons.mic_rounded,
            size: 48,
            color: _selectedFileName != null
                ? AppColors.accent
                : AppColors.secondary,
          ),
          const SizedBox(height: 12),
          Text(
            _selectedFileName ?? 'Tap to upload meeting recording',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _selectedFileName != null
                  ? AppColors.accent
                  : AppColors.secondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text('MP3, WAV, M4A, OGG supported',
              style:
              GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
        ]),
      ),
    );
  }

  Widget _buildTranscribeButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed:
        (_isLoading || _selectedFileName == null) ? null : _pickAndTranscribe,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.accent.withOpacity(0.4),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.transcribe_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            _selectedFileName == null
                ? 'Select audio first'
                : 'Transcribe & Summarize',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ]),
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
        const CircularProgressIndicator(color: AppColors.accent),
        const SizedBox(height: 16),
        Text('Whisper is transcribing your meeting...',
            style:
            GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('This may take 1-2 minutes for long recordings',
            style:
            GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
            textAlign: TextAlign.center),
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

  Widget _buildTranscriptCard() {
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
        Row(children: [
          const Icon(Icons.article_rounded,
              color: AppColors.secondary, size: 20),
          const SizedBox(width: 8),
          Text('Transcript',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_rounded,
                color: AppColors.textLight, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _transcript!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Transcript copied!', style: GoogleFonts.inter()),
                backgroundColor: AppColors.secondary,
                duration: const Duration(seconds: 2),
              ));
            },
          ),
        ]),
        const Divider(height: 12),
        Container(
          height: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Text(_transcript!,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textDark, height: 1.6)),
          ),
        ),
      ]),
    );
  }

  Widget _buildSummaryCard() {
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
        Row(children: [
          const Icon(Icons.summarize_rounded,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('Meeting Summary',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_rounded,
                color: AppColors.textLight, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _summary!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Summary copied!', style: GoogleFonts.inter()),
                backgroundColor: AppColors.accent,
                duration: const Duration(seconds: 2),
              ));
            },
          ),
        ]),
        const Divider(height: 12),
        _SummarySection(
          borderColor: AppColors.secondary,
          label: 'Summary',
          content: _summary!,
        ),
      ]),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final Color borderColor;
  final String label;
  final String content;
  const _SummarySection(
      {required this.borderColor,
        required this.label,
        required this.content});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: borderColor)),
        const SizedBox(height: 4),
        Text(content,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textDark, height: 1.5)),
      ]),
    );
  }
}