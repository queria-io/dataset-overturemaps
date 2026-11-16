{# raw_land_use の主な列を平坦化し、面積と代表点を足したもの。 #}

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
