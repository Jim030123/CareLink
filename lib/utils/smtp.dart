
// // In-app SMTP helper using the `mailer` package.
// // NOTE: Embedding SMTP credentials in a mobile app is insecure. Prefer a
// // server-side function (Cloud Function) for production. This helper is
// // intended for testing or trusted environments only.

// import 'package:mailer/mailer.dart';

// /// SMTP configuration holder.
// class SmtpConfig {
// 	final String host;
// 	final int port;
// 	final String username;
// 	final String password;
// 	final bool useSsl;

// 	const SmtpConfig({
// 		required this.host,
// 		required this.port,
// 		required this.username,
// 		required this.password,
// 		this.useSsl = true,
// 	});
// }

// /// Result of a send attempt.
// class SmtpResult {
// 	final bool success;
// 	final String? message;

// 	SmtpResult(this.success, [this.message]);
// }

// /// Send an email using the provided SMTP config.
// ///
// /// Example:
// /// ```dart
// /// final cfg = SmtpConfig(
// ///   host: 'smtp.gmail.com',
// ///   port: 587,
// ///   username: 'your@email.com',
// ///   password: 'app-or-smtp-password',
// ///   useSsl: false,
// /// );
// /// final res = await sendEmail(
// ///   config: cfg,
// ///   from: 'Your App <your@email.com>',
// ///   to: ['recipient@example.com'],
// ///   subject: 'Welcome',
// ///   body: '<p>Hello</p>',
// ///   isHtml: true,
// /// );
// /// ```
// Future<SmtpResult> sendEmail({
// 	required SmtpConfig config,
// 	required String from,
// 	required List<String> to,
// 	List<String>? cc,
// 	List<String>? bcc,
// 	String? subject,
// 	String? body,
// 	bool isHtml = false,
// }) async {
// 	try {
// 		final message = Message()
// 			..from = Address(config.username, from)
// 			..recipients.addAll(to)
// 			..ccRecipients.addAll(cc ?? [])
// 			..bccRecipients.addAll(bcc ?? [])
// 			..subject = subject ?? '';

// 		if (body != null && body.isNotEmpty) {
// 			if (isHtml) {
// 				message.html = body;
// 			} else {
// 				message.text = body;
// 			}
// 		}

// 		final smtpServer = SmtpServer(
// 			config.host,
// 			port: config.port,
// 			username: config.username,
// 			password: config.password,
// 			ignoreBadCertificate: false,
// 			ssl: config.useSsl,
// 		);

// 		final sendReport = await send(message, smtpServer);
// 		return SmtpResult(true, sendReport.toString());
// 	} on MailerException catch (e) {
// 		// The MailerException contains detailed information about failures
// 		return SmtpResult(false, e.toString());
// 	} catch (e) {
// 		return SmtpResult(false, e.toString());
// 	}
// }

// // Convenience helper for single-recipient simple welcome email.
// Future<SmtpResult> sendWelcomeEmail({
// 	required SmtpConfig config,
// 	required String toEmail,
// 	required String displayName,
// }) async {
// 	final subject = 'Welcome to CareLink';
// 	final html = '''
// 	<p>Hello ${_escapeHtml(displayName)},</p>
// 	<p>Welcome to CareLink — we're glad to have you onboard.</p>
// 	<p>Best regards,<br/>The CareLink Team</p>
// 	''';

// 	return sendEmail(
// 		config: config,
// 		from: 'CareLink <${config.username}>',
// 		to: [toEmail],
// 		subject: subject,
// 		body: html,
// 		isHtml: true,
// 	);
// }

// String _escapeHtml(String input) {
// 	return input
// 			.replaceAll('&', '&amp;')
// 			.replaceAll('<', '&lt;')
// 			.replaceAll('>', '&gt;')
// 			.replaceAll('"', '&quot;')
// 			.replaceAll("'", '&#x27;');
// }
