# wari_can

## node.js

```bash
sudo apt update && sudo apt install curl build-essential
```

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
```

```bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
```

```bash
nvm install 22
nvm use 22
```

## Firebase

```bash
npm install -g firebase-tools
```

```bash 
firebase --version
```

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

## リリース

```bash
cd ~/wari_can/build/web;
git switch gh-pages;
#
flutter build web --release --base-href "/wari-can/";
#
flutter build web --release --base-href /wari-can/ --pwa-strategy=refresh
flutter build web --release --base-href /wari-can/ --pwa-strategy=none

git commit -am deploy;
git push origin;
```
