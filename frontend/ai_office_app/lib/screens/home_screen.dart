import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'pdf_screen.dart';
import 'meeting_screen.dart';
import 'email_screen.dart';
import 'pipeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final List<_FeatureData> _features = [
    _FeatureData(
      icon: Icons.picture_as_pdf_rounded,
      iconColor: AppColors.secondary,
      bgColor: Color(0xFFD6EAF8),
      title: 'PDF Summarizer',
      subtitle: 'Upload and summarize any PDF',
    ),
    _FeatureData(
      icon: Icons.mic_rounded,
      iconColor: AppColors.accent,
      bgColor: Color(0xFFD5F5E3),
      title: 'Meeting Notes',
      subtitle: 'Transcribe and summarize meetings',
    ),
    _FeatureData(
      icon: Icons.email_rounded,
      iconColor: AppColors.orange,
      bgColor: Color(0xFFFDEBD0),
      title: 'Email Generator',
      subtitle: 'Draft professional emails with AI',
    ),
    _FeatureData(
      icon: Icons.auto_awesome,
      iconColor: Color(0xFF6C3483),
      bgColor: Color(0xFFE8DAEF),
      title: 'Smart Pipeline',
      subtitle: 'Meeting → Summary → Email (Auto)',
    ),
  ];

  int _selectedNav = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What would you like to do?',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                    const SizedBox(height: 16),
                    ..._features.asMap().entries.map((e) => _buildCard(
                        context, e.key, e.value)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A5276), Color(0xFF2471A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                size: 44, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text('AI Office Assistant',
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text('Your offline AI powered workspace',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, int index, _FeatureData data) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 120),
      curve: Curves.easeOut,
      builder: (context, val, child) =>
          Opacity(
            opacity: val,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - val)),
              child: child,
            ),
          ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _FeatureCard(
          data: data,
          onTap: () {
            if (index == 0) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PdfScreen()));
            } else if (index == 1) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MeetingScreen()));
            } else if (index == 2) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmailScreen()));
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PipelineScreen()));
            }
          },
        ),
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  const _FeatureData({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
  });
}

class _FeatureCard extends StatefulWidget {
  final _FeatureData data;
  final VoidCallback onTap;
  const _FeatureCard({required this.data, required this.onTap});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.data.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.data.icon,
                  color: widget.data.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.data.title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  const SizedBox(height: 3),
                  Text(widget.data.subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 15, color: AppColors.textLight),
          ]),
        ),
      ),
    );
  }
}