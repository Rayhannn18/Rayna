const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();
setGlobalOptions({ region: 'asia-southeast1', maxInstances: 10 });
const db = admin.firestore();

/**
 * Loads user notification preferences from `users/{uid}.notificationSettings`.
 */
async function getUserNotificationPrefs(uid) {
  const doc = await db.collection('users').doc(uid).get();
  const settings = doc.data()?.notificationSettings || {};
  return {
    allEnabled: settings.allEnabled !== false,
    moments: settings.moments !== false,
    mood: settings.mood !== false,
    messages: settings.messages !== false,
    pairing: settings.pairing !== false,
    reactions: settings.reactions !== false,
    speedAlerts: settings.speedAlerts !== false,
    lockScreenPhotoPreview:
      settings.lockScreenPhotoPreview ?? settings.previews ?? true,
    hideContentOnLockScreen: settings.hideContentOnLockScreen === true,
  };
}

/**
 * Resolves the active partner UID from `pairs/{pairId}.memberUids`.
 */
async function getPartnerUid(pairId, senderUid) {
  const pairSnap = await db.collection('pairs').doc(pairId).get();
  const pairData = pairSnap.data();
  if (!pairData || pairData.status === 'dissolved') return null;
  const members = Array.isArray(pairData.memberUids) ? pairData.memberUids : [];
  if (!members.includes(senderUid)) return null;
  return members.find((uid) => uid !== senderUid) || null;
}

/**
 * Sends a data-first FCM multicast message to all registered devices of [uid]
 * and automatically cleans up invalid/unregistered FCM tokens.
 */
async function sendDataPush(uid, { channelId, priority = 'high', data }) {
  const devicesSnap = await db.collection('users').doc(uid).collection('devices').get();
  const entries = devicesSnap.docs
    .map((doc) => ({ ref: doc.ref, token: doc.data().fcmToken }))
    .filter((entry) => Boolean(entry.token));

  if (!entries.length) return;

  const stringData = {};
  for (const [key, value] of Object.entries(data)) {
    if (value !== undefined && value !== null) {
      stringData[key] = String(value);
    }
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens: entries.map((e) => e.token),
    data: stringData,
    android: {
      priority: priority === 'max' ? 'high' : priority,
      ttl: 3600 * 1000,
    },
  });

  // Clean up invalid / expired tokens
  const cleanup = [];
  response.responses.forEach((res, idx) => {
    if (!res.success) {
      const code = res.error?.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        cleanup.push(entries[idx].ref.delete());
      }
    }
  });
  if (cleanup.length) {
    await Promise.allSettled(cleanup);
  }
}

// 1. Connection Request Created
exports.onConnectionRequestCreated = onDocumentCreated(
  'connectionRequests/{requestId}',
  async (event) => {
    const req = event.data?.data();
    if (!req || req.status !== 'pending' || !req.toUid) return;
    const prefs = await getUserNotificationPrefs(req.toUid);
    if (!prefs.allEnabled || !prefs.pairing) return;

    const senderName = req.fromDisplayName || req.fromUsername || 'Someone';
    await sendDataPush(req.toUid, {
      channelId: 'rayna_pairing',
      data: {
        type: 'connection_request',
        eventId: `req_${event.params.requestId}`,
        requestId: event.params.requestId,
        senderUid: req.fromUid || '',
        title: 'Rayna · Connection Request',
        body: `${senderName} wants to connect with you ❤️`,
      },
    });
  },
);

// 2. Connection Request Accepted
exports.onConnectionRequestUpdated = onDocumentUpdated(
  'connectionRequests/{requestId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || before?.status === 'accepted' || after.status !== 'accepted') {
      return;
    }
    if (!after.fromUid) return;
    const prefs = await getUserNotificationPrefs(after.fromUid);
    if (!prefs.allEnabled || !prefs.pairing) return;

    const partnerName = after.toDisplayName || after.toUsername || 'Your partner';
    await sendDataPush(after.fromUid, {
      channelId: 'rayna_pairing',
      data: {
        type: 'request_accepted',
        eventId: `req_acc_${event.params.requestId}`,
        requestId: event.params.requestId,
        senderUid: after.toUid || '',
        title: 'Rayna · Request Accepted',
        body: `${partnerName} accepted your connection request! Your private space is ready ❤️`,
      },
    });
  },
);

