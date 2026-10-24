# dataset-overturemaps

[Overture Maps Foundation](https://overturemaps.org/) が公開するオープンな地図データのうち、
places テーマの日本の POI、transportation テーマの日本の道路網、divisions テーマの日本の行政区画、buildings テーマの日本の建物、base テーマの日本の設備（infrastructure）と土地利用（land_use）を Queria のカタログ
（[data.queria.io](https://data.queria.io/)）へ取り込むデータセットです。

## データ出典

Overture は月1回ほどリリースを出し、古いリリースは数か月で配布元から消えます。版を固定せず、
ビルドのたびに配布元のバケット（`s3://overturemaps-us-west-2/release/`）を一覧して最新のリリースを
取ります。取り込んだリリース名は `release` 列に入ります。

places テーマのうち、住所の国コードが JP のレコードだけを取り出します。外接矩形だけで絞ると
韓国・ロシア極東・中国の一部が混ざるためです。

`place` には位置から、施設が入る市区町村の地方公共団体コード（`local_government_code`、政令市は区）、都道府県コード、
メッシュコード（`mesh1` / `mesh2` / `mesh3`）、施設が入る建物の `building_id` を付けています。住所の `address_region` は
多くの行で空なので、地域で絞るときはこちらを使ってください。東京周辺で試したところ、施設の約 7 割が建物の中に
入りました。建物の外にある施設（駐車場・公園・ATM など）や、外形の無い建物の中の施設は `building_id` が NULL です。

提供元ごとにライセンスが違い、各レコードの `source_licenses` 列がそのレコードのライセンスを示します。

| 提供元 | ライセンス | 件数 |
| --- | --- | ---: |
| Meta・Microsoft・PinMeTo・DAC など | CDLA-Permissive-2.0 | 全件（Overture 自身の分を含む） |
| AllThePlaces | CC0-1.0 | 約 37 万 |
| Foursquare | Apache-2.0 | 約 33 万 |

transportation テーマと divisions テーマは OpenStreetMap 由来で、[ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)
が適用されます（© OpenStreetMap contributors）。divisions の一部の区画は geoBoundaries と Esri Community Maps
contributors（どちらも CC BY 4.0）に由来します。このデータセットの `transportation` スキーマと `divisions`
スキーマ、buildings スキーマも同じ ODbL で提供します。buildings は OpenStreetMap、Microsoft の
Global ML Building Footprints（ODbL）、Shi らの推定（Zenodo、CC BY 4.0）に由来します。

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
| `buildings.building` | 建物の外形。1行が1棟。高さ・階数とメッシュ・地方公共団体コード付き | 約 5,400 万 |
| `buildings.building_part` | 建物の部分（高層部など）。`building_id` で `building` を指す | 約 14 万 |
| `buildings.raw_building` | `building` を Overture のスキーマのまま全列で持つ | 約 5,400 万 |
| `buildings.raw_building_part` | `building_part` を Overture のスキーマのまま全列で持つ | 約 14 万 |
| `base.infrastructure` | バス停・信号・駐車場・橋などの設備。1行が1地物。メッシュ・地方公共団体コード付き | 約 350 万 |
| `base.raw_infrastructure` | `infrastructure` を Overture のスキーマのまま全列で持つ | 約 350 万 |
| `base.land_use` | 住宅地・農地・公園などの土地利用の区画。1行が1区画。面積・メッシュ・地方公共団体コード付き | 約 190 万 |
| `base.raw_land_use` | `land_use` を Overture のスキーマのまま全列で持つ | 約 190 万 |

`place` に無い情報（名前の言語別・別名、副カテゴリ、SNS・メールアドレス、2件目以降の住所、
提供元ごとの元レコード ID と更新時刻など）は `raw_place` にあります。列の意味は
[Overture のスキーマ](https://docs.overturemaps.org/schema/reference/places/place/)を見てください。

places の行数はリリース 2026-09-23.1、transportation と divisions の行数はリリース 2026-10-21.0 の実測です。buildings と base の行数は同じリリースを 0.05 度の格子で数えた概数で、初回のビルドで確定します。

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
  飛騨市です。照合できた市区町村が 1,700 を下回るとビルドが落ちます（`tests/division_lg_code_coverage.sql`）
- いまの `lg_code` データセットは政令市の区のコードを持っていません（総務省の一覧の 2 枚目のシートにあり、
  まだ取り込んでいない）。そのため区の区画にはコードが付かず、政令市の中の町丁と建物には市のコードが入ります。
  `lg_code` に区が入れば、作り直すだけで区のコードに変わります
- 区の再編（浜松市は 2024 年に 7 区から 3 区へ）があると、一覧と Overture の片方だけが新しい間は、合わない区に
  区のコードが付かず、その中の町丁には市のコードが入ります。件数の下限ではこの取りこぼしは検出できません

POI や建物の位置を `division_area` に当てると、市区町村コードを持つ他のデータセットと結合できます。

```sql
-- 日野駅の位置が入る市区町村と町丁
select subtype, name, local_government_code
from overturemaps.divisions.division_area
where is_land and st_contains(geometry, st_point(139.3948, 35.6795))
```

## 建物（buildings）

`building` は外形の重心からメッシュコード（`mesh1` / `mesh2` / `mesh3`）と、重心が入る市区町村の地方公共団体コード
（`divisions.division_area` から引いたもの。政令市は区）を付けています。行は 3 次メッシュ（約 1km 四方）の順に並んで
いるので、`mesh2` や `mesh3` で絞ると必要な行グループだけを読みます。

- 提供元は OpenStreetMap（約 3,000 万棟）、Microsoft ML Buildings（約 2,100 万棟）、Shi らの推定（約 310 万棟）。
  高さや階数を持つのは OSM 由来の一部（約 420 万棟）だけで、機械学習由来の建物は外形しか持ちません
- `building_id` は Overture の GERS ID で、リリースをまたいでも同じ建物には同じ ID が付きます
- `area_m2` は外形の面積を楕円体の上で測ったものです

```sql
-- 3 次メッシュごとの建物数と高さの分かる建物の数（東京駅のまわり）
select mesh3, count(*) as buildings, count(height) as with_height
from overturemaps.buildings.building
where mesh2 = 533946
group by mesh3
```

## 設備（base の infrastructure）

`infrastructure` は OpenStreetMap 由来の設備で、点（バス停・信号・ベンチ・自動販売機など）、線（送電線・柵など）、
面（駐車場・橋など）が混ざります。地物の上に取った代表点（`longitude` / `latitude`）からメッシュコードと、代表点が入る
市区町村の地方公共団体コードを付けています。種類は `subtype`（大分類）と `class`（細かい分類）で絞ります。

- 東京周辺の 52 万件で多かった `class` は、横断歩道（crossing）、駐車場（parking）、一時停止の標識（stop）、橋（bridge）、
  信号（traffic_signals）、バス停（bus_stop）の順でした
- OpenStreetMap に描かれたものだけなので、地域によって網羅の度合いが違います。件数を地域で比べるときは注意してください
- base テーマの GERS ID（`infrastructure_id`）は 2026-09 のリリースで全件振り直されました。ほかのテーマほど
  リリースをまたいで安定していません

```sql
-- 市区町村ごとのバス停と信号の数（東京都）
select local_government_code, count(*) filter (where class = 'bus_stop') as bus_stops,
    count(*) filter (where class = 'traffic_signals') as signals
from overturemaps.base.infrastructure
where prefecture_code = '13'
group by local_government_code
```

## 土地利用（base の land_use）

`land_use` は OpenStreetMap に描かれた土地利用の区画で、ほぼすべてが面です。`infrastructure` と同じく代表点から
メッシュコードと地方公共団体コードを付け、外形から面積（`area_m2`）を測っています。

- 東京周辺の 12 万件で多かった `class` は、農地（farmland）、住宅地（residential）、公園（park）、草地（grass）、
  運動場（pitch）の順でした
- 描かれている範囲は地域によって差が大きく、日野市では住宅地の区画が合わせて 42ha しかありません。市区町村全体の
  土地利用の割合を出す用途には向きません。公園・学校・墓地・工業地のように輪郭のはっきりした区画を数える用途が向いています
- 大きな区画は市区町村の境をまたぐことがありますが、`local_government_code` は代表点の市区町村の 1 つだけです

```sql
-- 市区町村ごとの公園の数と面積（東京都）
select local_government_code, count(*) as parks, round(sum(area_m2) / 1e4, 1) as park_ha
from overturemaps.base.land_use
where prefecture_code = '13' and class = 'park'
group by local_government_code
```
