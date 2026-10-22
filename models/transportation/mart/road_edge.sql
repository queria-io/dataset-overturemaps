{# 道路網の辺。Overture の区間を、途中で他の道とつながる点（connector）ごとに区切った 1 本が 1 行。
   from_node から to_node へ向かう向きが、元の区間の線の向き（Overture の forward）になる。
   通れる手段は道路の種類で決め、access_restrictions の区間全体に効く規則で上書きする。
   一方通行は車にだけ効かせる（歩行者と自転車は両方向に通す）。
   connector の位置 at は WGS84 の楕円体の上で測った長さの比なので、経緯度のまま切ると
   東西と南北で縮尺が違うぶんずれる（東京で 1km あたり最大 90m ほど）。等角な楕円体メルカトル
   （EPSG:3395）に移して切り、経緯度に戻す。 #}

{% set car_modes = "['car', 'motor_vehicle', 'vehicle']" %}
{% set bike_modes = "['bicycle', 'vehicle']" %}
{% set walk_modes = "['foot']" %}

with segment as (
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
),

mode as (
    select
        *,
        -- 当てはまる規則があればその access_type（allowed / designated なら通れる）、無ければ道路の種類で決める
        coalesce(
            {{ access_rule('rules', walk_modes) }} <> 'denied',
            class <> 'motorway'
        ) as walk,
        coalesce(
            {{ access_rule('rules', bike_modes) }} <> 'denied',
            class not in ('motorway', 'footway', 'steps', 'pedestrian')
        ) as bike,
        class in (
            'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'unclassified',
            'residential', 'living_street', 'service', 'track', 'unknown'
        ) as car_default
    from segment
),

part as (
    select
        m.*,
        c.connector_id as from_gers,
        c.at as from_at,
        lead(c.connector_id) over w as to_gers,
        lead(c.at) over w as to_at
    from mode as m, unnest(m.connectors) as u(c)
    -- 同じ位置に別々の connector があるときも毎回同じ順に並べる
    window w as (partition by m.id order by c.at, c.connector_id)
),

edge as (
    select
        *,
        -- 別々の connector が区間上の同じ位置にあることがある（全国で 76 本）。切り出すと点になるので、
        -- つながりを残すために長さ 0 の線にする
        case
            -- 区切る必要の無い区間は元の線をそのまま使う（座標を投影の往復で丸めない）
            when from_at = 0 and to_at = 1 then geometry
            when from_at < to_at then st_transform(
                st_linesubstring(geometry_merc, from_at, to_at), 'EPSG:3395', 'EPSG:4326', true
            )
            else st_makeline(
                st_transform(st_lineinterpolatepoint(geometry_merc, from_at), 'EPSG:3395', 'EPSG:4326', true),
                st_transform(st_lineinterpolatepoint(geometry_merc, from_at), 'EPSG:3395', 'EPSG:4326', true)
            )
        end as part_geometry
    from part
    where to_gers is not null and from_gers <> to_gers
),

placed as (
    select
        *,
        if(from_at < to_at, st_lineinterpolatepoint(part_geometry, 0.5), st_startpoint(part_geometry)) as midpoint
    from edge
)

select
    row_number() over (order by {{ jis_mesh2('st_x(p.midpoint)', 'st_y(p.midpoint)') }}, p.id, p.from_at, p.from_gers) as edge_id,
    f.node_id as from_node,
    t.node_id as to_node,
    round(st_length_spheroid(st_flipcoordinates(p.part_geometry)), 1) as length_m,
    p.class,
    p.subclass,
    p.walk,
    p.bike,
    -- 向きを問わない規則とその向きの規則を合わせて、最後に当てはまるものが効く
    coalesce({{ access_rule('p.rules', car_modes, 'forward') }} <> 'denied', p.car_default) as car_forward,
    coalesce({{ access_rule('p.rules', car_modes, 'backward') }} <> 'denied', p.car_default) as car_backward,
    (case p.max_speed.unit when 'mph' then round(p.max_speed.value * 1.609344) else p.max_speed.value end)::integer
        as speed_limit_kmh,
    list_contains(p.flags, 'is_bridge') as is_bridge,
    list_contains(p.flags, 'is_tunnel') as is_tunnel,
    list_contains(p.flags, 'is_link') as is_link,
    {{ jis_mesh1('st_x(p.midpoint)', 'st_y(p.midpoint)') }} as mesh1,
    {{ jis_mesh2('st_x(p.midpoint)', 'st_y(p.midpoint)') }} as mesh2,
    p.id as gers_id,
    p.from_at,
    p.to_at,
    p.part_geometry as geometry,
    p.release
from placed as p
join {{ ref('road_node') }} as f on f.gers_id = p.from_gers
join {{ ref('road_node') }} as t on t.gers_id = p.to_gers
order by edge_id
