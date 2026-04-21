import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final name  = auth.username;
    final inits = name.length >= 2 ? name.substring(0,2).toUpperCase() : name.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // Blue header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text('Manage your preferences', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [

          // ACCOUNT
          _label('ACCOUNT'),
          _section([
            Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: AppColors.primary,
                  child: Text(inits, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const Text('Offline account', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ]),
            ])),
            const Divider(height:1, indent:16, endIndent:16),
            _row(Icons.person_outline, const Color(0xFFEBF5FB), 'Edit Profile', AppColors.textDark, () => _editDialog(context, name)),
            const Divider(height:1, indent:16, endIndent:16),
            _row(Icons.lock_outline, const Color(0xFFF0E6FF), 'Change Password', AppColors.textDark, () => _changePassDialog(context)),
          ]),
          const SizedBox(height: 16),

          // APPEARANCE
          _label('APPEARANCE'),
          _section([
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [
              Container(width:36, height:36, decoration: BoxDecoration(color: const Color(0xFFFFF9C4), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.light_mode, color: Color(0xFFF39C12), size: 20)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Theme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              Switch(value: auth.isDark, activeColor: AppColors.primary, onChanged: (v) async { auth.setTheme(v ? 'dark' : 'light'); await ApiService.updateTheme(v ? 'dark' : 'light'); }),
            ])),
          ]),
          const SizedBox(height: 16),

          // ABOUT
          _label('ABOUT'),
          _section([
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [const Text('Version', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)), const Spacer(), const Text('1.0.0', style: TextStyle(fontSize: 15, color: AppColors.textGrey))])),
            const Divider(height:1, indent:16, endIndent:16),
            _row(null, null, 'Privacy Policy', AppColors.textDark, () {}),
          ]),
          const SizedBox(height: 16),

          // DANGER ZONE
          _label('DANGER ZONE'),
          _section([
            _row(Icons.logout, const Color(0xFFFADBD8), 'Log Out', const Color(0xFFC0392B), () async => await auth.logout()),
            const Divider(height:1, indent:16, endIndent:16),
            _row(Icons.delete_forever, const Color(0xFFFADBD8), 'Delete Account', const Color(0xFFC0392B), () => _deleteDialog(context)),
          ]),
          const SizedBox(height: 24),
        ])),
      ]),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(left:4, bottom:8), child: Text(t, style: const TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:AppColors.textGrey, letterSpacing:1.2)));
  Widget _section(List<Widget> c) => Container(decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))]), child: Column(children: c));
  Widget _row(IconData? ic, Color? icBg, String label, Color lc, VoidCallback onTap) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal:16, vertical:2),
    leading: ic != null ? Container(width:36, height:36, decoration: BoxDecoration(color:icBg, borderRadius: BorderRadius.circular(8)), child: Icon(ic, color:lc, size:20)) : null,
    title: Text(label, style: TextStyle(fontSize:15, fontWeight:FontWeight.w500, color:lc)),
    trailing: const Icon(Icons.chevron_right, color:AppColors.textGrey, size:20),
    onTap: onTap,
  );

  void _editDialog(BuildContext ctx, String name) => showDialog(context: ctx, builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    title: const Text('Edit Profile'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Username cannot be changed in offline mode.', style: TextStyle(color: Colors.grey, fontSize:13)), const SizedBox(height:12), Text('Current: $name', style: const TextStyle(fontWeight: FontWeight.bold))]),
    actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
  ));

  void _changePassDialog(BuildContext context) {
    final c1 = TextEditingController(), c2 = TextEditingController();
    String? err;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Change Password'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: c1, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder())),
        const SizedBox(height:12),
        TextField(controller: c2, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
        if (err != null) Padding(padding: const EdgeInsets.only(top:8), child: Text(err!, style: const TextStyle(color: Colors.red, fontSize:12))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async { try { await ApiService.changePassword(currentPassword: c1.text, newPassword: c2.text); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed!'))); } catch (e) { setS(() => err = e.toString().replaceAll('Exception: ','')); } }, child: const Text('Change')),
      ],
    )));
  }

  void _deleteDialog(BuildContext context) => showDialog(context: context, builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    title: const Text('Delete Account?', style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.bold)),
    content: const Text('Permanently deletes your account and all history. Cannot be undone.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B), foregroundColor: Colors.white),
        onPressed: () async { Navigator.pop(context); await ApiService.deleteAccount(); await context.read<AuthProvider>().logout(); },
        child: const Text('Delete Forever'),
      ),
    ],
  ));
}
