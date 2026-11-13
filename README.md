# Overture Maps

[Overture Maps Foundation](https://overturemaps.org/) が公開するオープンな地図データのうち、日本の POI（places テーマ）、道路網（transportation テーマ）、行政区画（divisions テーマ）、建物（buildings テーマ）、設備と土地利用（base テーマの infrastructure・land_use）を、SQL で集計・地図表示できるテーブルにしたデータセットです。毎月、Overture の最新リリースから取得し直します。

位置から市区町村の地方公共団体コードとメッシュコードを付けているため、市区町村コードやメッシュを持つ他のデータセットと結合できます。

## 出典と利用条件

出典: Overture Maps Foundation, overturemaps.org（[帰属表示](https://docs.overturemaps.org/attribution/)）

Overture は月 1 回ほどリリースを出し、古いリリースは数か月で配布元から消えます。リリースを固定せず、ビルドのたびに配布元のバケット（`s3://overturemaps-us-west-2/release/`）を一覧して最新のリリースを取得します。取り込んだリリース名は `release` 列に入ります。

提供元ごとにライセンスが違います。

| テーマ・提供元 | ライセンス |
| --- | --- |
| places の Meta・Microsoft・PinMeTo・DAC など（全件、Overture 自身の分を含む） | CDLA-Permissive-2.0 |
| places の AllThePlaces（約 37 万件） | CC0-1.0 |
| places の Foursquare（約 33 万件） | Apache-2.0 |
| transportation・base（OpenStreetMap 由来） | [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)（© [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)） |
| divisions（OpenStreetMap 由来。一部は [geoBoundaries](https://www.geoboundaries.org/) と Esri Community Maps contributors の CC BY 4.0） | ODbL 1.0 |
| buildings（OpenStreetMap、Microsoft の Global ML Building Footprints、Shi らの推定 doi:10.5281/zenodo.8174931 の CC BY 4.0） | ODbL 1.0 |

- places の各レコードの `source_licenses` 列が、そのレコードに適用されるライセンスを示します
- ODbL のもとで、このデータセットの `transportation`・`divisions`・`buildings`・`base` スキーマも同じ ODbL で提供します
- divisions の地方公共団体コードは、総務省「全国地方公共団体コード」（Queria の lg_code データセット経由、政府標準利用規約 第2.0版）と照合して付けています

### Foursquare の NOTICE

Foursquare 由来のデータ（`source_licenses` に Apache-2.0 を含むレコード）には、次の [NOTICE](https://opensource.foursquare.com/places-notice-txt/) が適用されます。

```text
© 2026 Foursquare Labs, Inc. All rights reserved.
The Foursquare OS Places dataset (the "Data") is licensed under the Apache License, Version 2.0 (the "License"). You may not use, modify, or distribute the Data except in compliance with the License.
As set forth more fully in the License, if you use, modify, or distribute the Data, you must: provide recipients with a copy of the License; if applicable, include prominent notices to the extent you've changed the Data; preserve attribution to Foursquare, including preserving the full content of this NOTICE.txt file.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0. Unless required by applicable law or agreed to in writing, the Data distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
```

Queria による変更の通知: Overture Maps Foundation が Overture のスキーマへ変換した Foursquare 由来データについて、Queria は日本のレコードの抽出と、`places.place` での列の選択と平坦化を行いました。

## テーブル

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

places の行数はリリース 2026-09-23.1、transportation と divisions の行数はリリース 2026-10-21.0 の実測です。buildings と base の行数は同じリリースを 0.05 度の格子で数えた概数で、初回のビルドで確定します。

## POI（places）

places テーマのうち、住所の国コードが JP のレコードだけを取り出します。外接矩形だけで絞ると韓国・ロシア極東・中国の一部が混ざるためです。`place` は主な列を平坦化したもので、`raw_place` は Overture のスキーマのまま全列を持ちます。

`place` には位置から、施設が入る市区町村の地方公共団体コード（`local_government_code`、政令市は区）、都道府県コード、メッシュコード（`mesh1` / `mesh2` / `mesh3`）、施設が入る建物の `building_id` を付けています。住所の `address_region` は多くの行で空なので、地域で絞るときはこちらを使ってください。東京周辺で試したところ、施設の約 7 割が建物の中に入りました。建物の外にある施設（駐車場・公園・ATM など）や、外形のない建物の中の施設は `building_id` が NULL です。外形が重なる建物では小さい方の建物を付けます。

### 重複と閉店

同じ施設が複数の行で入っていることがあります（日本語名と英語名で別々に登録された店、改名や入れ替わりで前の店の行が残ったもの）。`place` は行を消さずに、重複と判定した行の `duplicate_of` に残す側の行の `id` を、件数を数えるときに除く理由を `exclude_reason` に入れています。店や施設を数えるときは `exclude_reason IS NULL` に絞ってください。

- 重複の判定は 2 つです。正規化した先頭の電話番号が全国で 2 行にだけあり、100m 以内で `basic_category` が同じもの。記号と空白を除いた名称が同じで 50m 以内、電話番号が両方にあれば同じもの
- 残す側は閉店・休業でない方、同じなら `confidence` が高い方、それも同じなら日本語の名称を持つ方です
- `exclude_reason` は `closed`（`operating_status` が閉店・休業）、`duplicate`（`duplicate_of` が入っている）、`low_confidence`（`confidence` が 0.5 未満。撤退した店を多く含む）です。複数当たるときはこの順で先のものです
- 判定は電話番号と名称の一致だけで、これに当たらない重複や、閉店していても Overture に残っている店は数に入ったままです
- `operating_status`（営業状態）はほとんどのレコードで空です。閉店した施設を除く用途には使えません

### カテゴリ

カテゴリは Overture 独自の英語の分類で、`basic_category`（262 種）、`taxonomy_primary`（1,415 種）、`taxonomy_hierarchy`（最大 6 段）の 3 つの粒度があります。同じ業態でも施設によって付いている粒度が違うので、細かいカテゴリで数えると取りこぼします。

`places.category` は、Overture の分類を日本標準産業分類（第14回改定）の大分類・中分類、OpenStreetMap のタグ、無人の設備かに対応させた表です。Queria が分類の名前と中身から手で当てたもので、公式の対応ではありません。正本はリポジトリの `reference/places/category.csv` です。

- 1 行が `basic_category` ごとの既定の行（`taxonomy_primary` が NULL）か、その中で行き先の違う `taxonomy_primary` の行です（パン屋は飲食店でなく飲食料品小売業、郵便局は複合サービス事業、など）
- `place` に当てるときは、`basic_category` と `taxonomy_primary` の両方が合う行があればそちらを、なければ既定の行を使います。`taxonomy_primary` の行の空の値は既定の行を打ち消します（ATM の産業分類を空にするなど）
- 産業分類の名前は e_stat の `code.industry`（`revision = 2023`、`level` が `'major'` か `'middle'`）を `code` で引きます。山・川・公園・ATM・駐車場のように事業所でないものと、分類の粗さで当てられないものは NULL です。Overture の分類は事業所の業態を名前と提供元から推定したもので、統計調査の格付けとは一致しないことがあります
- `osm_tag` は施設の種類に当たる OpenStreetMap の主なタグを「キー=値」で 1 つ持ちます。alltheplaces データセットのように OpenStreetMap のタグで分類する施設のデータと照合するときに使います
- `is_unattended` は ATM・自動販売機・宅配ロッカー・駐車場・公衆トイレ・EV 充電器など、人のいない設備で true です。店舗として数えるときは false の分類に絞ってください

`place` にない情報（名前の言語別・別名、副カテゴリ、SNS・メールアドレス、2 件目以降の住所、提供元ごとの元レコード ID と更新時刻など）は `raw_place` にあります。列の意味は [Overture のスキーマ](https://docs.overturemaps.org/schema/reference/places/place/)を見てください。

## 道路網（transportation）

`road_edge` と `road_node` は、経路や到達圏（徒歩 10 分圏など）をそのまま計算できる形にしたものです。

- Overture の区間は交差点をまたいで続くので、他の道とつながる点（connector）ごとに区切り直しています。
  `from_node` / `to_node` が `road_node.node_id` を指します
- 徒歩・自転車・車で通れるか（`walk` / `bike` / `car_forward` / `car_backward`）は道路の種類で決め、
  Overture の `access_restrictions` のうち区間全体に効く条件なしの規則で上書きしています。時間帯や車種の
  条件付きの規制と、区間の一部だけに効く規制は反映していません。一方通行は車にだけ効かせています
- 行は JIS X 0410 の 2 次メッシュ（約 10km 四方）の順に並んでいます。`mesh2` で絞ると、DuckDB は
  そのメッシュを含む行グループだけを読みます（2026-10-21.0 では 1 メッシュあたり 152 のうち 2 つ）
- 既定では、徒歩は motorway 以外、自転車は motorway・footway・steps・pedestrian 以外を通れるとしています。`car_forward` と `car_backward` のどちらか片方だけが true なら一方通行です。規制速度（`speed_limit_kmh`）は区間全体に効く条件なしの最高速度で、生活道路ではほとんど NULL です
- 線の `mesh2` は中点が入るメッシュです。メッシュをまたぐ線は中点の側に入るため、境界付近の経路を出すときは隣のメッシュも読んでください
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
- `is_municipality` が true の行は 1 つのコードに 1 行だけです。同じ市区町村が点だけの行とポリゴンを持つ行の 2 行で載っているときは、ポリゴンを持つ方が true です
- 5 桁のコードと結合するときは、`local_government_code` の先頭 5 桁を使います
- `division_area` は、陸地だけの形（`is_land`）と領海を含む形（`is_territorial`）が別の行になることがあります。点を当てるときはどちらかに絞ってください
- `county` は geoBoundaries 由来のローマ字名の区画で、市区町村とほぼ同じ範囲ですがコードは付けていません
- リリース 2026-10-21.0 で照合できなかったのは、北方領土の 6 村（照合から外している）と、Overture に区画の無い
  飛騨市です。照合できた市区町村が 1,700、政令市の区が 160 を下回るとビルドが落ちます
  （`tests/division_lg_code_coverage.sql`）
- 政令市の区のコードは、`lg_code` データセットの `code_type = 'ward'` の行（総務省の一覧の 2 枚目のシート）から
  取ります
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

## ビルド

```bash
git submodule update --init
uv sync
scripts/build.sh   # fdl checkout → python main.py → fdl commit
```

毎月 GitHub Actions の Sync が実行され、最新のリリースを取り込みます。