// 3. New Moment Shared (supports both direct-ready create and legacy update)
exports.onMomentCreated = onDocumentCreated(
  'pairs/{pairId}/moments/{momentId}',
  async (event) => {
    const moment = event.data?.data();
    if (!moment || moment.status !== 'ready') return;
    const recipient = await getPartnerUid(event.params.pairId, moment.senderUid);
    if (!recipient) return;

    const prefs = await getUserNotificationPrefs(recipient);
    if (!prefs.allEnabled || !prefs.moments) return;

    const senderName = moment.senderName || 'Your partner';
    const caption = (moment.caption || '').trim();
    const body = caption
      ? `${senderName} sent you a moment ❤️ "${caption}"`
      : `${senderName} sent you a moment ❤️`;

    // Never send raw binary or huge data URIs in FCM payloads; only HTTPS URLs
    const rawUrl = moment.downloadUrl || '';
    const safeImageUrl =
      prefs.lockScreenPhotoPreview &&
      !prefs.hideContentOnLockScreen &&
      rawUrl.startsWith('https://')
        ? rawUrl
        : '';

    await sendDataPush(recipient, {
      channelId: 'rayna_moments',
      data: {
        type: 'moment',
        eventId: `moment_${event.params.momentId}`,
        momentId: event.params.momentId,
        pairId: event.params.pairId,
        senderUid: moment.senderUid || '',
        imageUrl: safeImageUrl,
        title: 'Rayna · New Moment',
        body,
      },
    });
  },
);

// 4. Moment Quick Reaction Created
exports.onMomentReactionCreated = onDocumentCreated(
  'pairs/{pairId}/moments/{momentId}/reactions/{uid}',
  async (event) => {
    const reaction = event.data?.data();
    if (!reaction) return;
    const recipient = await getPartnerUid(event.params.pairId, reaction.uid);
    if (!recipient) return;

    const prefs = await getUserNotificationPrefs(recipient);
    if (!prefs.allEnabled || !prefs.reactions) return;

    const name = reaction.displayName || 'Your partner';
    const emoji = reaction.emoji || '❤️';
    await sendDataPush(recipient, {
      channelId: 'rayna_reactions',
      data: {
        type: 'moment_reaction',
        eventId: `mreact_${event.params.momentId}_${reaction.uid}`,
        momentId: event.params.momentId,
        pairId: event.params.pairId,
        senderUid: reaction.uid || '',
        title: 'Rayna · New Reaction',
        body: `${name} reacted ${emoji} to your moment.`,
      },
    });
  },
);

// 5. Mood Check-In Created (from moodHistory)
exports.onMoodCreated = onDocumentCreated(
  'pairs/{pairId}/moodHistory/{historyId}',
  async (event) => {
    const mood = event.data?.data();
    if (!mood) return;
    const recipient = await getPartnerUid(event.params.pairId, mood.uid);
    if (!recipient) return;

    const prefs = await getUserNotificationPrefs(recipient);
    if (!prefs.allEnabled || !prefs.mood) return;

    const name = mood.displayName || 'Your partner';
    const emoji = mood.emoji || '✨';
    const note = (mood.note || '').trim();
    const body = note
      ? `${name} is feeling ${mood.mood} ${emoji} — "${note}"`
      : `${name} is feeling ${mood.mood} ${emoji}`;

    await sendDataPush(recipient, {
      channelId: 'rayna_moods',
      data: {
        type: 'mood',
        eventId: `mood_${event.params.historyId}`,
        moodHistoryId: event.params.historyId,
        pairId: event.params.pairId,
        senderUid: mood.uid || '',
        title: 'Rayna · Mood Update',
        body,
      },
    });
  },
);

