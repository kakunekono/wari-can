```bash title="GitPages公開"
flutter build web --release --base-href "/wari-can/" --pwa-strategy=none;
git add .;
git commit -m '`git rev-parse HEAD`';
git push origin;
```

```bash title="ローカル起動"
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```