// lib/screens/pipeline_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});
  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  // ── Input state ────────────────────────────────────────────
  Uint8List? _audioBytes;
  String?    _audioName;
  final _textCtrl      = TextEditingController();
  final _recipientCtrl = TextEditingController();
  String _tone     = 'formal';
  bool   _useAudio = true;

  // ── Output state ───────────────────────────────────────────
  bool    _running = false;
  String? _error;
  Map<String, dynamic>? _result;

  // ── Stage reveal flags ─────────────────────────────────────
  bool _show1 = false, _show2 = false, _show3 = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _recipientCtrl.dispose();
    super.dispose();
  }

  // ── Pick audio file ────────────────────────────────────────
  Future<void> _pickAudio() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg'],
      withData: true,
    );
    if (res == null) return;
    setState(() {
      _audioBytes = res.files.single.bytes;
      _audioName  = res.files.single.name;
    });
  }

  // ── Run the pipeline ───────────────────────────────────────
  Future<void> _run() async {
    if (_useAudio && _audioBytes == null) {
      setState(() => _error = 'Please select an audio file first.');
      return;
    }
    if (!_useAudio && _textCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please paste your meeting transcript.');
      return;
    }

    setState(() {
      _running = true;
      _error   = null;
      _result  = null;
      _show1 = _show2 = _show3 = false;
    });

    try {
      final result = await ApiService.runPipeline(
        audioBytes:     _useAudio ? _audioBytes    : null,
        audioFileName:  _useAudio ? _audioName     : null,
        transcriptText: _useAudio ? null           : _textCtrl.text.trim(),
        tone:           _tone,
        recipientRole:  _recipientCtrl.text.trim(),
      );

      setState(() { _result = result; _running = false; });

      // Staggered reveal
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _show1 = true);
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() => _show2 = true);
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() => _show3 = true);

      // Fire-and-forget history save
      ApiService.addHistory(
        type: 'meeting',
        title: _audioName ?? 'Pipeline Run',
        content: result['stage3_email'] ?? '',
      );
    } catch (e) {
      setState(() {
        _error   = e.toString().replaceAll('Exception: ', '');
        _running = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildInputSection()),

          // Error
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 13))),
                  ]),
                ),
              ),
            ),

          // Loading
          if (_running) SliverToBoxAdapter(child: _buildLoadingWidget()),

          // Results
          if (_result != null) ...[
            if (_show1)
              SliverToBoxAdapter(child: _buildStageCard(
                stage: 1,
                title: '📝 Transcript',
                subtitle: _result!['stage1_source'] == 'whisper'
                    ? 'Transcribed by Whisper AI'
                    : 'Typed input',
                content: _result!['stage1_transcript'] ?? '',
                color: AppColors.primary,
                bgColor: const Color(0xFFD6EAF8),
              )),
            if (_show2)
              SliverToBoxAdapter(child: _buildStage2Card()),
            if (_show3)
              SliverToBoxAdapter(child: _buildStageCard(
                stage: 3,
                title: '📧 Email Draft',
                subtitle:
                '${(_result!["tone_used"] ?? "").toString().toUpperCase()} tone · To: ${_result!["recipient_used"] ?? ""}',
                content: _result!['stage3_email'] ?? '',
                color: AppColors.orange,
                bgColor: const Color(0xFFFDEBD0),
                showCopy: true,
              )),
            SliverToBoxAdapter(child: const SizedBox(height: 32)),
          ],
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A5276), Color(0xFF2471A3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Smart Pipeline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('Meeting → Summary → Email Draft', style: TextStyle(fontSize: 13, color: Colors.white70)),
        ]),
      ]),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _pill('🎤 Input'),
          _arrow(),
          _pill('📝 Transcribe'),
          _arrow(),
          _pill('🔍 Summarize'),
          _arrow(),
          _pill('📧 Email'),
        ]),
      ),
    ]),
  );

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
  );

  Widget _arrow() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
  );

  // ── Input section ─────────────────────────────────────────
  Widget _buildInputSection() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [

      // Audio / Text toggle
      Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _useAudio = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _useAudio ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.mic, color: _useAudio ? Colors.white : AppColors.textLight, size: 18),
                const SizedBox(width: 6),
                Text('Audio File', style: TextStyle(
                  color: _useAudio ? Colors.white : AppColors.textLight,
                  fontWeight: FontWeight.w500, fontSize: 13,
                )),
              ]),
            ),
          )),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _useAudio = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !_useAudio ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.notes, color: !_useAudio ? Colors.white : AppColors.textLight, size: 18),
                const SizedBox(width: 6),
                Text('Paste Text', style: TextStyle(
                  color: !_useAudio ? Colors.white : AppColors.textLight,
                  fontWeight: FontWeight.w500, fontSize: 13,
                )),
              ]),
            ),
          )),
        ]),
      ),
      const SizedBox(height: 14),

      // Audio picker OR text field
      if (_useAudio) _buildAudioPicker() else _buildTextInput(),
      const SizedBox(height: 14),

      // Tone selector
      Row(children: [
        Text('Tone:', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textDark)),
        const SizedBox(width: 8),
        _toneChip('formal',      'Formal'),
        const SizedBox(width: 6),
        _toneChip('semiformal',  'Semi-formal'),
        const SizedBox(width: 6),
        _toneChip('friendly',    'Friendly'),
      ]),
      const SizedBox(height: 14),

      // Recipient
      TextField(
        controller: _recipientCtrl,
        decoration: InputDecoration(
          hintText: 'Recipient role (optional — auto-detected if blank)',
          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
          prefixIcon: Icon(Icons.person_outline, color: AppColors.textLight, size: 20),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      const SizedBox(height: 16),

      // Run button
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _running ? null : _run,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: _running
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_awesome, size: 20),
          label: Text(
            _running ? 'Running pipeline...' : 'Run Pipeline',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ]),
  );

  Widget _buildAudioPicker() => GestureDetector(
    onTap: _pickAudio,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _audioName != null ? AppColors.primary : Colors.grey.withOpacity(0.3),
          width: _audioName != null ? 2 : 1,
        ),
      ),
      child: Column(children: [
        Icon(
          _audioName != null ? Icons.audio_file : Icons.mic_none,
          color: _audioName != null ? AppColors.primary : AppColors.textLight,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          _audioName ?? 'Tap to select audio file',
          style: TextStyle(
            color: _audioName != null ? AppColors.primary : AppColors.textLight,
            fontWeight: _audioName != null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (_audioName == null)
          Text('MP3, WAV, M4A, OGG', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
      ]),
    ),
  );

  Widget _buildTextInput() => TextField(
    controller: _textCtrl,
    maxLines: 6,
    decoration: InputDecoration(
      hintText: 'Paste your meeting transcript or notes here...',
      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.all(16),
    ),
  );

  Widget _toneChip(String val, String label) {
    final active = _tone == val;
    return GestureDetector(
      onTap: () => setState(() => _tone = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: active ? Colors.white : AppColors.textLight,
        )),
      ),
    );
  }

  // ── Loading widget ────────────────────────────────────────
  Widget _buildLoadingWidget() => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(children: [
      CircularProgressIndicator(color: AppColors.primary),
      SizedBox(height: 16),
      Text('Running pipeline...', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
      SizedBox(height: 4),
      Text('Transcribing → Extracting → Drafting email', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
      SizedBox(height: 4),
      Text('This may take 1–3 minutes', style: TextStyle(fontSize: 11, color: AppColors.textLight, fontStyle: FontStyle.italic)),
    ]),
  );

  // ── Generic stage card ────────────────────────────────────
  Widget _buildStageCard({
    required int stage,
    required String title,
    required String subtitle,
    required String content,
    required Color color,
    required Color bgColor,
    bool showCopy = false,
  }) =>
      AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ExpansionTile(
              initiallyExpanded: stage == 3,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('$stage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
              ),
              title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (showCopy) IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: AppColors.textLight),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email copied to clipboard!'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
                const Icon(Icons.expand_more, color: AppColors.textLight),
              ]),
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                SelectableText(content, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.7)),
              ],
            ),
          ),
        ),
      );

  // ── Stage 2 card (structured analysis) ───────────────────
  Widget _buildStage2Card() {
    final r = _result!;
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFE8DAEF), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('2', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark))),
            ),
            title: const Text('🔍 Analysis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: const Text('Summary · Key Points · Action Items · Decisions', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            trailing: const Icon(Icons.expand_more, color: AppColors.textLight),
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              if ((r['stage2_summary'] ?? '').isNotEmpty) ...[
                _s2Section('Summary', r['stage2_summary']),
                const SizedBox(height: 10),
              ],
              if ((r['stage2_key_points'] ?? '').isNotEmpty) ...[
                _s2Section('Key Points', r['stage2_key_points']),
                const SizedBox(height: 10),
              ],
              if ((r['stage2_action_items'] ?? '').isNotEmpty) ...[
                _s2Section('Action Items', r['stage2_action_items']),
                const SizedBox(height: 10),
              ],
              if ((r['stage2_decisions'] ?? '').isNotEmpty && r['stage2_decisions'] != 'None')
                _s2Section('Decisions', r['stage2_decisions']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _s2Section(String label, String content) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(content, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.6)),
    ],
  );
}