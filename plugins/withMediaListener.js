const { withAndroidManifest } = require('expo/config-plugins');

const YT_MUSIC_PACKAGE = 'com.google.android.apps.youtube.music';

function addMediaListenerServiceToManifest(androidManifest) {
  if (!androidManifest?.manifest?.application?.[0]) {
    return androidManifest;
  }

  const application = androidManifest.manifest.application[0];

  const serviceExists = application.service?.some(
    (service) =>
      service.$['android:name'] ===
      '.MediaNotificationListenerService'
  );

  if (serviceExists) {
    return androidManifest;
  }

  const mediaListenerService = {
    $: {
      'android:name': 'expo.modules.medialistener.MediaNotificationListenerService',
      'android:permission': 'android.permission.BIND_NOTIFICATION_LISTENER_SERVICE',
      'android:exported': 'true',
    },
    'intent-filter': [
      {
        action: [
          {
            $: {
              'android:name':
                'android.service.notification.NotificationListenerService',
            },
          },
        ],
      },
    ],
  };

  if (!application.service) {
    application.service = [];
  }
  application.service.push(mediaListenerService);

  return androidManifest;
}

module.exports = function withMediaListener(config) {
  config = withAndroidManifest(config, (config) => {
    config.modResults = addMediaListenerServiceToManifest(config.modResults);
    return config;
  });
  return config;
};
