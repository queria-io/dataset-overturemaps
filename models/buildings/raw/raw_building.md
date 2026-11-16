---
$schema: https://queria.io/schemas/table/v1.json
table: buildings.raw_building
title: 日本の建物（Overture のスキーマのまま）
description: |-
  buildings.building と同じ建物を、Overture のスキーマのまま全列で持ちます。外壁・屋根の色や素材などはここにあります。

  - 列の意味は Overture のスキーマのリファレンスを参照してください
  - release 列だけは Queria が追加した、取り込み元のリリース名です
keywords:
  - 建物
  - GIS
  - Overture Maps
sources:
  - path: https://docs.overturemaps.org/schema/reference/buildings/building/
primary_key: [id]
published: false
themes: [housing_land]
---
