'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"manifest.json": "663c832af2760b21a6929420f4f7f195",
"flutter_bootstrap.js": "d4dcb4c66c13d3e1d85a55019761fed8",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/ORIG_HEAD": "68623502dbee38dc77f7c7da2db87ad0",
".git/REBASE_HEAD": "eb27a7030cd08bfeabd5588a6d2510c5",
".git/config": "558ac7a17db4c70b16b2257487696902",
".git/refs/remotes/origin/feature/cloud": "69bb5298e1f3d8012783e81d44bfc55a",
".git/refs/remotes/origin/master": "a424077183b56fc9deaebd7482cd537f",
".git/refs/remotes/origin/gh-pages": "e697f09efb83762f424ebcbbd117b0e7",
".git/refs/heads/gh-pages": "e697f09efb83762f424ebcbbd117b0e7",
".git/index": "ea7cc9297c923235f9433be377021dcd",
".git/FETCH_HEAD": "729f863b9dc42f449e0cd729aa34d8d7",
".git/objects/6b/a33a4315fbe3a9d69692fa596e011f5dacba88": "e7843bb912c416c1b7795e710ae774d5",
".git/objects/e4/2aaa3f9d706db64890b334687c0cac33d76b38": "9a299a75802efb2f194337fe6ceedb4a",
".git/objects/e4/337d7b548e369435c8bf7ff127ba24a1c9365d": "40d419e85a6a079f6675d62aa9c554d1",
".git/objects/54/4eb2ebed2b29c04e4c61ce1a57dfefa95b046e": "c301c454154a9e0a59077901712f8c85",
".git/objects/54/c86959505e107f6374b3730425bb6f0b2fba65": "b04adf671a4e373e874c43d9c5eb2336",
".git/objects/54/73029458f37d5839c52de56cbdf531f02f8dc5": "fdeb8d965d1afdc2f9a50f2f3e1ea7eb",
".git/objects/5e/baa6b993d4cdd63925fd30f18992933f35470b": "7ff3da794d34e7e6b3c291f3e4e52053",
".git/objects/05/4dba08819627d06a2c0680872eef8659552956": "afe5e487908188512a78e1ff95261d92",
".git/objects/2f/e85e42672621bd2539b75fa1c3285321020349": "4f826b07cf39ac551a84239f6eb3aa90",
".git/objects/2f/1b17cbfd06d1d9511be69096dbc881807c514c": "c4d0f003350e6b3b9da7963818ab87b3",
".git/objects/2f/c70545277f8dc9ad2a66385da7fbe95139988d": "a2386340396f74d9644d1684e82fc306",
".git/objects/7d/eb79b656f5fbd51734e3683fb17abba245c66f": "f7b7708472365fd0b09b4f333ccdd207",
".git/objects/02/0da6e0b1af10493a1a3d12bb3a1021d0d22612": "61d53697b6386298d3ee1daf6e434061",
".git/objects/59/0a81d6d8c87ca307ef7b30d720df9cd59223e8": "6c37667da10fd6f618d0d41fa3483400",
".git/objects/59/036968f93e79fbb6b2de34a4e270669fa7cd59": "b06b390b9d0ada18652896fdd9e59886",
".git/objects/a6/7a1e92f4e25cba6e2d707b9aba54d09a41e15c": "1ea3f047f108e73c9e68b3eae575d9a4",
".git/objects/1c/4c010b6c99a35acfbfb2d3651d984f95cf559a": "259c50e7ca3282d77be03d8aab3adcec",
".git/objects/1c/f55d30b7ed122c32c03db9994ecc1a43cfe3a7": "041b27343378996d4f8c731b3421e846",
".git/objects/30/4777185e393620a2f9bd5ead0c03a1910e5631": "673261333547d7881944fe3f81c1d6c4",
".git/objects/30/897a422b55a76c91bbf652e1c59bd447e06975": "376fed3bfc717ac449768084cb130c1e",
".git/objects/30/3f21df3c62bd00df1ec855bb577bddb6308d74": "e077c6200ca755005820effe5deee65b",
".git/objects/0c/e6f391d73c5b0108b03de9e776dd68c42fb2b1": "c9b76a7e9c4b9892d004eb80559b1434",
".git/objects/0c/a9adf72571cb6b7a01ed8efe3ee71912f1a0de": "e34655b208d3a14b82996561c3087830",
".git/objects/94/4d8214b0514d89f85a0ef3f8ec489b6bc6bf26": "f1714d0a0dc265ebc3b62375890ba7be",
".git/objects/c6/35a467964f3b9bf86428fb69b4857ee1cec947": "ed3dbe98dc28069c4c47261c3a615eae",
".git/objects/08/43648c6a505d6bf243bc0d2bf1d2c4d3407068": "4308147ae95cb36740fa1ad54bc4413d",
".git/objects/78/f12f73d0fc2f68cfbbc766e83250beb10e41dd": "655e66df3019d0c57b19c3873390fc0c",
".git/objects/78/44f3f1900e1e807a7d90a253cd6138d6a0b99e": "29d5f977bb4fccad773adf78e605d7a2",
".git/objects/f3/b6bede69f9d86f2d8254497e8119343f8c07a5": "a57c9758c50a11ff35e17b5e5bd5e14a",
".git/objects/f3/1959a479d2b7554b02c6f10fc42e57cbe09cac": "3cb6052486d0d18ed283abebf13fa334",
".git/objects/d0/d692a66b82ad26f4eb8e2ed34b6a9260b2215c": "ac28a8618c5104862daceafe3f1c3b98",
".git/objects/d0/d8b8fbc75db280394142961438c132441fcc4c": "64416fccd15553cf557c72813f132006",
".git/objects/af/2f987558dfcf7867794abd68d9782db8e16b41": "35ad441c255aa2447533b6cdc7b5f6d3",
".git/objects/39/c2560f5aac94aa20bf840edaa2535406bb0b21": "51cf24d389ca7f79c65898256c28bee4",
".git/objects/39/d49b6bf7b493aba5ab9322ed96b473bfb76ef4": "ebf1d3dab757ef9ac3f9f81044d9e8c8",
".git/objects/96/a46a2ea373b918ab3b02bf3543bb399ba8f1b1": "4dd1563fe0d694927559e60c20c0839c",
".git/objects/96/59144ce496713ff07ac0b315389bb638c1d548": "32994e717ae3e64ca859397a70b71250",
".git/objects/96/957113fd799cf19810f6786f12a1eba2b86cff": "65e02c798e3158300ded45d501b32a15",
".git/objects/a8/8dc108c920d76b7b72693a3b70635ff3d86103": "3c562d7483e2f6f5ae659f6ef0cc722d",
".git/objects/82/b5b54f3320b5982c4765654ddf99413f4fe5a2": "94b6a55392ac0e21fc23729781587525",
".git/objects/82/fbfbd43c4ca42b427581db6abe3adacb7efd49": "3b447d6f9c9993a1afb005537cf2b59f",
".git/objects/ed/dce1ac7687cb3aa1f55137f1edde9f8115dfef": "b354e3976d2eb0f13a958fdaf73c17bc",
".git/objects/0f/6697f64a702f4bc40e2f2de5c7d358f908d224": "ab67d64a04803671aa1243e3fd71b19c",
".git/objects/d5/abb8e8594faafc16f5d5ba9d1cb939c6b62e5d": "e2d7f820dea0344ac6327fc08db2e2f9",
".git/objects/d5/80ce749ea55b12b92f5db7747290419c975070": "8b0329dbc6565154a5434e6a0f898fdb",
".git/objects/e3/33ec91a8178ef2b96dc4745695a457a20d7b92": "e27814d6b82761bdc9183ba06bd50739",
".git/objects/e3/fe637e8c8a5cf06eca37a3e8d55ebd36b89ec4": "5e5a6863ae67a2ef8a55abfa461e03e1",
".git/objects/e3/49a9fae31d3e88f0b906c3bb78356197a8307d": "078937469a24a70e516f66627ccbb1c8",
".git/objects/06/a51be9c3427459223f65e4c9dbeafd6360ed9f": "0bbd037a06d4997b6c260c99af0fe7d6",
".git/objects/06/b447618374bdac54da678c7de4ff68d43fe932": "929b9c29d6e8051a3e3dbc5b45c9b023",
".git/objects/06/cddfe9d0d92c63d983de31c14b52f1dbeca866": "79efbe755c9d5ece0e1b3aee670779ce",
".git/objects/76/0ff6af40e4946e3b2734c0e69a6e186ab4d8f4": "009b8f1268bb6c384d233bd88764e6f8",
".git/objects/5b/280aedc8037897f572f9404bf98d5ba26a6aa2": "d2cf84966655f2dfd3623cf8654fac3f",
".git/objects/5b/c6b47aade8ebf7ee0fd933c65adf51cc0bc6e1": "402e922090482179237edbe77adea6bc",
".git/objects/5b/74823647fe93e2a20ffe032a516c4fb9c76ba2": "bc5561502532d1e4e499ac555459d789",
".git/objects/17/3363551f92327407537759df1f346e40f18cd9": "88ba39423bdae9fb6b7be3f9e7a686b8",
".git/objects/66/9dc5ff2b97d867c8b978797b66f2beeb95cb64": "12bdecbca9cc123c1940ad7a1aff07cb",
".git/objects/66/5b5967178e18225cc9b83bea5e86c8e5d381e1": "f3a0376611e72adb782cb62afc2b8f04",
".git/objects/3a/a9bfdd0098ff7673ac5ad7797fbe043cb028f9": "3ace79e33bfc9c2623b7cacdc08932eb",
".git/objects/3a/dd3d4753eec35910efe66b5608bf98b156fb9c": "2d77df4b2fc02114c9e43005c5d1e4d1",
".git/objects/46/ffb2af3df311abb58fd9bf6fe949c7c02cff08": "31007f64e11c1e1919fe4f7552087aa6",
".git/objects/60/eb7d42e07292e827eca7e9b177907d841ab492": "e6bcf978f5a3f0696531e154a29584f2",
".git/objects/60/c74220f504e4cd7970986da25927f6065bf2c3": "81b47a4b98d025865ae21d5fca55a059",
".git/objects/37/ee88a0eab5e03f1fb1aafd8dbfd699975a6d0a": "a7b983718e0765e07c761d2a9355fb78",
".git/objects/2a/7b27d068368405f01c9a7a2bac9cd881697475": "710fa1c8bf2a344e546541390a103c76",
".git/objects/40/12b7cdcdb16a1bf19c74bbf26a0dff8164369d": "85505ef1472f28765c18a5ad740d7d05",
".git/objects/40/30f4495152d3cc42c95af0fdcdac7104e9ac2e": "b683079be3c1619e26b4fc64417ed5e6",
".git/objects/40/a2bb55bc5778f17e4baa6431373c47b15660f0": "53cd6fb262d4f3708403538ca34410af",
".git/objects/40/7356cd3e3c072900be86b8306b740f0728b1a7": "2d976f3ff695af2f5e3865c72f742326",
".git/objects/40/c20f9c3cbe58ae2bb502be46b5bf8f7a5e7c68": "0e9e2cc331651adfd4a605c243a3f4e2",
".git/objects/88/6e1a0f8d00b0d522d81f07798843fae0e3d6b9": "db0ffce24e8c000241122a22bea737cf",
".git/objects/a5/9f4583bec67666f15fb7ede53ebd862bb9781c": "a4c995d79ddedc5cc43b2362a6aea6aa",
".git/objects/a5/87735aca94dce5797f07cd21ab9a4c1f16fe57": "ae59e33e3df520023fb4f415b82e9e6f",
".git/objects/a5/8d05b58a798b24674dad1484190b4784635a4c": "b79d3353ff3748cf2c48652e147bf809",
".git/objects/a5/4e0b40ad91bc5eac8925b497497646c1033b3f": "524509ea07212c773b6b8e40061e3f43",
".git/objects/a4/c6fb6550bea7972386b97179b7cc0ba3f0f0c1": "d0a6d7a34785bc709978ebdb047c9d5c",
".git/objects/fa/956eb7f643c89b6e0f6dc48f69a2b61401010c": "a01135955e199817cd81c6a216733d5f",
".git/objects/21/d29aa520a50b70d5f0e1c918e9ab09ca8e7819": "0c215afd5d0ec4696ad62048edd27df2",
".git/objects/1e/53151513016d61e9ba78f4bdb97d3bf059b729": "268edf063029de8ace9a000aaa543b85",
".git/objects/98/6da52544196780c1ca250e253cedb3dd61882e": "c58f9570c536f71e8f9a925b7e8c9735",
".git/objects/98/a6cca1767108451752bdd1024fdda1f11c628b": "04c981a06cb43728a960e53fec172128",
".git/objects/98/a741933c0c8b4e3c7c08c450206d99ef0a8bfd": "15808166e33e417c13d6e08e8315b16b",
".git/objects/98/47f047249d6d78fff278298f6cacb2f0c31781": "615984364a11ae60c60f877b168ae559",
".git/objects/98/7c9fbe533a97fc8574ea8e0fa20e5dfb0507f5": "2f19c737a05a9099f53834732c6fdcf8",
".git/objects/98/0fd3ffb329ea619db553c057c59f8cd46778ce": "3855b3d317d9f0b00af5da9e7b89649a",
".git/objects/6f/e141808b1359537e9be07ffd982ccfb1387f81": "3c999f0d5eb440bf5d1e8a8dba07e229",
".git/objects/43/5d22dfcdb747c5839618dd5914f4037abf62f5": "474379f14ab14f5470c66cb94af402e4",
".git/objects/9e/31dad5fa3e8db2881ba8895403b1c59ea10f24": "5de5d1d1a206bb501897c3755ed0da6b",
".git/objects/9e/af39c7a5289ec975ffc8dc0e87b3f2502cc3b1": "45df22d1c3e558f2fb447e6b83027813",
".git/objects/c8/7920c4a645807111c77a0f2b23b9b5ed18705d": "0d5a89c46484a6630789633f00fbfb9c",
".git/objects/c7/0fe9f1a3f03978a0d033241323d33b86859902": "ce440d6c399aac4d4776fafa2aadedba",
".git/objects/fb/d37ade91a8a242e4a805594fbe69c4acfaa441": "a9b9ed3c08c3cdbe75670e993e8417ea",
".git/objects/80/dacb0dc62d941cc218aa4c3945e76aed005009": "a37fb493a5032ddccce7a64ba85194c6",
".git/objects/80/68e9a952714f1f5289ded82bcebc920d6e69af": "f6b5cb843991b7e61f7025bc0841a4bf",
".git/objects/e8/7fd9b03c70d3eba4624d81150bbae95a19f0bf": "7980c2f6dceb9a1cdafdae4391053aa3",
".git/objects/b1/fccf3c1bce2fa0232daeb482eef175fef3c20c": "b0f0ee43f43665f8b9f0b88a474c728a",
".git/objects/73/5c9157edfd463764e8f24c4f2cdb44afb42bca": "b7ae908374721ca1b834296cf281ab27",
".git/objects/92/eab450609b7dc5d076ddf6c8416de8209373e0": "9b3d4cb7f5916a87f36a18b466ea7ac4",
".git/objects/92/2516466892e048cf9a756d91d9dab079c60db3": "ec0ddd51a25ccc2bddbbbfabe06c9138",
".git/objects/99/50bac6044f9fb5b5e651f88d5920001432461a": "af6ddd041e09256afdb29ad9dac7800f",
".git/objects/b3/197a073e9f8b808b1e312e011ac4b47c2f72f3": "5b479b70eed2b0714520a9557667c526",
".git/objects/f6/3c396ff8966302835729107b443ba69e29a0aa": "1b29d3d161557705a31e4de41fd2557f",
".git/objects/f6/30514b7b14b6771fd0bc3321c554ea940245ae": "d993ab1cb6ed8c9b7cacc1f7f5840061",
".git/objects/f6/aaa871c87614531ea7e510b70c099ef1380863": "cf9c8fa30aa3f880209f66df01cf87c7",
".git/objects/72/dd5cb1c5af5bd993f09ccad2d113ac2b0724f8": "3469a526a2b6ddc9935e0b5b6f8ca24c",
".git/objects/1b/4b3e2254199ae3e9606f08bb0665c25d3e87be": "6f6976887d170215971dfed092a17ae9",
".git/objects/a9/309d44b837fe7f6a68f704d8e5d8704c438419": "29ecbe544d324432b5da965f8bb6e155",
".git/objects/45/a4011c3d8eb0beca810df48ed39c4d22694975": "6a16ccffb8e72433fa292d4f74262812",
".git/objects/45/38b22a905a62e24354b2f75dcd7f66951e3771": "b43c684f24b3e0fdd1cdc90469de9423",
".git/objects/45/1d335a734303c4a40e380baa357eaef53e19c5": "1bb92f30b6caf16fa4e750cf4c9d887f",
".git/objects/45/49f4e726f27c9cd4584d20a34357c52416faee": "751e003007be3b5b212acfb38c7153d0",
".git/objects/45/f5a826a4acfbf96181052d9a61b67a4ebfafa4": "0fafc37e769cc652ffc2178999fbe847",
".git/objects/45/5d94e36e81f8a84b371aa81e0af063b43bb05a": "c4cf446613626acec44be748f226ff5a",
".git/objects/a0/0fc42e83b13d09bf33c70ff20795efd1f85912": "203f9fe29fb4d669cd81c7968630c283",
".git/objects/a0/944448a93ab9eeb3ec40d3f0bd7db743f93dd8": "56f925fbdef279dce2aa27cda5e76a1c",
".git/objects/fd/9b4a10fd644968ca6c571c7908671e950ff71b": "8baa6655ab7ec12a53bde0d398d05178",
".git/objects/85/e6d470a16f952d326f0b90dd5783dbcd73cb93": "5233d1e3d0c76e19dceb15211a3b824c",
".git/objects/ef/f21a390e32a24a76f4be064939343971982a5b": "3dd47d9912b13968c96e16e64de3764a",
".git/objects/3c/59ad5cbd15327710a25a007a690f6a41014f42": "b3e4e986ea7b72ba88217992cc7d9955",
".git/objects/15/5b4bd2e09b8956397c640a1a5285ef385e8a53": "f464715ee4a6bc0ce42d4702977349c1",
".git/objects/d6/391c39a690cfec015359b9811689ac6f0f641d": "2541fd64b6e4fdbe887595acb9a07e67",
".git/objects/ee/fefee6349b9c13bec891f3da4c389e27303fb1": "30831b0497385272e6c979e64a5f7d5b",
".git/objects/ee/0946b5533ec44191e73349bd15b2ddac12efe3": "9ca77d5a3009f8bd91791c646f53a154",
".git/objects/d4/50841abde1a4afe5d5ad520200f5c9a2a8d6d0": "060df140f2b54e7059663e3b2757b4ea",
".git/objects/d4/cd8a820bc8985c3db296fb8b286d7bc8ff3951": "eb230c6b113a697cc2c8d854f5cedc95",
".git/objects/c2/f278651d7d17eaa92ebf7edbc709b8693967d9": "a3d6be929e402e7dbb7a8390caebd7f4",
".git/objects/a7/fe3508096bbeda3a14872bf8f170d4d32c31aa": "beb1aa55529727a70b6172e4b85f9780",
".git/objects/ec/5c7a5cd888fa37a64a738ab81f77cc7f2fa9bf": "923b21fa6362e81e9c2bb4008e755183",
".git/objects/ec/d0bdb199e12941938f5c87d62a7fe5764403ae": "754874a21ca5babbc2be788c96390bc1",
".git/objects/ec/c21bfe1b74a7bff0dd83544e993023e12b4522": "07588a022eb0fb539b78519d54e3cc9f",
".git/objects/ec/bc567faeb7fa1a7b46733dc277430244326107": "d24aed34628bcb743b6f314eb54fc0f7",
".git/objects/b5/66dec6f45d86060b952f4c42ab687c42e6e4a1": "c205a2c7555529096b90ce0578ddd858",
".git/objects/b5/aa0903a4427fc78a564f280a2ee3b14d57d713": "d63ecdd1d0b34babc0006eee0924284b",
".git/objects/b5/bd4e8e686e1d79c9cefeb247078edf0b6daf82": "a1b77beaf422b6127a32619137885f30",
".git/objects/44/813d19d709c5b0fc6187a6a0f0955e4eb9fd01": "81f51ad58f8033514e09d47d2d614579",
".git/objects/41/5c059c8094b888b0159fdedfd4e3cb08a8028e": "86914685ccd40e82a7fe5b70459fb9f7",
".git/objects/26/a7647f4363bfc866d34c0840c8a4ac59398873": "a724a5fd9653c565cf1dfab16bb2ba58",
".git/objects/26/5890d04c385c70ad2f6e3d9d2619205c158119": "3983bedfea7cefd112abf3effcf2aa4a",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.pack": "6a9914bedb976f7f15356b0382dc35d2",
".git/objects/pack/pack-aeaee9485a921ca454830657c4b5c1105c6dc954.rev": "b03b014acc9d88700cd79ceb463d1a93",
".git/objects/pack/pack-aeaee9485a921ca454830657c4b5c1105c6dc954.pack": "4f844f78d926db86627850623b32a478",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.idx": "9ad3e69f5583fed02e9128c8aa8eba66",
".git/objects/pack/pack-aeaee9485a921ca454830657c4b5c1105c6dc954.idx": "32e052d800698882a786709443150acb",
".git/objects/pack/pack-8e84c5255a6a5da027d11ec48cae44291e06efff.rev": "b7f28e1b599664803c8d58bf785401c4",
".git/objects/68/1f6449cd016592c9e87920f92637713bb4ac0d": "5f5b1435d8f2528bec580b4e9c81b86f",
".git/objects/68/895acb7a3838161cc878fe072880c273100389": "89e547127d05004e02e321e5e7372371",
".git/objects/31/e85789a55c99ff22cdd3002796e03dc6dd9d30": "ecf71ccf5dad8127bbdf83192b5e0277",
".git/objects/31/fd8905848c7584609eee5493a181c704677bc4": "6fbd2ca615587bcc884acf01abc6820e",
".git/objects/31/64e121bc6eefc9bd00b0a54fb811a4007cd05d": "ce10d38d11276013b7516baa5500288f",
".git/objects/18/0fb6fa92004a1ee0d3904243ddeac65cf8d683": "705383c8b57303db8e3fa66ddf4ba19c",
".git/objects/18/6369a67091f5ae385391f60a4885f790dc5d6f": "8395e6ca7b8281fdaae3de95bd223989",
".git/objects/18/ef0072884ffbe5c345fa9bebe7c094b6cdf4b2": "ddf0a108e4feff32f94610045248605f",
".git/objects/e7/606bd969a45f76bb61be2d01ff610b662c2e61": "425c9649988f0ba81027d065f6c92239",
".git/objects/57/91ae35aa03f8647b3faeee99d79c9d9f76552a": "fb40ddab3b53f196985636d1985cdf20",
".git/objects/16/087cde21d48e37a828219df85fb03684fe9591": "cc18033793d3b8f42bf92de5f0eda3d6",
".git/objects/16/51a213c51d444f8cb4eb2a349a1e69be695b41": "4c5924afd4643295007da60f129c1eea",
".git/objects/87/1555952c551b5d09b05ea09bd6fb1ae0e714f6": "67f5e99d2a1d502e7669ef77646d6d19",
".git/objects/25/df413dcda2d90d89f3f1b311860cf5d686c3ab": "0c3b9a7a1f8803fd31fdfaa5308d5973",
".git/objects/6d/be9edd65411b76d1d0e83613c9138f0dc7ab12": "f42095df7a2d8393c56d61bba2eb4d38",
".git/objects/cf/93103ea52376edb19f53bf73fcce2e11fd7cee": "3b6a83bf59653d67c0ff0f8ec061438c",
".git/objects/0d/28079ce73200f58142fe85fddc3d56e943c356": "f9c460172946ba95fea5f44e96791ed5",
".git/objects/ae/0ee8fd64a47f73f53455690ce77facd2b4b7e3": "2f5c41691247c02305c7d51da287d663",
".git/objects/a3/ce7c25b3700e422acde95da4fe07dab36743db": "0d3e589c0f17b5f01a6d8b41e9be991b",
".git/objects/13/437b8c4e41c95a6aa58dd4b15f58f73a478bdd": "59c518258d4742b45dfa2ea7c0ce1a66",
".git/objects/13/19233adf64ccc51a83c04f8b42c884acc0cb61": "0227d505e8c026b66520717a695f0e7b",
".git/objects/13/e16e3790cc671dbc2367b7767e7ef1a0c97a2b": "65f71c57c4b8faa9f28c8e0d8db36736",
".git/objects/13/b729df9cd3f9b014719b12a9a903aa347265d4": "e02ecde557633c23d2c495db9f035603",
".git/objects/f5/f8e292e528510478bc60d0dc0f65f0d783bb9d": "2842a817d8c48618cb6c7c5644bfacd2",
".git/objects/f5/5b6b0f739f7d8ad7a86bef3ac355abdf87e1ee": "83fa79a1998e6c099ba9f25a17562d4b",
".git/objects/6c/b97f2e4a2b8b27d58cb552ea3ab2eeb811b594": "d08fcdc86e52eca369cfc287c925c398",
".git/objects/b9/f1eb125afd1dd20f6350285d640b4f50683e0d": "d9f0629c9571950612bc17ed2a6f7e82",
".git/objects/b9/80c93a1eaebb589772f7173ad4ebac71bdefb0": "1d2db901e9b3f4c9de7e6bd34ee2d8df",
".git/objects/33/de571acffcf8fec7e94af17f601eb6761f16ff": "5362476d2deb42b358d1d7886a0085d1",
".git/objects/6e/23c3abb8751178786394025b9e54de7e5f6f80": "e753107de7c77e54a0ee4df67742f00d",
".git/objects/90/dfd6ee687472c8e01c080b077ffa7c2e9af86f": "b8663ff887d2a88d2ba9142d8b592576",
".git/objects/3e/8f3e13b81ad1999de240b80c498603eaaf1d76": "2a7e9932b75707a9c14fe51c0989892b",
".git/objects/cd/b1df7012375313817bd75378bab40d467845e3": "425dd4195bf9ce135e369f87cfce5cc3",
".git/objects/cd/58a2650dc77cec0518f6f3dcb1e3ab762eb219": "ed3ec8aa323947e002b4f8ba1bdbde55",
".git/objects/63/fb5c0bb914877909061a02f8cf0473aee14807": "5e193c92c5223b357c74a0b71bcb8c65",
".git/objects/5d/c44f215885b636bfa06225737474469b57d70a": "bd76adb8f5ffaf5dbaa98c0e8a1b0029",
".git/objects/d3/3df747a4c26d017f26e5cd250703c18fc52b14": "ac6d9e1afde0b59f68acc92078f30ac4",
".git/objects/d3/83854549c745be56f2d31cec3ee5a8bcb13502": "78e6e212ac951a89334c31936259e6af",
".git/objects/3f/599538240f31e78489a2d1992e67d96aaff927": "bff5aa31f7269c96a6bc2f7120df6ff5",
".git/objects/3f/2c5a247ba0b2cd0e311f206dcc57aebdacdaaf": "7d1127e5b7e4f61ce437878d69231d50",
".git/objects/3f/7134af7ad95352b1bd19e6633f3fa81380ea8c": "b8a033915e02c792a6af98007ad01aa3",
".git/objects/1a/ff2926037f41ee4755d0c554467c25479a93b6": "607457a10a3e4c1157f63c502beed052",
".git/objects/ad/4c0ba9842f4de544316a62269732d33f652961": "d2648c4f7ac6a01d24dedabffef3980b",
".git/objects/97/1a4ec28cfd587e97d3c08dc03829ce8395ab1b": "115090257dca116c158ea98e9504381f",
".git/objects/97/76e44e81c6a8476c5c7e2ba93529c1f4494946": "8967fd1a46c00fc6e1c72adf774687c2",
".git/objects/eb/1fe2da53fe8af2d1454e785644e19be980e1b8": "3ed5df8414fe03934e6688c59f494dcf",
".git/objects/c5/e8a4d389ae718605235ec8e79dd503257782ff": "8f26798e5dfdd79a6657037c6b4b5b0c",
".git/objects/58/16dba5ddc8af0a07ba2750b918714b700eb660": "6459935fa9db1bf1df8c78d6e45b9045",
".git/objects/58/182427344dec75b4f8f9772fa9d0b070bb4a5d": "6d8dc7a0e322aea78fa8e76fd85562d0",
".git/objects/c1/25f71fa83c44f10a3710b1d7a832609162252f": "7c35f97fe1ee1fe239049aba596fa28d",
".git/objects/42/7d5e8bd5420aad1f7ab05cbc27ba8f7ae7ef7d": "ab30ec414eeca6ab594bab44f5d017b4",
".git/objects/42/9f32d01b642a270fc40ddcc71180b3e4721675": "50c28c02eb662d0a2545fe3ee7e7d82a",
".git/objects/4b/903f62790d2276f11df6b6ba0ed6381482cc6f": "f5aa8cdec31c4587d2ba21a5857eb2e1",
".git/objects/4b/8badb641ab515d852cd151c6814b8aec7f5262": "bd2abdacc2f530d73d8cad8aa82d829b",
".git/objects/4b/cdad397aa557f80923c990c530acb79b7d3f25": "59b5597b8b5e25c456851cf5131f6208",
".git/objects/ab/94cd735dc3a1ce1fc27599519ef84db8b7ac68": "65c0d508c0d01073d526ff481307d764",
".git/objects/00/3d2a65a2a5abeb76d8725d5dc8568334a3ebbc": "df8f9a95f09e6cf3f1d2d30fdae8098a",
".git/objects/00/5318bc2b7f55bd93bed51bae52a91b9de8bbe3": "f4cda46fd5017e88fbce5647685a745f",
".git/objects/00/3d21da009aeb19ed2abab2eeef16eb7c8237f7": "8303a54cddf35fcf90c60feb90484557",
".git/objects/03/6d8c77031c90ce3db3e999cb2d5bd532414513": "58f15818f39842a121fe05c1f9ad5429",
".git/objects/04/c30a4b215d0314bc16bbfe81a83895adb1db8d": "fd2ffcdf7cdad2a50ed3c7451cad722e",
".git/objects/1f/b6d879c2afdad9ab853de45a490bd329b57e5e": "802ee4f0edcdbc5f844db4df9ae61ecd",
".git/objects/65/60a02bb6588b6c50cca044e4fb9ffb8bec608e": "b55f1e5bd026732722274f78f914477f",
".git/objects/65/f253a3a971ded3e39bb08bf90dd7bacee69b04": "ef62e82ec29f149cf4f2184a62c0c188",
".git/objects/db/5c89dff72f538ec91eb4578b181ecff7ccc112": "4e503022bbc63b834705ffcc916cd048",
".git/objects/35/6b489ababcf8fe0e22327e3398b580c8e43e01": "6483c8e7b4b6509804eec4a8047d02cd",
".git/objects/35/12158de67d47d057c8900334e2527f397f83f8": "38b6cb3f0e5172b60c57c59a9a597998",
".git/objects/dc/d5c9c972c299420eeefc143e428dba7edde55b": "4eee8532c17d4d1afdd18c0738a405b9",
".git/objects/dc/81c2082f4bb5f4c4d38b57f80741d3275e8ef7": "a876c2a08570bedfe8f0d4cbf78c2e41",
".git/objects/7c/d96cec6923072f0c3eab872f7a96a126b9b7bc": "fdcdeba208fc6163379d42a79c875f3f",
".git/objects/4a/47caf6ef3aa63303d7e3a677f4642f2db094fc": "434f4d2a5ae3db042277ee9653a620ea",
".git/objects/4a/b623c7895da8d74f94437214f0299a1dfbf2b8": "0f1aad85e5a12e311abeda766391ab63",
".git/objects/ba/1373047b4fb307db6ca7babc39fa4aad54485d": "5a8cc55b847c884ba497f29d11c1fd32",
".git/objects/ba/ec3628daa7e8ff6f5037a453fe93e05ea9fcd2": "6b83965438d2dc67a00ad287ab7f44c0",
".git/objects/ba/86250ae8a64cf64097337a308fcac7d99ce61a": "139db4f1060457b728607cbe70f8230c",
".git/objects/09/9561e2bf722e592d6ae1742b822df002b3ff5a": "a2dc34afbc19bcd3c90d590a2e615fda",
".git/objects/20/9e807a353c6f836419e9753a51136fd817c02a": "5bd3ccdd55a4126bd4e39faeb52093b4",
".git/objects/20/28c5e4e3e6252aaeb393a529b6de572a26a1fd": "2f4e5daefe7dae004e34eb2e803c49a9",
".git/objects/12/ef842e96531ca3d1e34e9cfa64ebedf90d78c2": "20f632c097b3cf0d08bc9f9566b84060",
".git/objects/bc/6909b331ed20d61be32a6b6181aa7c500ec20a": "8925dd969121152b7602c25b83576001",
".git/objects/bc/70c1d467413a827e749077ad0ace43432b3fde": "54cdd97e033d7a27744642c2c7c97346",
".git/objects/bc/5737ba5d13a977ecb8e47e5c56d638378bfd36": "9182fbbc3373238942f49eff088c1f7f",
".git/objects/01/83907716faed08ce3581e2111b669a1f744628": "966f8e2f0b99ad93dd58c566b87ac490",
".git/objects/bd/dfc8f91a4d7e822291bccf2043723b44c4c5e8": "d8b455e931791ba2fa4d56fa35d07d9b",
".git/objects/2c/7a96b316ce7812e528a2b5b9c1dc81a8ec7ce3": "300f29be56d2e42e553b5ea7aaf46e1f",
".git/objects/2c/8b3db2ed12077581b2be1e897731776560cb96": "1504822fd426e0c23fa0c102d06264b6",
".git/objects/95/62d2092f7cc6505dbc1620c453289f824c51d4": "3c628e6a9d4b9eefb790d48b78d00faf",
".git/objects/e9/e3790e760735e533a971076603975c07909c35": "c70f71dba9145d7906e5822796c0e219",
".git/objects/e9/be8311bc34ca779a70f9393bed586680687c7f": "5b9e59f9dd1380af50f91c9f6f232372",
".git/objects/e9/bd2d8cf9959ffe90591acca1b3263dd3d529b5": "d0827ff4fea56305d05f4d4551f62f96",
".git/objects/53/84291a8f2a07000e8ea4f171adb9a6ac52972c": "a07a25abf286438fc41d292df95a0d9e",
".git/objects/67/e1beca6032573973feb9df50812c15d0999da5": "3f0d7601441c0aead892d5304b30a946",
".git/objects/67/c644da114932bf75634791367954687cf68e4b": "e7b93b610ec4c2c9bec7e11b22bbf6c8",
".git/objects/67/997b6c5d116923032c688c8c4a3ecbd6f418c4": "96fe29999061d89386723e914608dd6f",
".git/objects/e6/9de29bb2d1d6434b8b29ae775ad8c2e48c5391": "c70c34cbeefd40e7c0149b7a0c2c64c2",
".git/objects/ea/b2d1a73331f58554f09fa447291b461af7fc96": "a3005132d3b0b2b6d9412e75f18f2afc",
".git/objects/89/e61caa9d0609ac129d06cad363c61547bfd385": "63974ade862edca8411194b75fe93d09",
".git/objects/61/ecac8954f7182519bd21c4dc8ea9e291ffe317": "3bf1452410a2e43d93153afad6e1aa41",
".git/objects/61/59b0a7351fd667d40a229fb1354a097d55b298": "171e5b7c35e0166eb8fb8dacb4c4ba04",
".git/objects/14/64a885b8f5b7d040ccebafdfdf464fa9bc4332": "83ec23c5a247191ac4e57f828e865372",
".git/objects/14/509c65562777126afd5ef5cdcff2df85a0ca7c": "71f99e28929468713d280712c3325ab8",
".git/objects/77/a13b798708c6ccff7d267863854c02b2647b4f": "1d6ce3658b952672caedd79271071b77",
".git/objects/77/6d0515af40583a51c457c3cac5b8118abc88be": "4252c521e27fd8913c8dddebb03665f6",
".git/objects/52/c187856c761ed97d60bd7fa70f270f4f7fb7ea": "1b0eb73db1028e46340191e0cfaa3646",
".git/objects/b0/07c0fe6627dce708f99ca6404550e8bbabf814": "167d9785560c99abdea805e78d06e59b",
".git/objects/8b/f6b157f46af2f2af92ad52bade706324a90eaa": "af49db3d3f7587cf73c5faef0c8f8e8b",
".git/objects/8b/e0ddebb5155b64d579df036ab2c3afae85092a": "4cbee23b352c3dffbb3e0ede1e81de89",
".git/objects/8b/ca5c9fb4ff8f9886fca4451ffba908fe9162d0": "51e2ba6d592caf37fad85e4be6b2937a",
".git/objects/8b/0b28d5ba449e79748d9805994cc1163b21d06e": "f5c600ec2c1892923c14f61688695da9",
".git/objects/8b/03751a6a17371d42e1fa8879e06c548b795cdf": "0dc8a0f8b5ad9cdcdd6c6567c94fcc7e",
".git/objects/de/9658c4d4305d7c38903f2fa9ec11871c312941": "f69304397228ddee555d6f60b5e15cee",
".git/objects/2e/7e936eaaeb8a10db0d72863978d76c61f4cd41": "7e4717de807332c0264e20839b330271",
".git/objects/2e/f0458fa42536814bd18eb19185b1762e8401cf": "a7dffba1bda5c9f4bae3d4662e7943d1",
".git/objects/b4/040136e752ea224276e7ffb7889ead95035f87": "b8e882094783eacaf47747d16537714a",
".git/objects/9b/5a7e346d16542ac343f1ab5859577b69d59399": "e2353f38aa253fff7f38998bb4d5acee",
".git/objects/9b/91443e642c96dccfbdde0390d4b4abe2fac1f8": "a0b8c81bf6c8f4dd5e283b7a14062695",
".git/objects/f1/ddc80637fbc7491a4a758cf4cc94a8eeca36b5": "bd555a776cbc9b343fc13b4ecbd79788",
".git/objects/f1/48bd60679ea5e6389e61b3a4b9d6a7565b8e76": "a85f3d6b0c637c967c1a92f457e36451",
".git/objects/8a/85cb0846c90ef6aee76039f831203c201a3a2b": "038e60d2c1ee3b28815d274578da6a41",
".git/objects/8c/99266130a89547b4344f47e08aacad473b14e0": "41375232ceba14f47b99f9d83708cb79",
".git/objects/8c/a83a2ecf6fcd837a2ba9c6b6063347e03bfc52": "795914ee32837d37ac17a9f22e7d5171",
".git/objects/f0/39964e11acf0c8f53dbac0328b4287a1030068": "b80a13ab131f22aaf64eb8534633e321",
".git/objects/df/8f38e3ae7d6bec993643029e6652679019fb9f": "fda6a86b7e3c02dfeec1b569b56eb0ce",
".git/objects/19/48a1d387a7e0a64c7fd9a770845502f7638394": "3e93777d6dd24af1f2e27a0ebcce9ee4",
".git/objects/7b/cbf24fa4ad00dd160bba6fc0dc7ff363167d75": "ee8911626d6401120b7f51f787595372",
".git/objects/50/516806694a66f880a674b90041d60f15d0d199": "a5e85f7284778f8cf7302adfbe362091",
".git/objects/2d/b6dddbb51f857e114bf93603ba57faf4c091f3": "d31c50c93b2d4e3c869b9e59db7453a2",
".git/objects/4e/121052b9911027fb4c854205f93759e472a80c": "ee5c21bc032364f82e6471e790f9e27a",
".git/objects/4e/204be50e383a8e95d8093b304457e92d5041b5": "9f725ea3c07dfbd5afedb2515c7b02f5",
".git/objects/4e/afa19433361f0da88f675e640389041371ea88": "32447dd8eddd6a9b6225f89f7113710a",
".git/objects/34/05c60a7e5784634c210155b9c33f7d1380b537": "812c09217b2d251e88f85541c62b807d",
".git/objects/ac/77ada1bd5cb9efdabc57a951c939d09df21439": "4d45aedc6c1e92cf221df59f8ab95308",
".git/objects/f2/ef19be167878f656c44c67fe7b8d683d802e40": "b576963cb799401ee699f493cf957741",
".git/objects/f2/a8a9b5eca9b021a2f2f68fea4238d2025ee114": "244f0177d6ba56f4289e9d7cf68bd6ad",
".git/objects/f8/7790c41dcaadcaa9534aceeb0710b374977e62": "6e938b8b038092b770f424467ac44acc",
".git/objects/b6/3defbab3880949eb11c5ba8eca0714c989dc9a": "e990f82aec3c451ea5ea6bd8fcf0fc10",
".git/objects/b6/fda4758859db0f4cfde2d97e3036b9af4c268a": "3af236643075dad4618530da22fa27f7",
".git/objects/4c/36774f94f92f0e0ad5aaefadc7f0d2ae4baee1": "1846efd14ca499e07f827e586aadf509",
".git/objects/91/754e07c8f09f19b13c1d55a3ccd8b1a921dc20": "5a127d301b6b1287d45e1787e916415f",
".git/objects/91/f92c51be68a891122aa02e9b28e0655099d13a": "651a958781d387701d4751315b6cd97c",
".git/objects/28/e9f4e91f6a877cefd69cbbde1d719a6ae54ed9": "2a7b7d5d7abe0e96153f6404f78bdec8",
".git/objects/28/22cedb29bd0fe2d77661b4fe38f6841569887b": "6c25256d9de585cac170d832406de9a1",
".git/objects/7f/ccae166c6eaa01b195e0111cf93c844a41248c": "ebd0ea2833b529a4f033acb167f9c850",
".git/objects/93/96daff2ffc885cfa8f99af9641b23a696ae047": "328eae17992ea733c18cd27f806e8103",
".git/objects/b7/dfdfafa0c7b181d34e26f0bc925fb5279b991f": "4c1c9b57db20efc565c9dc7d31bc1fb3",
".git/objects/23/69be3a7edd5dae3e96b850dcd367ba86383d1d": "01c99d12706f448392f2fcb4fb92c7b5",
".git/objects/23/78cab98c8f6bf7e1af2668e5e813af647323f1": "7a4f6c279a3344e12903caf1e8157a35",
".git/objects/23/df0c1681f32196a9fc6c4ef6ea682239ee2fb3": "340b66defede0caee8a3192ae4bc06d8",
".git/objects/23/1f26281f286c0b9397000a12cde1d843ccfd07": "b109322e5ef59ba3eea5a6a3de9553ff",
".git/objects/47/e63e2f94281313e92f7280b487df2e1243b235": "85bf3a4edbdd7511cba82eff4d17ac90",
".git/objects/24/55fdfaaaa9b2080e85f616a5029196011882a6": "be76ad1b50e8fbf4ad107a142f8aa798",
".git/objects/24/1a28f34e3d2fbde2ac841e31283d8d1b44dc6f": "9bc87bee0a1f6514bd610fb7dfadf555",
".git/objects/75/1aeb24edfa4a8f080b680589a22f9d79285f1f": "1661301fe4eae56aded31cb8d6717b50",
".git/objects/75/ae48b487fe5e7f1f65192cab6ba0f0915c0c4c": "b81548dcd9501575a481d7db40a40cef",
".git/objects/9f/5e12e5f7dd24755c8a1fe47719ce96a08701e5": "9d1e4354d90a2b952b3e3b2f8a623a0b",
".git/objects/5a/3fa91c666897d31d41beafae6db24ffa49084a": "3704d3910364cc489a95aae4ff9deae9",
".git/objects/5a/39d0788ab22b7dcf560863c3cf6d4c2a5a1a70": "45fc750ffc39645657ed2d8500f0c097",
".git/objects/5a/a960007e5b7a52f1d028272b594ee3d6a32336": "2623bb4790f8800f01c2fb2bfa16ecc4",
".git/objects/49/474a1d75e809af86449dbf5d1cfc39e197791c": "3a9d829adf36f8e0a8ea301359fef6c7",
".git/objects/ff/d213695941cc34f600905f3b0da2a33a3d7984": "be95ffd8eb06f5ab7f61fe147cd5f538",
".git/objects/ff/31e21a45754362d60eca442dfcd28e674fb3b0": "f140bf137a281e85eb4ac962f7fa7bf4",
".git/objects/ff/668e6ee9badc5c2820eaaaf19ea90f67ad0e62": "d5bd9d450fec88f1330ca1d833142b5c",
".git/objects/7a/43bfb70e904b086b0f1078c17751f630321ab4": "a7d8d79482441b8e16db9e62727d16f7",
".git/objects/e1/0429dc7f4143830081599b0ecd10800457670e": "d6d26ad31b527794cb04c4c234568781",
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
".git/COMMIT_EDITMSG": "f8e64b8185e38e7e8ca34f3d88135f47",
".git/logs/refs/remotes/origin/feature/cloud": "38bd624a618acbcd7b6b2066fc44aa2e",
".git/logs/refs/remotes/origin/master": "99625f1ec56682b8d79211b6ebff5f70",
".git/logs/refs/remotes/origin/gh-pages": "9dd24ad90adf6c3bbb936703e0cfdbb4",
".git/logs/refs/heads/gh-pages": "6cfe568704b277b6a2c5c8e0e603d979",
".git/logs/HEAD": "9fbc21c1fcd1224f5a9ae7a81dbe6db9",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"README.md": "4f3da60ddb70e8644b2f11a40879dc6a",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"main.dart.js": "eac62def1a82d18d0274387678576ade",
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
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "693635b5258fe5f1cda720cf224f158c",
"assets/AssetManifest.bin.json": "69a99f98c8b1fb8111c5fb961769fcd8",
"assets/fonts/MaterialIcons-Regular.otf": "54a2981c4319a3d0fb23ba21731e957e",
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
