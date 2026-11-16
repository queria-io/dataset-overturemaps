---
$schema: https://queria.io/schemas/table/v1.json
table: buildings.raw_building_part
title: 日本の建物の部分（Overture のスキーマのまま）
description: |-
  buildings.building_part と同じ行を、Overture のスキーマのまま全列で持ちます。

  - 列の意味は Overture のスキーマのリファレンスを参照してください
  - release 列だけは Queria が追加した、取り込み元のリリース名です
keywords:
  - 建物
  - GIS
  - Overture Maps
sources:
  - path: https://docs.overturemaps.org/schema/reference/buildings/building_part/
primary_key: [id]
published: false
themes: [housing_land]
---
