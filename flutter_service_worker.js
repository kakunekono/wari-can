'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"manifest.json": "663c832af2760b21a6929420f4f7f195",
"flutter_bootstrap.js": "d9a349195fccf4eea4eaff6e89b73edf",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/config": "0ca3dbbc8c3bc88938b866372dd33083",
".git/refs/remotes/origin/master": "f7e55cd93f61834788ea099428e22853",
".git/refs/remotes/origin/gh-pages": "3b4ac44eeec32b2877e42532e413ce3b",
".git/refs/heads/gh-pages": "3b4ac44eeec32b2877e42532e413ce3b",
".git/index": "a236e461c1a2d1de7c8452aa5a7f5bc5",
".git/FETCH_HEAD": "92250e5f0187af05d78e9a1b56d9ca76",
".git/objects/6b/a33a4315fbe3a9d69692fa596e011f5dacba88": "e7843bb912c416c1b7795e710ae774d5",
".git/objects/e4/2aaa3f9d706db64890b334687c0cac33d76b38": "9a299a75802efb2f194337fe6ceedb4a",
".git/objects/e4/337d7b548e369435c8bf7ff127ba24a1c9365d": "40d419e85a6a079f6675d62aa9c554d1",
".git/objects/54/4eb2ebed2b29c04e4c61ce1a57dfefa95b046e": "c301c454154a9e0a59077901712f8c85",
".git/objects/05/4dba08819627d06a2c0680872eef8659552956": "afe5e487908188512a78e1ff95261d92",
".git/objects/2f/e85e42672621bd2539b75fa1c3285321020349": "4f826b07cf39ac551a84239f6eb3aa90",
".git/objects/2f/1b17cbfd06d1d9511be69096dbc881807c514c": "c4d0f003350e6b3b9da7963818ab87b3",
".git/objects/2f/c70545277f8dc9ad2a66385da7fbe95139988d": "a2386340396f74d9644d1684e82fc306",
".git/objects/02/0da6e0b1af10493a1a3d12bb3a1021d0d22612": "61d53697b6386298d3ee1daf6e434061",
".git/objects/1c/4c010b6c99a35acfbfb2d3651d984f95cf559a": "259c50e7ca3282d77be03d8aab3adcec",
".git/objects/30/897a422b55a76c91bbf652e1c59bd447e06975": "376fed3bfc717ac449768084cb130c1e",
".git/objects/0c/e6f391d73c5b0108b03de9e776dd68c42fb2b1": "c9b76a7e9c4b9892d004eb80559b1434",
".git/objects/08/43648c6a505d6bf243bc0d2bf1d2c4d3407068": "4308147ae95cb36740fa1ad54bc4413d",
".git/objects/d0/d692a66b82ad26f4eb8e2ed34b6a9260b2215c": "ac28a8618c5104862daceafe3f1c3b98",
".git/objects/d0/d8b8fbc75db280394142961438c132441fcc4c": "64416fccd15553cf557c72813f132006",
".git/objects/af/2f987558dfcf7867794abd68d9782db8e16b41": "35ad441c255aa2447533b6cdc7b5f6d3",
".git/objects/39/c2560f5aac94aa20bf840edaa2535406bb0b21": "51cf24d389ca7f79c65898256c28bee4",
".git/objects/96/a46a2ea373b918ab3b02bf3543bb399ba8f1b1": "4dd1563fe0d694927559e60c20c0839c",
".git/objects/96/59144ce496713ff07ac0b315389bb638c1d548": "32994e717ae3e64ca859397a70b71250",
".git/objects/82/b5b54f3320b5982c4765654ddf99413f4fe5a2": "94b6a55392ac0e21fc23729781587525",
".git/objects/0f/6697f64a702f4bc40e2f2de5c7d358f908d224": "ab67d64a04803671aa1243e3fd71b19c",
".git/objects/d5/80ce749ea55b12b92f5db7747290419c975070": "8b0329dbc6565154a5434e6a0f898fdb",
".git/objects/e3/33ec91a8178ef2b96dc4745695a457a20d7b92": "e27814d6b82761bdc9183ba06bd50739",
".git/objects/06/b447618374bdac54da678c7de4ff68d43fe932": "929b9c29d6e8051a3e3dbc5b45c9b023",
".git/objects/76/0ff6af40e4946e3b2734c0e69a6e186ab4d8f4": "009b8f1268bb6c384d233bd88764e6f8",
".git/objects/66/5b5967178e18225cc9b83bea5e86c8e5d381e1": "f3a0376611e72adb782cb62afc2b8f04",
".git/objects/46/ffb2af3df311abb58fd9bf6fe949c7c02cff08": "31007f64e11c1e1919fe4f7552087aa6",
".git/objects/60/eb7d42e07292e827eca7e9b177907d841ab492": "e6bcf978f5a3f0696531e154a29584f2",
".git/objects/60/c74220f504e4cd7970986da25927f6065bf2c3": "81b47a4b98d025865ae21d5fca55a059",
".git/objects/40/7356cd3e3c072900be86b8306b740f0728b1a7": "2d976f3ff695af2f5e3865c72f742326",
".git/objects/40/c20f9c3cbe58ae2bb502be46b5bf8f7a5e7c68": "0e9e2cc331651adfd4a605c243a3f4e2",
".git/objects/a5/9f4583bec67666f15fb7ede53ebd862bb9781c": "a4c995d79ddedc5cc43b2362a6aea6aa",
".git/objects/a5/87735aca94dce5797f07cd21ab9a4c1f16fe57": "ae59e33e3df520023fb4f415b82e9e6f",
".git/objects/fa/956eb7f643c89b6e0f6dc48f69a2b61401010c": "a01135955e199817cd81c6a216733d5f",
".git/objects/21/d29aa520a50b70d5f0e1c918e9ab09ca8e7819": "0c215afd5d0ec4696ad62048edd27df2",
".git/objects/98/6da52544196780c1ca250e253cedb3dd61882e": "c58f9570c536f71e8f9a925b7e8c9735",
".git/objects/98/7c9fbe533a97fc8574ea8e0fa20e5dfb0507f5": "2f19c737a05a9099f53834732c6fdcf8",
".git/objects/43/5d22dfcdb747c5839618dd5914f4037abf62f5": "474379f14ab14f5470c66cb94af402e4",
".git/objects/9e/31dad5fa3e8db2881ba8895403b1c59ea10f24": "5de5d1d1a206bb501897c3755ed0da6b",
".git/objects/9e/af39c7a5289ec975ffc8dc0e87b3f2502cc3b1": "45df22d1c3e558f2fb447e6b83027813",
".git/objects/80/dacb0dc62d941cc218aa4c3945e76aed005009": "a37fb493a5032ddccce7a64ba85194c6",
".git/objects/73/5c9157edfd463764e8f24c4f2cdb44afb42bca": "b7ae908374721ca1b834296cf281ab27",
".git/objects/92/eab450609b7dc5d076ddf6c8416de8209373e0": "9b3d4cb7f5916a87f36a18b466ea7ac4",
".git/objects/92/2516466892e048cf9a756d91d9dab079c60db3": "ec0ddd51a25ccc2bddbbbfabe06c9138",
".git/objects/99/50bac6044f9fb5b5e651f88d5920001432461a": "af6ddd041e09256afdb29ad9dac7800f",
".git/objects/f6/3c396ff8966302835729107b443ba69e29a0aa": "1b29d3d161557705a31e4de41fd2557f",
".git/objects/f6/30514b7b14b6771fd0bc3321c554ea940245ae": "d993ab1cb6ed8c9b7cacc1f7f5840061",
".git/objects/f6/aaa871c87614531ea7e510b70c099ef1380863": "cf9c8fa30aa3f880209f66df01cf87c7",
".git/objects/45/a4011c3d8eb0beca810df48ed39c4d22694975": "6a16ccffb8e72433fa292d4f74262812",
".git/objects/45/38b22a905a62e24354b2f75dcd7f66951e3771": "b43c684f24b3e0fdd1cdc90469de9423",
".git/objects/45/f5a826a4acfbf96181052d9a61b67a4ebfafa4": "0fafc37e769cc652ffc2178999fbe847",
".git/objects/a0/0fc42e83b13d09bf33c70ff20795efd1f85912": "203f9fe29fb4d669cd81c7968630c283",
".git/objects/fd/9b4a10fd644968ca6c571c7908671e950ff71b": "8baa6655ab7ec12a53bde0d398d05178",
".git/objects/ef/f21a390e32a24a76f4be064939343971982a5b": "3dd47d9912b13968c96e16e64de3764a",
".git/objects/3c/59ad5cbd15327710a25a007a690f6a41014f42": "b3e4e986ea7b72ba88217992cc7d9955",
".git/objects/15/5b4bd2e09b8956397c640a1a5285ef385e8a53": "f464715ee4a6bc0ce42d4702977349c1",
".git/objects/d6/391c39a690cfec015359b9811689ac6f0f641d": "2541fd64b6e4fdbe887595acb9a07e67",
".git/objects/ee/fefee6349b9c13bec891f3da4c389e27303fb1": "30831b0497385272e6c979e64a5f7d5b",
".git/objects/d4/50841abde1a4afe5d5ad520200f5c9a2a8d6d0": "060df140f2b54e7059663e3b2757b4ea",
".git/objects/d4/cd8a820bc8985c3db296fb8b286d7bc8ff3951": "eb230c6b113a697cc2c8d854f5cedc95",
".git/objects/c2/f278651d7d17eaa92ebf7edbc709b8693967d9": "a3d6be929e402e7dbb7a8390caebd7f4",
".git/objects/ec/5c7a5cd888fa37a64a738ab81f77cc7f2fa9bf": "923b21fa6362e81e9c2bb4008e755183",
".git/objects/ec/d0bdb199e12941938f5c87d62a7fe5764403ae": "754874a21ca5babbc2be788c96390bc1",
".git/objects/ec/bc567faeb7fa1a7b46733dc277430244326107": "d24aed34628bcb743b6f314eb54fc0f7",
".git/objects/b5/66dec6f45d86060b952f4c42ab687c42e6e4a1": "c205a2c7555529096b90ce0578ddd858",
".git/objects/b5/aa0903a4427fc78a564f280a2ee3b14d57d713": "d63ecdd1d0b34babc0006eee0924284b",
".git/objects/b5/bd4e8e686e1d79c9cefeb247078edf0b6daf82": "a1b77beaf422b6127a32619137885f30",
".git/objects/41/5c059c8094b888b0159fdedfd4e3cb08a8028e": "86914685ccd40e82a7fe5b70459fb9f7",
".git/objects/26/5890d04c385c70ad2f6e3d9d2619205c158119": "3983bedfea7cefd112abf3effcf2aa4a",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.pack": "6a9914bedb976f7f15356b0382dc35d2",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.idx": "9ad3e69f5583fed02e9128c8aa8eba66",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.rev": "b7f28e1b599664803c8d58bf785401c4",
".git/objects/68/1f6449cd016592c9e87920f92637713bb4ac0d": "5f5b1435d8f2528bec580b4e9c81b86f",
".git/objects/87/1555952c551b5d09b05ea09bd6fb1ae0e714f6": "67f5e99d2a1d502e7669ef77646d6d19",
".git/objects/6d/be9edd65411b76d1d0e83613c9138f0dc7ab12": "f42095df7a2d8393c56d61bba2eb4d38",
".git/objects/0d/28079ce73200f58142fe85fddc3d56e943c356": "f9c460172946ba95fea5f44e96791ed5",
".git/objects/ae/0ee8fd64a47f73f53455690ce77facd2b4b7e3": "2f5c41691247c02305c7d51da287d663",
".git/objects/a3/ce7c25b3700e422acde95da4fe07dab36743db": "0d3e589c0f17b5f01a6d8b41e9be991b",
".git/objects/13/437b8c4e41c95a6aa58dd4b15f58f73a478bdd": "59c518258d4742b45dfa2ea7c0ce1a66",
".git/objects/f5/f8e292e528510478bc60d0dc0f65f0d783bb9d": "2842a817d8c48618cb6c7c5644bfacd2",
".git/objects/b9/80c93a1eaebb589772f7173ad4ebac71bdefb0": "1d2db901e9b3f4c9de7e6bd34ee2d8df",
".git/objects/6e/23c3abb8751178786394025b9e54de7e5f6f80": "e753107de7c77e54a0ee4df67742f00d",
".git/objects/3e/8f3e13b81ad1999de240b80c498603eaaf1d76": "2a7e9932b75707a9c14fe51c0989892b",
".git/objects/5d/c44f215885b636bfa06225737474469b57d70a": "bd76adb8f5ffaf5dbaa98c0e8a1b0029",
".git/objects/d3/3df747a4c26d017f26e5cd250703c18fc52b14": "ac6d9e1afde0b59f68acc92078f30ac4",
".git/objects/3f/599538240f31e78489a2d1992e67d96aaff927": "bff5aa31f7269c96a6bc2f7120df6ff5",
".git/objects/3f/7134af7ad95352b1bd19e6633f3fa81380ea8c": "b8a033915e02c792a6af98007ad01aa3",
".git/objects/ad/4c0ba9842f4de544316a62269732d33f652961": "d2648c4f7ac6a01d24dedabffef3980b",
".git/objects/97/1a4ec28cfd587e97d3c08dc03829ce8395ab1b": "115090257dca116c158ea98e9504381f",
".git/objects/58/16dba5ddc8af0a07ba2750b918714b700eb660": "6459935fa9db1bf1df8c78d6e45b9045",
".git/objects/58/182427344dec75b4f8f9772fa9d0b070bb4a5d": "6d8dc7a0e322aea78fa8e76fd85562d0",
".git/objects/c1/25f71fa83c44f10a3710b1d7a832609162252f": "7c35f97fe1ee1fe239049aba596fa28d",
".git/objects/42/9f32d01b642a270fc40ddcc71180b3e4721675": "50c28c02eb662d0a2545fe3ee7e7d82a",
".git/objects/4b/903f62790d2276f11df6b6ba0ed6381482cc6f": "f5aa8cdec31c4587d2ba21a5857eb2e1",
".git/objects/4b/8badb641ab515d852cd151c6814b8aec7f5262": "bd2abdacc2f530d73d8cad8aa82d829b",
".git/objects/4b/cdad397aa557f80923c990c530acb79b7d3f25": "59b5597b8b5e25c456851cf5131f6208",
".git/objects/65/60a02bb6588b6c50cca044e4fb9ffb8bec608e": "b55f1e5bd026732722274f78f914477f",
".git/objects/dc/81c2082f4bb5f4c4d38b57f80741d3275e8ef7": "a876c2a08570bedfe8f0d4cbf78c2e41",
".git/objects/7c/d96cec6923072f0c3eab872f7a96a126b9b7bc": "fdcdeba208fc6163379d42a79c875f3f",
".git/objects/4a/47caf6ef3aa63303d7e3a677f4642f2db094fc": "434f4d2a5ae3db042277ee9653a620ea",
".git/objects/ba/86250ae8a64cf64097337a308fcac7d99ce61a": "139db4f1060457b728607cbe70f8230c",
".git/objects/20/28c5e4e3e6252aaeb393a529b6de572a26a1fd": "2f4e5daefe7dae004e34eb2e803c49a9",
".git/objects/12/ef842e96531ca3d1e34e9cfa64ebedf90d78c2": "20f632c097b3cf0d08bc9f9566b84060",
".git/objects/bc/70c1d467413a827e749077ad0ace43432b3fde": "54cdd97e033d7a27744642c2c7c97346",
".git/objects/2c/7a96b316ce7812e528a2b5b9c1dc81a8ec7ce3": "300f29be56d2e42e553b5ea7aaf46e1f",
".git/objects/2c/8b3db2ed12077581b2be1e897731776560cb96": "1504822fd426e0c23fa0c102d06264b6",
".git/objects/e9/be8311bc34ca779a70f9393bed586680687c7f": "5b9e59f9dd1380af50f91c9f6f232372",
".git/objects/e9/bd2d8cf9959ffe90591acca1b3263dd3d529b5": "d0827ff4fea56305d05f4d4551f62f96",
".git/objects/67/e1beca6032573973feb9df50812c15d0999da5": "3f0d7601441c0aead892d5304b30a946",
".git/objects/14/509c65562777126afd5ef5cdcff2df85a0ca7c": "71f99e28929468713d280712c3325ab8",
".git/objects/77/a13b798708c6ccff7d267863854c02b2647b4f": "1d6ce3658b952672caedd79271071b77",
".git/objects/8b/f6b157f46af2f2af92ad52bade706324a90eaa": "af49db3d3f7587cf73c5faef0c8f8e8b",
".git/objects/8b/ca5c9fb4ff8f9886fca4451ffba908fe9162d0": "51e2ba6d592caf37fad85e4be6b2937a",
".git/objects/de/9658c4d4305d7c38903f2fa9ec11871c312941": "f69304397228ddee555d6f60b5e15cee",
".git/objects/9b/5a7e346d16542ac343f1ab5859577b69d59399": "e2353f38aa253fff7f38998bb4d5acee",
".git/objects/8a/85cb0846c90ef6aee76039f831203c201a3a2b": "038e60d2c1ee3b28815d274578da6a41",
".git/objects/8c/99266130a89547b4344f47e08aacad473b14e0": "41375232ceba14f47b99f9d83708cb79",
".git/objects/19/48a1d387a7e0a64c7fd9a770845502f7638394": "3e93777d6dd24af1f2e27a0ebcce9ee4",
".git/objects/4e/121052b9911027fb4c854205f93759e472a80c": "ee5c21bc032364f82e6471e790f9e27a",
".git/objects/4e/204be50e383a8e95d8093b304457e92d5041b5": "9f725ea3c07dfbd5afedb2515c7b02f5",
".git/objects/4e/afa19433361f0da88f675e640389041371ea88": "32447dd8eddd6a9b6225f89f7113710a",
".git/objects/ac/77ada1bd5cb9efdabc57a951c939d09df21439": "4d45aedc6c1e92cf221df59f8ab95308",
".git/objects/f2/ef19be167878f656c44c67fe7b8d683d802e40": "b576963cb799401ee699f493cf957741",
".git/objects/f2/a8a9b5eca9b021a2f2f68fea4238d2025ee114": "244f0177d6ba56f4289e9d7cf68bd6ad",
".git/objects/f8/7790c41dcaadcaa9534aceeb0710b374977e62": "6e938b8b038092b770f424467ac44acc",
".git/objects/91/f92c51be68a891122aa02e9b28e0655099d13a": "651a958781d387701d4751315b6cd97c",
".git/objects/28/e9f4e91f6a877cefd69cbbde1d719a6ae54ed9": "2a7b7d5d7abe0e96153f6404f78bdec8",
".git/objects/28/22cedb29bd0fe2d77661b4fe38f6841569887b": "6c25256d9de585cac170d832406de9a1",
".git/objects/93/96daff2ffc885cfa8f99af9641b23a696ae047": "328eae17992ea733c18cd27f806e8103",
".git/objects/23/69be3a7edd5dae3e96b850dcd367ba86383d1d": "01c99d12706f448392f2fcb4fb92c7b5",
".git/objects/23/df0c1681f32196a9fc6c4ef6ea682239ee2fb3": "340b66defede0caee8a3192ae4bc06d8",
".git/objects/23/1f26281f286c0b9397000a12cde1d843ccfd07": "b109322e5ef59ba3eea5a6a3de9553ff",
".git/objects/47/e63e2f94281313e92f7280b487df2e1243b235": "85bf3a4edbdd7511cba82eff4d17ac90",
".git/objects/24/55fdfaaaa9b2080e85f616a5029196011882a6": "be76ad1b50e8fbf4ad107a142f8aa798",
".git/objects/24/1a28f34e3d2fbde2ac841e31283d8d1b44dc6f": "9bc87bee0a1f6514bd610fb7dfadf555",
".git/objects/75/1aeb24edfa4a8f080b680589a22f9d79285f1f": "1661301fe4eae56aded31cb8d6717b50",
".git/objects/5a/3fa91c666897d31d41beafae6db24ffa49084a": "3704d3910364cc489a95aae4ff9deae9",
".git/objects/49/474a1d75e809af86449dbf5d1cfc39e197791c": "3a9d829adf36f8e0a8ea301359fef6c7",
".git/objects/ff/d213695941cc34f600905f3b0da2a33a3d7984": "be95ffd8eb06f5ab7f61fe147cd5f538",
".git/objects/ff/31e21a45754362d60eca442dfcd28e674fb3b0": "f140bf137a281e85eb4ac962f7fa7bf4",
".git/objects/ff/668e6ee9badc5c2820eaaaf19ea90f67ad0e62": "d5bd9d450fec88f1330ca1d833142b5c",
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
".git/COMMIT_EDITMSG": "de8b45fe4c11548cc73bc1a18acaeec3",
".git/logs/refs/remotes/origin/master": "65df66ad064f92f52dece63fa83fb0f9",
".git/logs/refs/remotes/origin/gh-pages": "7c7b32aecde017ddde5f8902a7fe261b",
".git/logs/refs/heads/gh-pages": "acf34deebc0d3265125ce5115dc65d76",
".git/logs/HEAD": "bb9e62da0963f2609269973de6a6daf7",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"README.md": "4f3da60ddb70e8644b2f11a40879dc6a",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"main.dart.js": "b09743d0e5435fdb3adad9fb818fc18b",
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
"index.html": "878bc582abd7e52baa7ada8895046b1b",
"/": "878bc582abd7e52baa7ada8895046b1b",
"assets/AssetManifest.json": "2efbb41d7877d10aac9d091f58ccd7b9",
"assets/NOTICES": "6d3a0c7fb90e01bee37f5d54ce452695",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "b93248a553f9e8bc17f1065929d5934b",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "693635b5258fe5f1cda720cf224f158c",
"assets/AssetManifest.bin.json": "69a99f98c8b1fb8111c5fb961769fcd8",
"assets/fonts/MaterialIcons-Regular.otf": "e7069dfd19b331be16bed984668fe080",
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
