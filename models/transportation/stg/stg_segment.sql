{# raw_segment の列を、道路網の辺を作るのに使う形にしたもの。区間全体に効く道路の属性と最高速度を取り出す。 #}

select
    id,
    class,
    subclass,
    geometry,
    st_transform(geometry, 'EPSG:4326', 'EPSG:3395', true) as geometry_merc,
    release,
    coalesce(access_restrictions, []) as rules,
    list_distinct(flatten(list_transform(
        list_filter(coalesce(road_flags, []), f -> f.between is null), f -> f.values
    ))) as flags,
    list_filter(coalesce(speed_limits, []),
        s -> s.between is null and s.when is null and s.max_speed is not null
    )[1].max_speed as max_speed,
    connectors
from {{ ref('raw_segment') }}
