const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Read credentials from environment variables or functions config
const gmailUser = process.env.GMAIL_USER || (functions.config && functions.config().gmail && functions.config().gmail.user);
const gmailPass = process.env.GMAIL_PASS || (functions.config && functions.config().gmail && functions.config().gmail.pass);

if (!gmailUser || !gmailPass) {
  functions.logger.warn('GMAIL_USER / GMAIL_PASS not set. Email send will fail until configured.');
}

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: gmailUser,
    pass: gmailPass,
  },
});

/**
 * Callable function that will:
 * 1) create or fetch a Firebase Auth user from provided `email` (and `password`) and `displayName`
 * 2) write { authUid } into Firestore doc `care_recipients/<recipientId>` (merge) if recipientId is provided
 * 3) send the email using provided `to`/`subject`/`text`
 * 4) return per-recipient creation + email status
 */
exports.sendTestEmail = functions.https.onCall(async (data, context) => {
  functions.logger.info('sendTestEmail called', { data });

  // Unwrap possible wrappers (some SDKs wrap payloads)
  let payload = data;
  if (payload && typeof payload === 'object') {
    if (Object.prototype.hasOwnProperty.call(payload, 'data') && payload.data && typeof payload.data === 'object') {
      functions.logger.info('Detected nested payload under `data` property — unwrapping.');
      payload = payload.data;
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'rawRequest') && payload.rawRequest && payload.rawRequest.body) {
      functions.logger.info('Detected payload under rawRequest.body — unwrapping.');
      payload = payload.rawRequest.body;
    }
  }

  // Accept either `to` (string or array) or `email` (string)
  const toField = payload?.to || payload?.email || null;
  let recipients = null;
  if (Array.isArray(toField)) recipients = toField.map((r) => String(r));
  else if (typeof toField === 'string') recipients = [String(toField)];
  else recipients = null;

  if (!recipients || recipients.length === 0) {
    functions.logger.error('Missing recipients in payload', { payloadKeys: payload ? Object.keys(payload) : null });
    throw new functions.https.HttpsError('invalid-argument', 'Missing "to" or "email" in request payload');
  }

  const password = payload?.password ? String(payload.password) : null;
  const displayName = payload?.displayName ? String(payload.displayName) : null;
  const recipientId = payload?.recipientId ? String(payload.recipientId) : null;
  const subject = payload?.subject || 'Hello from CareLink!';
  const text = payload?.text || '';
  const html = payload?.html || null;
  const fromAddress = process.env.FROM_EMAIL || gmailUser || 'no-reply@yourdomain.com';

  const overall = { recipients: [] };

  for (const email of recipients) {
    const result = { email, createdUser: null, wroteFirestore: null, mail: null };
    let userRecord;

    // Create or fetch auth user
    try {
      const createParams = { email };
      if (password) createParams.password = password;
      if (displayName) createParams.displayName = displayName;

      userRecord = await admin.auth().createUser(createParams);
      functions.logger.info('Created new auth user', { uid: userRecord.uid, email: userRecord.email });
      result.createdUser = { uid: userRecord.uid, created: true };
    } catch (createErr) {
      functions.logger.warn('createUser failed; attempting to fetch existing user', { err: createErr && createErr.message ? createErr.message : String(createErr) });
      try {
        userRecord = await admin.auth().getUserByEmail(email);
        functions.logger.info('Fetched existing auth user', { uid: userRecord.uid, email: userRecord.email });
        result.createdUser = { uid: userRecord.uid, created: false };
      } catch (fetchErr) {
        functions.logger.error('Failed to create or fetch user', { fetchErr: fetchErr && fetchErr.message ? fetchErr.message : String(fetchErr) });
        result.createdUser = { error: fetchErr && fetchErr.message ? fetchErr.message : String(fetchErr) };
        overall.recipients.push(result);
        continue; // skip firestore write and email send for this recipient
      }
    }

    // Write authUid into Firestore if recipientId provided
    if (recipientId) {
      try {
        await admin.firestore().collection('care_recipients').doc(recipientId).set({ authUid: userRecord.uid }, { merge: true });
        functions.logger.info('Wrote authUid to Firestore for recipient', { recipientId, uid: userRecord.uid });
        result.wroteFirestore = true;
      } catch (fsErr) {
        functions.logger.error('Failed to write Firestore doc for recipient', { recipientId, err: fsErr && fsErr.message ? fsErr.message : String(fsErr) });
        result.wroteFirestore = { success: false, error: fsErr && fsErr.message ? fsErr.message : String(fsErr) };
      }
    }

    // Send email to this recipient
    const mailOptions = { from: fromAddress, to: email, subject, text };
    if (html) mailOptions.html = html;
    try {
      const info = await transporter.sendMail(mailOptions);
      functions.logger.info('Email sent OK', { email, info });
      result.mail = { success: true, messageId: info.messageId, accepted: info.accepted, rejected: info.rejected };
    } catch (mailErr) {
      functions.logger.error('Error sending email', { email, err: mailErr && mailErr.message ? mailErr.message : String(mailErr) });
      result.mail = { success: false, error: mailErr && mailErr.message ? mailErr.message : String(mailErr) };
    }

    overall.recipients.push(result);
  }

  // Provide a convenience list of created/fetched UIDs and a single `uid` when only one recipient was provided.
  const uids = overall.recipients
    .map((r) => (r && r.createdUser && r.createdUser.uid ? r.createdUser.uid : null))
    .filter((u) => u != null);

  overall.uids = uids;
  if (uids.length === 1) overall.uid = uids[0];
  overall.success = uids.length > 0;

  return overall;
});
