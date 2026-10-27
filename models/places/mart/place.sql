{# raw_place の入れ子の列を平坦化した日本の POI。列の選び方は place.table.yml。
   位置から、メッシュコード、施設が入る市区町村の地方公共団体コード、施設が入る建物の
   building_id を付ける。市区町村の決め方は buildings.building と同じで、政令市は区を採る。
   結合で raw_place の並びが崩れるので、近い場所の行が同じ行グループに入るよう、最後に
   ヒルベルト曲線の順に並べ直す。地図の範囲や商圏で絞るクエリが行グループの統計で読み飛ばせる。
   行グループの大きさは dbt_project.yml で places スキーマに付ける。 #}

-- located_* と最後の select の 3 か所から読むので、実体化させずに読む側ごとに展開させる
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
    place.* exclude (geometry, release),
    left(located_municipality.lg_code, 2) as prefecture_code,
    located_municipality.lg_code as local_government_code,
    located_building.building_id,
    {{ jis_mesh1('place.longitude', 'place.latitude') }} as mesh1,
    {{ jis_mesh2('place.longitude', 'place.latitude') }} as mesh2,
    {{ jis_mesh3('place.longitude', 'place.latitude') }} as mesh3,
    place.geometry,
    place.release
from place
left join located_municipality using (id)
left join located_building using (id)
order by st_hilbert(place.longitude, place.latitude, {'min_x': 122.0, 'min_y': 20.0, 'max_x': 154.5, 'max_y': 46.0}::box_2d)
