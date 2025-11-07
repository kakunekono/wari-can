'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"manifest.json": "663c832af2760b21a6929420f4f7f195",
"flutter_bootstrap.js": "95aac2002f51cac4dc80f650e0854e0d",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/config": "0ca3dbbc8c3bc88938b866372dd33083",
".git/refs/remotes/origin/master": "f7e55cd93f61834788ea099428e22853",
".git/refs/remotes/origin/gh-pages": "438307c37151e966a9b39587b1938187",
".git/refs/heads/gh-pages": "438307c37151e966a9b39587b1938187",
".git/index": "e19870dd32417a8711b324a51e8f1dd1",
".git/FETCH_HEAD": "92250e5f0187af05d78e9a1b56d9ca76",
".git/objects/05/4dba08819627d06a2c0680872eef8659552956": "afe5e487908188512a78e1ff95261d92",
".git/objects/1c/4c010b6c99a35acfbfb2d3651d984f95cf559a": "259c50e7ca3282d77be03d8aab3adcec",
".git/objects/0c/e6f391d73c5b0108b03de9e776dd68c42fb2b1": "c9b76a7e9c4b9892d004eb80559b1434",
".git/objects/08/43648c6a505d6bf243bc0d2bf1d2c4d3407068": "4308147ae95cb36740fa1ad54bc4413d",
".git/objects/39/c2560f5aac94aa20bf840edaa2535406bb0b21": "51cf24d389ca7f79c65898256c28bee4",
".git/objects/98/7c9fbe533a97fc8574ea8e0fa20e5dfb0507f5": "2f19c737a05a9099f53834732c6fdcf8",
".git/objects/73/5c9157edfd463764e8f24c4f2cdb44afb42bca": "b7ae908374721ca1b834296cf281ab27",
".git/objects/45/38b22a905a62e24354b2f75dcd7f66951e3771": "b43c684f24b3e0fdd1cdc90469de9423",
".git/objects/d4/50841abde1a4afe5d5ad520200f5c9a2a8d6d0": "060df140f2b54e7059663e3b2757b4ea",
".git/objects/c2/f278651d7d17eaa92ebf7edbc709b8693967d9": "a3d6be929e402e7dbb7a8390caebd7f4",
".git/objects/26/5890d04c385c70ad2f6e3d9d2619205c158119": "3983bedfea7cefd112abf3effcf2aa4a",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.pack": "6a9914bedb976f7f15356b0382dc35d2",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.idx": "9ad3e69f5583fed02e9128c8aa8eba66",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.rev": "b7f28e1b599664803c8d58bf785401c4",
".git/objects/12/ef842e96531ca3d1e34e9cfa64ebedf90d78c2": "20f632c097b3cf0d08bc9f9566b84060",
".git/objects/77/a13b798708c6ccff7d267863854c02b2647b4f": "1d6ce3658b952672caedd79271071b77",
".git/objects/9b/5a7e346d16542ac343f1ab5859577b69d59399": "e2353f38aa253fff7f38998bb4d5acee",
".git/objects/f2/a8a9b5eca9b021a2f2f68fea4238d2025ee114": "244f0177d6ba56f4289e9d7cf68bd6ad",
".git/objects/28/e9f4e91f6a877cefd69cbbde1d719a6ae54ed9": "2a7b7d5d7abe0e96153f6404f78bdec8",
".git/objects/47/e63e2f94281313e92f7280b487df2e1243b235": "85bf3a4edbdd7511cba82eff4d17ac90",
".git/objects/75/1aeb24edfa4a8f080b680589a22f9d79285f1f": "1661301fe4eae56aded31cb8d6717b50",
".git/objects/7a/43bfb70e904b086b0f1078c17751f630321ab4": "a7d8d79482441b8e16db9e62727d16f7",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/pre-commit.sample": "305eadbbcd6f6d2567e033ad12aabbc4",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/COMMIT_EDITMSG": "45c9eb7fa6e6a781268f8a3b8d62d8b9",
".git/logs/refs/remotes/origin/master": "65df66ad064f92f52dece63fa83fb0f9",
".git/logs/refs/remotes/origin/gh-pages": "a0a06404a04a6ec516165a53ff2aaf4a",
".git/logs/refs/heads/gh-pages": "8e814f0258079e6bb473b8c51e844bef",
".git/logs/HEAD": "cc4ce1bea8708b17effeec0dc9f8ea10",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"README.md": "4f3da60ddb70e8644b2f11a40879dc6a",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"main.dart.js": "ea4ea6c048ac8abe9af7f815d48efec1",
"version.json": "f51e914292b53a2d04f665d8acd96bec",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"index.html": "f1454d5f36a4a04843c92a8789660968",
"/": "f1454d5f36a4a04843c92a8789660968",
"assets/AssetManifest.json": "2efbb41d7877d10aac9d091f58ccd7b9",
"assets/NOTICES": "45ba4e8e13be14fa6f4b2385e0b947ea",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "693635b5258fe5f1cda720cf224f158c",
"assets/AssetManifest.bin.json": "69a99f98c8b1fb8111c5fb961769fcd8",
"assets/fonts/MaterialIcons-Regular.otf": "dc272961f6738d0c460af99876699a7e",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
