{# raw_place の入れ子の列を平坦化した日本の POI。列の選び方は place.table.yml。
   位置から、メッシュコード、施設が入る市区町村の地方公共団体コード、施設が入る建物の
   building_id を付ける。市区町村の決め方は buildings.building と同じで、政令市は区を採る。
   結合で raw_place の並びが崩れるので、近い場所の行が同じ行グループに入るよう、最後に
   ヒルベルト曲線の順に並べ直す。地図の範囲や商圏で絞るクエリが行グループの統計で読み飛ばせる。
   既定の行グループ (122,880 行) だと、都心の 1km 四方 (約 1.5 万件) を引いても 25 のうち
   10 の行グループ (約 120 万行) にかかり、ブラウザの DuckDB が 60MB 余りを読む。8,192 行に
   切ると 9 つ (約 7 万行) で済む。16,384 行・4,096 行より読む量と往復の回数が少なかった。
   設定はスキーマに付ける。dbt は __dbt_tmp の名前で書いてから改名するので、テーブルに
   付けると書き出しに効かない。この設定は catalog に残り、places スキーマのほかの表
   (raw_place・category) にも効く。raw_place は place より先に書くので、設定が残った次の
   ビルドから効く (footer が約 0.15MB から 2.2MB、ファイルが約 3% 大きくなる)。
   hook を消しても元には戻らない。

   同じ施設が複数の行で入っていることがある（日本語名と英語名で別々に登録された店、
   改名や入れ替わりで前の店の行が残ったもの）。行は消さずに、重複と判定した行には残す側の id を
   duplicate_of に入れ、件数を数える用途で除く理由を exclude_reason に入れる。
   判定は次の 2 つのルールだけで、どちらにも当たらない重複は残る。
   - 電話番号: 正規化した先頭の番号が全国でちょうど 2 行にだけあり、2 行が 100m 以内で
     basic_category が同じ。百貨店や雑居ビルの代表番号は 3 行以上が持つので当たらない
   - 名称: 記号と空白を除いて小文字にした名称が同じで 50m 以内。電話番号が両方にあれば同じこと
   残す側は閉店・休業でない方、同じなら confidence が高い方、同じなら日本語の名称を持つ方、
   それも同じなら id の大きい方。営業中の行が閉店した行に付いて両方とも数から落ちないよう、営業状態を先に比べる。
   全行に順序が付くので、つながった重複の中で一番上の行は必ず残る。duplicate_of はその残る行を指す。 #}
{{ config(
    pre_hook="CALL {{ this.database }}.set_option('parquet_row_group_size', 8192, schema => '{{ this.schema }}')"
) }}

-- keyed・located_* と最後の select の 4 か所から読むので、実体化させずに読む側ごとに展開させる
with place as not materialized (
    select
        id,
        names.primary as name,
        -- 言語別の名前は names.rules の variant = 'language' に入る。names.common は
        -- 2026-09 のリリースでは日本の全行で NULL だが、スキーマ上は残っているので後ろで拾う
        coalesce(
            list_filter(names.rules, r -> r.variant = 'language' and r.language = 'ja')[1].value,
            names.common['ja']
        ) as name_ja,
        coalesce(
            list_filter(names.rules, r -> r.variant = 'language' and r.language = 'en')[1].value,
            names.common['en']
        ) as name_en,
        basic_category,
        taxonomy.primary as taxonomy_primary,
        array_to_string(taxonomy.hierarchy, ' > ') as taxonomy_hierarchy,
        confidence,
        operating_status,
        brand.names.primary as brand_name,
        brand.wikidata as brand_wikidata,
        addresses[1].freeform as address,
        addresses[1].locality as address_locality,
        addresses[1].region as address_region,
        addresses[1].postcode as postal_code,
        array_to_string(phones, ' ') as phones,
        -- 重複の判定にだけ使う。1 つの番号の中にも空白がある（+81 3-…）ので、つないだ phones からは切り出せない
        phones[1] as first_phone,
        array_to_string(websites, ' ') as websites,
        array_to_string(list_sort(list_distinct(list_transform(sources, s -> s.dataset))), ', ')
            as source_datasets,
        array_to_string(list_sort(list_distinct(list_transform(sources, s -> s.license))), ', ')
            as source_licenses,
        st_y(geometry) as latitude,
        st_x(geometry) as longitude,
        geometry,
        release
    from {{ ref('raw_place') }}
),

-- 重複の判定に使うキー。place を何度も展開しないよう、ここで一度だけ実体化する
keyed as materialized (
    select
        id,
        confidence,
        operating_status in ('permanently_closed', 'temporarily_closed') as is_closed,
        basic_category,
        latitude,
        longitude,
        regexp_matches(name, '[\p{Hiragana}\p{Katakana}\p{Han}]') as has_ja_name,
        nullif(regexp_replace(lower(name), '[\s\p{Z}\p{P}\p{S}]', '', 'g'), '') as name_key,
        -- 国番号付き（+81 3-…）と国内表記（03-…）をそろえる
        nullif(regexp_replace(regexp_replace(first_phone, '[^0-9]', '', 'g'), '^81', '0'), '')
            as phone_key,
        -- 名称の突き合わせを近くの行に限るための約 100m の格子
        floor(latitude * 1000)::bigint as cell_y,
        floor(longitude * 1000)::bigint as cell_x
    from place
),

ranked as (
    -- 残す側の順。閉店・休業でないか、confidence、日本語の名称を持つか、id の順に比べる
    select *, (not coalesce(is_closed, false), confidence, has_ja_name, id) as keep_rank
    from keyed
),

paired_phone as (
    select phone_key
    from keyed
    where phone_key is not null
    group by phone_key
    having count(*) = 2
),

-- 代表番号のように多くの行が持つ番号で自己結合が膨らまないよう、先に 2 行だけの番号に絞る
phone_candidate as (
    select *
    from ranked
    semi join paired_phone using (phone_key)
),

same_phone as (
    select a.id, a.keep_rank, b.id as other_id, b.keep_rank as other_rank
    from phone_candidate as a
    join phone_candidate as b using (phone_key)
    where a.id <> b.id
        and a.basic_category = b.basic_category
        and st_distance_sphere(st_point(a.latitude, a.longitude), st_point(b.latitude, b.longitude)) < 100
),

same_name as (
    -- 隣り合う格子まで見れば 50m 以内は漏れない
    select a.id, a.keep_rank, b.id as other_id, b.keep_rank as other_rank
    from ranked as a
    cross join (values (-1), (0), (1)) as dy(d)
    cross join (values (-1), (0), (1)) as dx(d)
    join ranked as b
        on b.name_key = a.name_key
        and b.cell_y = a.cell_y + dy.d
        and b.cell_x = a.cell_x + dx.d
    where a.id <> b.id
        and (a.phone_key is null or b.phone_key is null or a.phone_key = b.phone_key)
        and st_distance_sphere(st_point(a.latitude, a.longitude), st_point(b.latitude, b.longitude)) < 50
),

-- 順位を組の側に持たせて結合せずに選ぶ。keyed と結合して比べると、オプティマイザが
-- keyed 同士の不等号結合を先に組み、全国では終わらない
nearest_keeper as (
    select id, arg_max(other_id, other_rank) as duplicate_of
    from (select * from same_phone union all select * from same_name) as pair
    where other_rank > keep_rank
    group by id
),

-- 選んだ行がさらに別の行の重複のことがある（電話番号の無い行が同名の行に付き、その行が
-- 電話番号で別の行に付くなど）。残す側を直接指すよう、3 段まで先へたどる
duplicate as (
    select
        n1.id,
        coalesce(n3.duplicate_of, n2.duplicate_of, n1.duplicate_of) as duplicate_of
    from nearest_keeper as n1
    left join nearest_keeper as n2 on n2.id = n1.duplicate_of
    left join nearest_keeper as n3 on n3.id = n2.duplicate_of
),

excluded as (
    select
        keyed.id,
        duplicate.duplicate_of,
        case
            when keyed.is_closed then 'closed'
            when duplicate.duplicate_of is not null then 'duplicate'
            when keyed.confidence < 0.5 then 'low_confidence'
        end as exclude_reason
    from keyed
    left join duplicate using (id)
),

municipality as (
    select local_government_code as lg_code, subtype = 'macrohood' as is_ward, geometry
    from {{ ref('division_area') }}
    where is_municipality and is_land
),

located_municipality as (
    select place.id, arg_max(municipality.lg_code, municipality.is_ward) as lg_code
    from place
    join municipality on st_contains(municipality.geometry, place.geometry)
    group by place.id
),

located_building as (
    -- 外形が重なる建物に入るときは、小さい方（内側の建物）を採る
    select place.id, arg_min(building.building_id, building.area_m2) as building_id
    from place
    join {{ ref('building') }} as building on st_contains(building.geometry, place.geometry)
    group by place.id
)

select
    place.* exclude (first_phone, geometry, release),
    left(located_municipality.lg_code, 2) as prefecture_code,
    located_municipality.lg_code as local_government_code,
    located_building.building_id,
    {{ jis_mesh1('place.longitude', 'place.latitude') }} as mesh1,
    {{ jis_mesh2('place.longitude', 'place.latitude') }} as mesh2,
    {{ jis_mesh3('place.longitude', 'place.latitude') }} as mesh3,
    excluded.duplicate_of,
    excluded.exclude_reason,
    place.geometry,
    place.release
from place
left join located_municipality using (id)
left join located_building using (id)
left join excluded using (id)
order by st_hilbert(place.longitude, place.latitude, {'min_x': 122.0, 'min_y': 20.0, 'max_x': 154.5, 'max_y': 46.0}::box_2d)
