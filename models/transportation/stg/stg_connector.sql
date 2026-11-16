{# raw_connector の id と位置。 #}

select
    id as gers_id,
    st_x(geometry) as longitude,
    st_y(geometry) as latitude,
    geometry
from {{ ref('raw_connector') }}
