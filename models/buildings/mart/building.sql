{# 日本の建物。1行が1棟。raw_building の主な列を平坦化し、位置からメッシュコードと
   地方公共団体コードを付ける。
   コードは外形の重心が入る市区町村のポリゴン（divisions.division_area）から引く。政令市は
   市と区のポリゴンが重なるので区を採る。どの市区町村にも入らない建物（海上の施設、
   ポリゴンの隙間）は NULL になる。 #}

-- located と最後の select の 2 か所から読むので、そのままだと外形ごと全棟を一度実体化する。
-- located が読むのは building_id と重心だけなので、実体化させずに読む側ごとに展開させる
with building as not materialized (
    select
        id as building_id,
        subtype,
        class,
        names.primary as name,
        height,
        num_floors,
        num_floors_underground,
        min_height,
        is_underground,
        has_parts,
        roof_shape,
        sources[1].dataset as source_dataset,
        -- st_area_spheroid は緯度・経度の順の座標を受け取るので入れ替えて渡す（そのままだと NaN になる）
        st_area_spheroid(st_flipcoordinates(geometry)) as area_m2,
        st_centroid(geometry) as centroid,
        geometry,
        release
    from {{ ref('raw_building') }}
),

municipality as (
    select lg_code, subtype = 'macrohood' as is_ward, geometry
    from {{ ref('division_area') }}
    where is_municipality and is_land
),

located as (
    -- 都道府県コードは別の arg_max で取らず lg_code の先頭 2 桁から出す。同じ is_ward の
    -- ポリゴンに重なって入る建物では、arg_max ごとに違う行を選んで両者が食い違いうる
    select
        building.building_id,
        arg_max(municipality.lg_code, municipality.is_ward) as lg_code
    from building
    join municipality on st_contains(municipality.geometry, building.centroid)
    group by building.building_id
)

select
    building.building_id,
    building.subtype,
    building.class,
    building.name,
    building.height,
    building.num_floors,
    building.num_floors_underground,
    building.min_height,
    building.is_underground,
    building.has_parts,
    building.roof_shape,
    building.source_dataset,
    building.area_m2,
    left(located.lg_code, 2) as pref_code,
    located.lg_code,
    st_x(building.centroid) as lon,
    st_y(building.centroid) as lat,
    {{ jis_mesh1('st_x(building.centroid)', 'st_y(building.centroid)') }} as mesh1,
    {{ jis_mesh2('st_x(building.centroid)', 'st_y(building.centroid)') }} as mesh2,
    {{ jis_mesh3('st_x(building.centroid)', 'st_y(building.centroid)') }} as mesh3,
    building.geometry,
    building.release
from building
left join located using (building_id)
order by mesh3, building.building_id
