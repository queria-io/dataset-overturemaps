{# 日本の設備。1行が1地物で、点（バス停・信号・ベンチなど）、線（送電線・柵など）、面（駐車場・橋など）が
   混ざる。raw_infrastructure の主な列を平坦化し、代表点からメッシュコードと地方公共団体コードを付ける。
   代表点は st_pointonsurface で、線や面でも必ず地物の上に乗る。市区町村の決め方は buildings.building と
   同じで、政令市は区を採る。どの市区町村にも入らない地物（海上の設備など）は NULL になる。 #}

-- located と最後の select の 2 か所から読むので、実体化させずに読む側ごとに展開させる
with infrastructure as not materialized (
    select
        id as infrastructure_id,
        subtype,
        class,
        names.primary as name,
        level,
        height,
        surface,
        wikidata,
        sources[1].dataset as source_dataset,
        st_geometrytype(geometry)::varchar as geometry_type,
        st_pointonsurface(geometry) as point,
        geometry,
        release
    from {{ ref('raw_infrastructure') }}
),

municipality as (
    select lg_code, subtype = 'macrohood' as is_ward, geometry
    from {{ ref('division_area') }}
    where is_municipality and is_land
),

located as (
    select infrastructure.infrastructure_id, arg_max(municipality.lg_code, municipality.is_ward) as lg_code
    from infrastructure
    join municipality on st_contains(municipality.geometry, infrastructure.point)
    group by infrastructure.infrastructure_id
)

select
    infrastructure.* exclude (point, geometry, release),
    left(located.lg_code, 2) as pref_code,
    left(located.lg_code, 2) as prefecture_code,
    located.lg_code,
    located.lg_code as local_government_code,
    st_x(infrastructure.point) as lon,
    st_x(infrastructure.point) as longitude,
    st_y(infrastructure.point) as lat,
    st_y(infrastructure.point) as latitude,
    {{ jis_mesh1('st_x(infrastructure.point)', 'st_y(infrastructure.point)') }} as mesh1,
    {{ jis_mesh2('st_x(infrastructure.point)', 'st_y(infrastructure.point)') }} as mesh2,
    {{ jis_mesh3('st_x(infrastructure.point)', 'st_y(infrastructure.point)') }} as mesh3,
    infrastructure.geometry,
    infrastructure.release
from infrastructure
left join located using (infrastructure_id)
order by mesh3, infrastructure.infrastructure_id
