import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});
  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen>
    with SingleTickerProviderStateMixin {
  final _purposeController = TextEditingController();
  final _recipientController = TextEditingController();
  final _keyPointsController = TextEditingController();
  final _callToActionController = TextEditingController();
  String _selectedTone = 'formal';
  bool _isLoading = false;
  String? _generatedEmail;
  String? _error;
  late AnimationController _resultController;
  late Animation<double> _resultAnim;

  final List<String> _tones = ['formal', 'semi-formal', 'friendly'];

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
    _purposeController.dispose();
    _recipientController.dispose();
    _keyPointsController.dispose();
    _callToActionController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _generateEmail() async {
    if (_purposeController.text.isEmpty ||
        _recipientController.text.isEmpty) {
      setState(() =>
      _error = 'Please fill in Email Purpose and Recipient Role.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _generatedEmail = null;
    });
    try {
      final keyPoints = _keyPointsController.text
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final email = await ApiService.generateEmail(
        purpose: _purposeController.text,
        recipientRole: _recipientController.text,
        tone: _selectedTone,
        keyPoints: keyPoints,
        callToAction: _callToActionController.text,
      );
      setState(() {
        _generatedEmail = email;
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
        title: Text('Email Generator',
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
            _buildFormCard(),
            const SizedBox(height: 16),
            _buildGenerateButton(),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              _buildLoadingCard(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
            if (_generatedEmail != null) ...[
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
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
        _buildInputField(
          label: 'Email Purpose',
          controller: _purposeController,
          placeholder: 'e.g. Request a meeting',
          icon: Icons.flag_rounded,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Recipient Role',
          controller: _recipientController,
          placeholder: 'e.g. HR Manager, Client, Professor',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 16),
        _buildToneSelector(),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Key Points (one per line)',
          controller: _keyPointsController,
          placeholder: 'Enter key points...',
          icon: Icons.list_rounded,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Required Response',
          controller: _callToActionController,
          placeholder: 'e.g. Please confirm by Friday',
          icon: Icons.reply_rounded,
        ),
      ]),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark)),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle:
          GoogleFonts.inter(fontSize: 13, color: AppColors.textLight),
          filled: true,
          fillColor: AppColors.background,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            BorderSide(color: Colors.grey.withOpacity(0.25), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    ]);
  }

  Widget _buildToneSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.tune_rounded, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text('Tone',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: _tones.map((tone) {
          final isSelected = tone == _selectedTone;
          return GestureDetector(
            onTap: () => setState(() => _selectedTone = tone),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textLight.withOpacity(0.4),
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
                    : [],
              ),
              child: Text(
                tone[0].toUpperCase() + tone.substring(1),
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textDark),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generateEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          disabledBackgroundColor: AppColors.orange.withOpacity(0.4),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Generate Email',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
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
        const CircularProgressIndicator(color: AppColors.orange),
        const SizedBox(height: 16),
        Text('Mistral is drafting your email...',
            style:
            GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
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
        Row(children: [
          const Icon(Icons.email_rounded, color: AppColors.orange, size: 20),
          const SizedBox(width: 8),
          Text('Generated Email',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_rounded,
                color: AppColors.textLight, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generatedEmail!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Email copied!', style: GoogleFonts.inter()),
                backgroundColor: AppColors.orange,
                duration: const Duration(seconds: 2),
              ));
            },
          ),
        ]),
        const Divider(height: 16),
        Text(_generatedEmail!,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textDark, height: 1.6)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: _generatedEmail!));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                  Text('Copied!', style: GoogleFonts.inter()),
                  backgroundColor: AppColors.accent,
                  duration: const Duration(seconds: 2),
                ));
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text('Copy',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateEmail,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: Colors.white),
              label: Text('Regenerate',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}