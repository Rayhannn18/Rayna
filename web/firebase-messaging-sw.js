/* Firebase Cloud Messaging service worker for Closer (web).
 *
 * Only used when a Web Push VAPID key is configured in
 * lib/core/notifications/notification_config.dart and the app requests a token.
 */
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBiSlcq4AIVaxBjVuflWJ2YPYJBRo9i-3M',
  appId: '1:716123903575:web:33ba30d5757833ff5ef512',
  messagingSenderId: '716123903575',
  projectId: 'closer-3e8d7',
  authDomain: 'closer-3e8d7.firebaseapp.com',
  storageBucket: 'closer-3e8d7.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'Closer';
  const options = {
    body: notification.body || 'You have a new update from your partner.',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(title, options);
});
