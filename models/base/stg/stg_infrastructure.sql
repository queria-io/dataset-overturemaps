{# raw_infrastructure の主な列を平坦化し、代表点を足したもの。 #}

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