// 6. Mood Quick Response Created
exports.onMoodReactionCreated = onDocumentCreated(
  'pairs/{pairId}/moodHistory/{historyId}/responses/{responseId}',
  async (event) => {
    const resp = event.data?.data();
    if (!resp) return;
    const recipient = await getPartnerUid(event.params.pairId, resp.uid);
    if (!recipient) return;

    const prefs = await getUserNotificationPrefs(recipient);
    if (!prefs.allEnabled || !prefs.mood) return;

    const name = resp.displayName || 'Your partner';
    await sendDataPush(recipient, {
      channelId: 'rayna_moods',
      data: {
        type: 'mood_response',
        eventId: `mresp_${event.params.responseId}`,
        moodHistoryId: event.params.historyId,
        pairId: event.params.pairId,
        senderUid: resp.uid || '',
        title: 'Rayna · Mood Response',
        body: `${name}: ${resp.message || 'Sent you love ❤️'}`,
      },
    });
  },
);

// 7. New Private Chat Message
exports.onMessageCreated = onDocumentCreated(
  'pairs/{pairId}/messages/{messageId}',
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    const recipient = await getPartnerUid(event.params.pairId, msg.senderUid);
    if (!recipient) return;

    const prefs = await getUserNotificationPrefs(recipient);
    if (!prefs.allEnabled || !prefs.messages) return;

    const senderName = msg.senderName || 'Your partner';
    const text = prefs.hideContentOnLockScreen
      ? 'Sent you a private message.'
      : msg.text || 'Sent you a message.';

    await sendDataPush(recipient, {
      channelId: 'rayna_messages',
      data: {
        type: 'message',
        eventId: `msg_${event.params.messageId}`,
        pairId: event.params.pairId,
        senderUid: msg.senderUid || '',
        title: `Rayna · ${senderName}`,
        body: text,
      },
    });
  },
);

// 8. Speed Alert 80 km/h Triggered
exports.onSpeedAlertTriggered = onDocumentCreated(
  'pairs/{pairId}/speedAlerts/{alertId}',
  async (event) => {
    const alert = event.data?.data();
    if (!alert || typeof alert.speedKmh !== 'number' || alert.speedKmh < 80) {
      return;
    }
    const recipient = await getPartnerUid(event.params.pairId, alert.uid);
    if (!recipient) return;

    const prefs = await getUserNotificationPrefs(recipient);
    if (!prefs.allEnabled || !prefs.speedAlerts) return;

    const rounded = Math.round(alert.speedKmh);
    await sendDataPush(recipient, {
      channelId: 'rayna_speed_alerts',
      priority: 'max',
      data: {
        type: 'speed_alert',
        eventId: `speed_${event.params.alertId}`,
        speedAlertId: event.params.alertId,
        pairId: event.params.pairId,
        senderUid: alert.uid || '',
        speedKmh: rounded,
        title: '⚠️ Rayna · Speed Alert',
        body: `Your partner's location speed is detected at ${rounded} km/h. Please remind them to slow down and stay safe.`,
      },
    });
  },
);

// 9. Speed Alert Quick Safety Warning Response
exports.onSpeedAlertResponseCreated = onDocumentCreated(
  'pairs/{pairId}/speedAlerts/{alertId}/responses/{responseId}',
  async (event) => {
    const resp = event.data?.data();
    if (!resp) return;
    const recipient = await getPartnerUid(event.params.pairId, resp.uid);
    if (!recipient) return;

    const prefs = await getUserNotificationPrefs(recipient);
    if (!prefs.allEnabled || !prefs.speedAlerts) return;

    await sendDataPush(recipient, {
      channelId: 'rayna_speed_alerts',
      priority: 'max',
      data: {
        type: 'speed_alert_response',
        eventId: `sresp_${event.params.responseId}`,
        speedAlertId: event.params.alertId,
        pairId: event.params.pairId,
        senderUid: resp.uid || '',
        title: 'Your partner is worried about you ❤️',
        body: resp.message || 'Please slow down. I want you to stay safe.',
      },
    });
  },
);
