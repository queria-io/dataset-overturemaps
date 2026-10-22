{# 道路網の辺。Overture の区間を、途中で他の道とつながる点（connector）ごとに区切った 1 本が 1 行。
   from_node から to_node へ向かう向きが、元の区間の線の向き（Overture の forward）になる。
   通れる手段は道路の種類で決め、access_restrictions の区間全体に効く規則で上書きする。
   一方通行は車にだけ効かせる（歩行者と自転車は両方向に通す）。 #}

{% set car_modes = "['car', 'motor_vehicle', 'vehicle']" %}
{% set bike_modes = "['bicycle', 'vehicle']" %}
{% set walk_modes = "['foot']" %}
{% set yes = "['allowed', 'designated']" %}
{% set no = "['denied']" %}

with segment as (
    select
        id,
        class,
        subclass,
        geometry,
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
        case
            when {{ has_access_rule('rules', no, walk_modes) }} then false
            when {{ has_access_rule('rules', yes, walk_modes) }} then true
            else class <> 'motorway'
        end as walk,
        case
            when {{ has_access_rule('rules', no, bike_modes) }} then false
            when {{ has_access_rule('rules', yes, bike_modes) }} then true
            else class not in ('motorway', 'footway', 'steps', 'pedestrian')
        end as bike,
        case
            when {{ has_access_rule('rules', no, car_modes) }} then false
            when {{ has_access_rule('rules', yes, car_modes) }} then true
            else class in (
                'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'unclassified',
                'residential', 'living_street', 'service', 'track', 'unknown'
            )
        end as car_any
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
    window w as (partition by m.id order by c.at)
),

edge as (
    select
        *,
        -- 別々の connector が区間上の同じ位置にあることがある（全国で 76 本）。切り出すと点になるので、
        -- つながりを残すために長さ 0 の線にする
        case
            when from_at < to_at then st_linesubstring(geometry, from_at, to_at)
            else st_makeline(st_lineinterpolatepoint(geometry, from_at), st_lineinterpolatepoint(geometry, from_at))
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
    row_number() over (order by {{ jis_mesh2('st_x(p.midpoint)', 'st_y(p.midpoint)') }}, p.id, p.from_at) as edge_id,
    f.node_id as from_node,
    t.node_id as to_node,
    round(st_length_spheroid(st_flipcoordinates(p.part_geometry)), 1) as length_m,
    p.class,
    p.subclass,
    p.walk,
    p.bike,
    p.car_any and not {{ has_access_rule('p.rules', no, car_modes, 'forward') }} as car_forward,
    p.car_any and not {{ has_access_rule('p.rules', no, car_modes, 'backward') }} as car_backward,
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
