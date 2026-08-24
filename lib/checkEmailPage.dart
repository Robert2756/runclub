import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

final supabase = Supabase.instance.client;

class CheckEmailPage extends StatefulWidget {
  final String email;

  const CheckEmailPage({
    super.key,
    required this.email,
  });

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage> {
  bool sending = false;
  String? message;
  bool errorMessage = false;

  Future<void> resendEmail() async {
    if (sending) return;

    setState(() {
      sending = true;
      message = null;
      errorMessage = false;
    });

    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: 'com.enduvoapp://login-callback',
      );

      if (!mounted) return;

      setState(() {
        message = "Eine neue Bestätigungs-E-Mail wurde gesendet.";
        errorMessage = false;
      });
    } on AuthException catch (e) {
      debugPrint(
        'RESEND ERROR\nCode: ${e.code}\nStatus: ${e.statusCode}\nMessage: ${e.message}',
      );

      if (!mounted) return;

      final isRateLimited = e.code == 'over_email_send_rate_limit';

      setState(() {
        errorMessage = true;
        message = isRateLimited
            ? "Bitte warte 60 Sekunden, bevor du eine weitere E-Mail anforderst."
            : "Die E-Mail konnte nicht gesendet werden.\nBitte versuche es später erneut.";
      });
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: Color(0xFF111827),
          ),
          onPressed: () =>context.go('/signin'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Small, restrained brand-colored icon.
                      Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3F7),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            size: 28,
                            color: Color(0xFF12406B),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        "E-Mail bestätigen",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Wir haben dir einen Bestätigungslink "
                        "an diese Adresse gesendet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Email
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          widget.email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Spam hint
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              "Keine E-Mail erhalten? Schau auch in deinem "
                              "Spam- oder Junk-Ordner nach.",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Resend
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: sending ? null : resendEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFFE5E7EB),
                            disabledForegroundColor:
                                const Color(0xFF9CA3AF),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: sending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "E-Mail erneut senden",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      // Message
                      if (message != null) ...[
                        const SizedBox(height: 14),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: errorMessage
                                ? const Color(0xFFFFF2F2)
                                : const Color(0xFFF1F8F3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                errorMessage
                                    ? Icons.error_outline_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 18,
                                color: errorMessage
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  message!,
                                  style: TextStyle(
                                    color: errorMessage
                                        ? Colors.red.shade800
                                        : Colors.green.shade800,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}