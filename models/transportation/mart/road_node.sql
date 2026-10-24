{# 道路網の節点（交差点と道の端）。road_edge の from_node / to_node が指す。
   node_id は 2 次メッシュ順に振り直した整数で、Overture の版が変わると振り直しになる。 #}

with node as (
    select
        id as gers_id,
        st_x(geometry) as lon,
        st_y(geometry) as lat,
        geometry
    from {{ ref('raw_connector') }}
)

select
    row_number() over (order by {{ jis_mesh2('lon', 'lat') }}, gers_id) as node_id,
    gers_id,
    lon,
    lon as longitude,
    lat,
    lat as latitude,
    {{ jis_mesh1('lon', 'lat') }} as mesh1,
    {{ jis_mesh2('lon', 'lat') }} as mesh2,
    geometry
from node
order by node_id
