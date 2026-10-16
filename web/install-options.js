// Android browsers can offer either the installed PWA or the signed APK.
// Chrome's beforeinstallprompt is non-standard, so this is an enhancement:
// other browsers keep their native install options.
(() => {
  'use strict';

  const apkUrl =
    'https://github.com/philip20794/botc/releases/download/android-latest/b-o-t-c.apk';
  const dismissedKey = 'botc-install-options-dismissed-v1';
  const isAndroid = /Android/i.test(navigator.userAgent);
  const isStandalone =
    window.matchMedia('(display-mode: standalone)').matches ||
    navigator.standalone === true;

  if (!isAndroid || isStandalone) return;

  let pendingPrompt = null;
  const installDialog = document.getElementById('botc-install-options');
  const installPwa = document.getElementById('botc-install-pwa');
  const installApk = document.getElementById('botc-install-apk');
  const dismissButton = document.getElementById('botc-install-later');
  if (!installDialog || !installPwa || !installApk || !dismissButton) return;

  installApk.href = apkUrl;
  installApk.addEventListener('click', dismiss);

  function dismiss() {
    sessionStorage.setItem(dismissedKey, '1');
    if (installDialog.open) installDialog.close();
  }

  dismissButton.addEventListener('click', dismiss);
  installDialog.addEventListener('cancel', dismiss);
  window.addEventListener('appinstalled', dismiss);

  installPwa.addEventListener('click', async () => {
    const prompt = pendingPrompt;
    if (!prompt) return;
    pendingPrompt = null;
    dismiss();
    // Must happen synchronously in a direct button-click handler.
    try {
      await prompt.prompt();
    } catch (_) {
      // The browser's menu remains available if its one-shot prompt fails.
    }
  });

  window.addEventListener('beforeinstallprompt', (event) => {
    if (sessionStorage.getItem(dismissedKey) === '1') return;
    // Replace Chrome's generic PWA prompt with a choice between PWA and APK.
    event.preventDefault();
    pendingPrompt = event;
    if (!installDialog.open) installDialog.showModal();
  });
})();
