---
$schema: https://queria.io/schemas/table/v1.json
table: base.raw_infrastructure
title: 日本の設備（Overture のスキーマのまま）
description: |-
  base.infrastructure と同じ地物を、Overture のスキーマのまま全列で持ちます。OpenStreetMap の元のタグ（source_tags）などはここにあります。

  - 列の意味は Overture のスキーマのリファレンスを参照してください
  - release 列だけは Queria が追加した、取り込み元のリリース名です
keywords:
  - インフラ
  - 設備
  - GIS
  - Overture Maps
sources:
  - path: https://docs.overturemaps.org/schema/reference/base/infrastructure/
primary_key: [id]
published: false
themes: [land_climate]
---
