{# raw_building_part の主な列を平坦化したもの。並べ替えに使う bbox も持つ。 #}

select
    id as part_id,
    building_id,
    names.primary as name,
    height,
    num_floors,
    num_floors_underground,
    min_height,
    min_floor,
    is_underground,
    roof_shape,
    sources[1].dataset as source_dataset,
    geometry,
    release,
    bbox
from {{ ref('raw_building_part') }}
