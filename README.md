# dataset-overturemaps

[Overture Maps Foundation](https://overturemaps.org/) が公開するオープンな地図データのうち、
places テーマの日本の POI、transportation テーマの日本の道路網、divisions テーマの日本の行政区画を Queria のカタログ
（[data.queria.io](https://data.queria.io/)）へ取り込むデータセットです。

## データ出典

Overture は月1回ほどリリースを出し、古いリリースは数か月で配布元から消えます。版を固定せず、
ビルドのたびに配布元のバケット（`s3://overturemaps-us-west-2/release/`）を一覧して最新のリリースを
取ります。取り込んだリリース名は `release` 列に入ります。

places テーマのうち、住所の国コードが JP のレコードだけを取り出します。外接矩形だけで絞ると
韓国・ロシア極東・中国の一部が混ざるためです。

提供元ごとにライセンスが違い、各レコードの `source_licenses` 列がそのレコードのライセンスを示します。

| 提供元 | ライセンス | 件数 |
| --- | --- | ---: |
| Meta・Microsoft・PinMeTo・DAC など | CDLA-Permissive-2.0 | 全件（Overture 自身の分を含む） |
| AllThePlaces | CC0-1.0 | 約 37 万 |
| Foursquare | Apache-2.0 | 約 33 万 |

transportation テーマと divisions テーマは OpenStreetMap 由来で、[ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)
が適用されます（© OpenStreetMap contributors）。divisions の一部の区画は geoBoundaries と Esri Community Maps
contributors（どちらも CC BY 4.0）に由来します。このデータセットの `transportation` スキーマと `divisions`
スキーマも同じ ODbL で提供します。

Foursquare 由来のデータには [NOTICE](https://opensource.foursquare.com/places-notice-txt/) が
適用されます。全文と Queria による変更の通知は `dataset.yml` の説明に載せてあり、カタログの
データセットページに表示されます。

## 収録テーブル

| テーブル | 内容 | 行数 |
| --- | --- | ---: |
| `places.place` | 日本の POI。1行が1施設。主な列を平坦化してある | 2,914,402 |
| `places.raw_place` | 同じ行を Overture のスキーマのまま全列で持つ | 2,914,402 |
| `transportation.road_edge` | 道路網の辺。道路を交差点ごとに区切った1本が1行 | 18,610,451 |
| `transportation.road_node` | 道路網の節点（交差点と道の端） | 13,333,294 |
| `transportation.raw_segment` | 道路区間を Overture のスキーマのまま全列で持つ | 13,067,844 |
| `transportation.raw_connector` | `raw_segment` が参照する接続点を Overture のスキーマのまま | 13,333,294 |
| `divisions.division` | 都道府県・市区町村・町丁・字の代表点。地方公共団体コード付き | 221,245 |
| `divisions.division_area` | 同じ区画のポリゴン。地方公共団体コード付き | 27,368 |
| `divisions.raw_division` | `division` を Overture のスキーマのまま全列で持つ | 221,245 |
| `divisions.raw_division_area` | `division_area` を Overture のスキーマのまま全列で持つ | 27,368 |

`place` に無い情報（名前の言語別・別名、副カテゴリ、SNS・メールアドレス、2件目以降の住所、
提供元ごとの元レコード ID と更新時刻など）は `raw_place` にあります。列の意味は
[Overture のスキーマ](https://docs.overturemaps.org/schema/reference/places/place/)を見てください。

places の行数はリリース 2026-09-23.1、transportation と divisions の行数はリリース 2026-10-21.0 の実測です。

カテゴリは Overture 独自の英語の分類で、`basic_category`（262種）、`taxonomy_primary`（1,415種）、
`taxonomy_hierarchy`（最大6段）の3つの粒度があります。同じ業態でも施設によって付いている粒度が
違うので、細かいカテゴリで数えると取りこぼします。

`operating_status`（営業状態）はほとんどのレコードで空です。閉店した施設を除く用途には使えません。

## 道路網（transportation）

`road_edge` と `road_node` は、経路や到達圏（徒歩 10 分圏など）をそのまま計算できる形にしたものです。

- Overture の区間は交差点をまたいで続くので、他の道とつながる点（connector）ごとに区切り直しています。
  `from_node` / `to_node` が `road_node.node_id` を指します
- 徒歩・自転車・車で通れるか（`walk` / `bike` / `car_forward` / `car_backward`）は道路の種類で決め、
  Overture の `access_restrictions` のうち区間全体に効く条件なしの規則で上書きしています。時間帯や車種の
  条件付きの規制と、区間の一部だけに効く規制は反映していません。一方通行は車にだけ効かせています
- 行は JIS X 0410 の 2 次メッシュ（約 10km 四方）の順に並んでいます。`mesh2` で絞ると、DuckDB は
  そのメッシュを含む行グループだけを読みます（2026-10-21.0 では 1 メッシュあたり 152 のうち 2 つ）
- `node_id` と `edge_id` は Overture のリリースごとに振り直します。リリースをまたいで同じ道を追うときは
  `gers_id` を使ってください

```sql
-- 東京駅のまわり（2 次メッシュ 533946）で、徒歩で通れる道
select edge_id, from_node, to_node, length_m
from overturemaps.transportation.road_edge
where mesh2 = 533946 and walk
```

## 行政区画（divisions）

`division` と `division_area` は、Overture の区画（GERS ID）と総務省の地方公共団体コードの対応表を兼ねています。
Overture の区画はコードを持たないので、都道府県名と市区町村名を Queria の `lg_code` データセット
（総務省「全国地方公共団体コード」）と照合して付けています。

- 市区町村そのものの行は `is_municipality` が true。市町村・東京の特別区は `subtype = locality`、政令市の区は
  `macrohood` です。政令市は市の行と区の行の両方にコードが付きます
- 町丁・字（`neighborhood` / `microhood`）には、階層をさかのぼって最初に見つかった市区町村（政令市なら区）の
  コードが入ります
- `county` は geoBoundaries 由来のローマ字名の区画で、市区町村とほぼ同じ範囲ですがコードは付けていません
- リリース 2026-10-21.0 で照合できなかったのは、北方領土の 6 村（照合から外している）と、Overture に区画の無い
  飛騨市くらいです。照合できた市区町村が 1,850 を下回るとビルドが落ちます（`tests/division_lg_code_coverage.sql`）

POI や建物の位置を `division_area` に当てると、市区町村コードを持つ他のデータセットと結合できます。

```sql
-- 日野駅の位置が入る市区町村と町丁
select subtype, name, lg_code
from overturemaps.divisions.division_area
where is_land and st_contains(geometry, st_point(139.3948, 35.6795))
```
