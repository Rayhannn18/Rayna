const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();
setGlobalOptions({ region: 'asia-southeast1', maxInstances: 10 });
const db = admin.firestore();

async function tokensFor(uid) {
  const snapshot = await db.collection('users').doc(uid).collection('devices').get();
  return snapshot.docs.map((doc) => doc.data().fcmToken).filter(Boolean);
}
async function sendToUser(uid, notification, data) {
  const tokens = await tokensFor(uid);
  if (!tokens.length) return;
  await admin.messaging().sendEachForMulticast({ tokens, notification, data });
}

exports.notifyConnectionRequest = onDocumentCreated('connectionRequests/{requestId}', async (event) => {
  const request = event.data?.data();
  if (!request || request.status !== 'pending') return;
  await sendToUser(request.toUid, {
    title: 'New connection request',
    body: `${request.fromDisplayName || request.fromUsername || 'Someone'} wants to connect with you.`,
  }, { type: 'connection_request', requestId: event.params.requestId });
});

exports.notifyMoment = onDocumentUpdated('pairs/{pairId}/moments/{momentId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after || after.status !== 'ready' || before?.status === 'ready') return;
  const pair = (await db.collection('pairs').doc(event.params.pairId).get()).data();
  const recipient = (pair?.memberUids || []).find((uid) => uid !== after.senderUid);
  if (!recipient) return;
  await sendToUser(recipient, {
    title: 'New moment from your partner',
    body: after.caption || 'Your partner shared a photo with you.',
  }, { type: 'moment', pairId: event.params.pairId, momentId: event.params.momentId });
});
