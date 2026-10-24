{# 日本の土地利用。1行が1区画で、ほぼすべてが面（住宅地・農地・公園・学校の敷地・墓地など）。
   raw_land_use の主な列を平坦化して面積を足し、代表点からメッシュコードと地方公共団体コードを付ける。
   代表点は st_pointonsurface で、線や面でも必ず地物の上に乗る。市区町村の決め方は buildings.building と
   同じで、政令市は区を採る。どの市区町村にも入らない区画は NULL になる。
   大きな区画は市区町村の境をまたぐことがあるが、コードは代表点の市区町村の 1 つだけ。 #}

-- located と最後の select の 2 か所から読むので、実体化させずに読む側ごとに展開させる
with land_use as not materialized (
    select
        id as land_use_id,
        subtype,
        class,
        names.primary as name,
        level,
        surface,
        elevation,
        wikidata,
        sources[1].dataset as source_dataset,
        st_geometrytype(geometry)::varchar as geometry_type,
        -- st_area_spheroid は緯度・経度の順の座標を受け取るので入れ替えて渡す。線の区画は 0 になる
        st_area_spheroid(st_flipcoordinates(geometry)) as area_m2,
        st_pointonsurface(geometry) as point,
        geometry,
        release
    from {{ ref('raw_land_use') }}
),

municipality as (
    select lg_code, subtype = 'macrohood' as is_ward, geometry
    from {{ ref('division_area') }}
    where is_municipality and is_land
),

located as (
    select land_use.land_use_id, arg_max(municipality.lg_code, municipality.is_ward) as lg_code
    from land_use
    join municipality on st_contains(municipality.geometry, land_use.point)
    group by land_use.land_use_id
)

select
    land_use.* exclude (point, geometry, release),
    left(located.lg_code, 2) as pref_code,
    left(located.lg_code, 2) as prefecture_code,
    located.lg_code,
    located.lg_code as local_government_code,
    st_x(land_use.point) as lon,
    st_x(land_use.point) as longitude,
    st_y(land_use.point) as lat,
    st_y(land_use.point) as latitude,
    {{ jis_mesh1('st_x(land_use.point)', 'st_y(land_use.point)') }} as mesh1,
    {{ jis_mesh2('st_x(land_use.point)', 'st_y(land_use.point)') }} as mesh2,
    {{ jis_mesh3('st_x(land_use.point)', 'st_y(land_use.point)') }} as mesh3,
    land_use.geometry,
    land_use.release
from land_use
left join located using (land_use_id)
order by mesh3, land_use.land_use_id
