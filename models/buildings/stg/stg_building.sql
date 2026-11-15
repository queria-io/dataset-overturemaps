{# raw_building の主な列を平坦化し、面積と重心を足したもの。 #}

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
