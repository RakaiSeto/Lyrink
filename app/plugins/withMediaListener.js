const { withAndroidManifest } = require('expo/config-plugins');

const YT_MUSIC_PACKAGE = 'com.google.android.apps.youtube.music';

function permissionExists(manifest, name) {
  return manifest?.manifest?.['uses-permission']?.some(
    (p) => p.$['android:name'] === name
  );
}

function addPermission(manifest, name) {
  if (!manifest?.manifest) return;
  if (permissionExists(manifest, name)) return;

  if (!manifest.manifest['uses-permission']) {
    manifest.manifest['uses-permission'] = [];
  }
  manifest.manifest['uses-permission'].push({
    $: { 'android:name': name },
  });
}

function serviceExists(application, name) {
  return application.service?.some((s) => s.$['android:name'] === name);
}

function addMediaListenerServiceToManifest(androidManifest) {
  if (!androidManifest?.manifest?.application?.[0]) {
    return androidManifest;
  }

  const manifest = androidManifest.manifest;
  const application = manifest.application[0];

  // Add required permissions
  addPermission(androidManifest, 'android.permission.FOREGROUND_SERVICE');
  addPermission(androidManifest, 'android.permission.POST_NOTIFICATIONS');

  // Add NotificationListenerService (existing)
  if (!serviceExists(application, 'expo.modules.medialistener.MediaNotificationListenerService')) {
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
  }

  // Add ForegroundService (new)
  if (!serviceExists(application, 'expo.modules.medialistener.LyrinkForegroundService')) {
    const foregroundService = {
      $: {
        'android:name': 'expo.modules.medialistener.LyrinkForegroundService',
        'android:exported': 'false',
        'android:foregroundServiceType': 'dataSync',
        'android:stopWithTask': 'false',
      },
    };

    if (!application.service) {
      application.service = [];
    }
    application.service.push(foregroundService);
  }

  return androidManifest;
}

module.exports = function withMediaListener(config) {
  config = withAndroidManifest(config, (config) => {
    config.modResults = addMediaListenerServiceToManifest(config.modResults);
    return config;
  });
  return config;
};
