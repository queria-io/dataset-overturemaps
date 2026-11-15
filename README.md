# dataset-overturemaps

Queria のデータセット `overturemaps`（Overture Maps）のリポジトリです。データセットの説明は [docs/index.md](docs/index.md) にあります。

## ビルド

```bash
git submodule update --init
uv sync
scripts/build.sh   # fdl checkout → python main.py → fdl commit
```

毎月 GitHub Actions の Sync が実行され、最新のリリースを取り込みます。
