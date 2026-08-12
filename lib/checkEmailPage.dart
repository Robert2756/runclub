import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        emailRedirectTo: 'com.enduvo.app://login-callback',
      );

      if (!mounted) return;

      setState(() {
        message = "Eine neue Bestätigungs-E-Mail wurde gesendet.";
        errorMessage = false;
      });
    } on AuthException catch (e) {
      debugPrint('RESEND ERROR\nCode: ${e.code}\nStatus: ${e.statusCode}\nMessage: ${e.message}');
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
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    "E-Mail bestätigen",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Wir haben dir einen Bestätigungslink "
                    "an diese Adresse gesendet:",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Email
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Hint
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          "Schau auch in deinem Spam- oder "
                          "Junk-Ordner nach.",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Resend button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: sending ? null : resendEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                              height: 21,
                              width: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "E-Mail erneut senden",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // Message
                  if (message != null) ...[
                    const SizedBox(height: 16),
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
                        borderRadius: BorderRadius.circular(13),
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
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              message!,
                              style: TextStyle(
                                color: errorMessage
                                    ? Colors.red[800]
                                    : Colors.green[800],
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
    );
  }
}
