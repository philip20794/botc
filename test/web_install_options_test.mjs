import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import vm from 'node:vm';

const projectRoot = path.resolve(import.meta.dirname, '..');
const source = fs.readFileSync(
  path.join(projectRoot, 'web/install-options.js'),
  'utf8',
);
const markup = fs.readFileSync(
  path.join(projectRoot, 'web/index.html'),
  'utf8',
);

function makeElement() {
  const listeners = new Map();
  return {
    listeners,
    open: false,
    href: '',
    addEventListener(type, callback) {
      listeners.set(type, callback);
    },
    showModal() {
      this.open = true;
    },
    close() {
      this.open = false;
    },
    click() {
      return listeners.get('click')?.();
    },
  };
}

function mount({ android = true, standalone = false } = {}) {
  const store = new Map();
  const listeners = new Map();
  const elements = new Map([
    ['botc-install-options', makeElement()],
    ['botc-install-pwa', makeElement()],
    ['botc-install-apk', makeElement()],
    ['botc-install-later', makeElement()],
  ]);
  const window = {
    addEventListener(type, callback) {
      listeners.set(type, callback);
    },
    matchMedia() {
      return { matches: standalone };
    },
  };
  const navigator = {
    userAgent: android ? 'Chrome Android' : 'Chrome Windows',
  };
  const sessionStorage = {
    setItem(key, value) {
      store.set(key, value);
    },
    getItem(key) {
      return store.get(key) ?? null;
    },
  };
  const document = {
    getElementById(id) {
      return elements.get(id) ?? null;
    },
  };

  vm.runInNewContext(source, {
    window,
    navigator,
    document,
    sessionStorage,
  });

  return { listeners, elements, store };
}

test('PWA manifest references both sizes and maskable launcher icons', () => {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(projectRoot, 'web/manifest.json'), 'utf8'),
  );
  assert.equal(manifest.short_name, 'BOTC');
  assert.deepEqual(
    manifest.icons.map((icon) => [icon.sizes, icon.purpose]),
    [['192x192', 'any'], ['512x512', 'any'], ['192x192', 'maskable'], ['512x512', 'maskable']],
  );
  for (const icon of manifest.icons) {
    assert.ok(fs.existsSync(path.join(projectRoot, 'web', icon.src)),
      `Missing install icon: ${icon.src}`);
  }
  assert.match(markup, /icons\/Icon-192\.png/);
});

test('Android offers PWA prompt and published APK as distinct choices', async () => {
  const { listeners, elements } = mount();
  let pwaOpened = 0;
  let defaultSuppressed = false;
  listeners.get('beforeinstallprompt')({
    preventDefault() {
      defaultSuppressed = true;
    },
    async prompt() {
      pwaOpened++;
    },
  });

  assert.equal(defaultSuppressed, true);
  assert.equal(elements.get('botc-install-options').open, true);
  assert.match(elements.get('botc-install-apk').href,
    /^https:\/\/github\.com\/philip20794\/botc\/releases\/download\/android-latest\/b-o-t-c\.apk$/);

  await elements.get('botc-install-pwa').click();
  assert.equal(pwaOpened, 1);
  assert.equal(elements.get('botc-install-options').open, false);
});

test('choosing APK or later dismisses without triggering PWA', () => {
  const { listeners, elements, store } = mount();
  listeners.get('beforeinstallprompt')({
    preventDefault() {},
    prompt() {
      throw new Error('Native PWA prompt must not open');
    },
  });
  elements.get('botc-install-apk').click();
  assert.equal(elements.get('botc-install-options').open, false);
  assert.equal(store.get('botc-install-options-dismissed-v1'), '1');
});

test('regular desktop browser and standalone installs are not interrupted', () => {
  for (const options of [{ android: false }, { standalone: true }]) {
    const { listeners, elements } = mount(options);
    assert.equal(listeners.has('beforeinstallprompt'), false);
    assert.equal(elements.get('botc-install-options').open, false);
  }
});
