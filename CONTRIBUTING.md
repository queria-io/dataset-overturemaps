# ビルドと更新

データセットの概要は [README.md](README.md) にあります。ここにはこのリポジトリでデータセットをビルド・更新する手順を書きます。

## ビルド

```bash
git clone https://github.com/queria-io/dataset-shared.git shared  # 更新は git -C shared pull
uv sync
scripts/build.sh   # fdl checkout → python main.py → fdl commit
```

毎月 GitHub Actions の Sync が実行され、最新のリリースを取り込みます。
