{# 日本の行政区画に地方公共団体コードを付けたもの。1行が1区画。
   Overture の区画はコードを持たないので、都道府県名と市区町村名を総務省の一覧（Queria の
   lg_code、pipelines/divisions.py が data/divisions/lg_code.parquet に保存する）と照合する。

   市区町村にあたる区画は subtype = locality（市町村・東京の特別区）と macrohood（政令市の区）。
   locality には郡や大字・字（class = hamlet）も混ざっているが、照合のキーが一覧の名前と
   一致するものだけが残るので、ここでは絞らない。郡は階層の途中に挟まるので、親をたどる
   ときに飛ばす（「上川郡(石狩国)」のように旧国名の付くものがある）。

   町丁・字にはそれ自身のコードは無いので、階層をさかのぼって最初にコードが付いた区画の
   コードを入れる。政令市の区の中の町丁なら区のコードになる。 #}

{% set gun = "'郡(\\(.*\\))?$'" %}

with division as (
    select
        id as division_id,
        subtype,
        class,
        names.primary as name,
        coalesce(
            list_filter(names.rules, r -> r.variant = 'language' and r.language = 'en')[1].value,
            names.common['en']
        ) as name_en,
        parent_division_id,
        -- 日本の区画は階層が 1 本だけ。先頭が国、末尾が自分自身
        hierarchies[1] as hierarchy,
        list_filter(hierarchies[1], h -> h.subtype = 'region')[1].name as prefecture,
        population,
        wikidata,
        geometry,
        release
    from {{ ref('raw_division') }}
),

lg_code as (
    -- 「保土ケ谷区」と「保土ヶ谷区」のような小書きの揺れを両側で畳む
    select lg_code, pref_code, prefecture, replace(replace(city, 'ヶ', 'ケ'), 'ヵ', 'カ') as city, code_type
    from read_parquet('data/divisions/lg_code.parquet')
    -- 北方領土の 6 村は Overture に区画が無く、国後島の泊村は北海道の泊村と名前が重なる
    where not (code_type = 'municipality' and lg_code between '016951' and '017001')
),

candidate as (
    select
        division_id,
        prefecture,
        -- 政令市の区は一覧で「札幌市中央区」と市の名前から書くので、郡でない親の名前を前に付ける
        replace(replace(
            coalesce(list_filter(hierarchy[1:-2], h -> h.subtype = 'locality' and not regexp_matches(h.name, {{ gun }}))[-1].name, '')
                || name,
            'ヶ', 'ケ'), 'ヵ', 'カ') as city
    from division
    where subtype in ('locality', 'macrohood')
      and not regexp_matches(name, {{ gun }})
),

municipality as (
    select candidate.division_id, lg_code.lg_code
    from candidate
    join lg_code using (prefecture, city)
    where lg_code.code_type = 'municipality'
    -- 同じ都道府県に同じ名前の市区町村は無いはずだが、あれば付けない
    qualify count(*) over (partition by candidate.division_id) = 1
),

ancestor as (
    select division_id, unnest(hierarchy).division_id as ancestor_id, generate_subscripts(hierarchy, 1) as depth
    from division
),

nearest as (
    select ancestor.division_id, arg_max(municipality.lg_code, ancestor.depth) as lg_code
    from ancestor
    join municipality on municipality.division_id = ancestor.ancestor_id
    group by ancestor.division_id
)

select
    division.division_id,
    division.subtype,
    division.class,
    division.name,
    division.name_en,
    division.prefecture,
    prefecture.pref_code,
    nearest.lg_code,
    municipality.division_id is not null as is_municipality,
    division.parent_division_id,
    array_to_string(list_transform(division.hierarchy[2:], h -> h.name), ' > ') as hierarchy_names,
    division.population,
    division.wikidata,
    st_x(division.geometry) as lon,
    st_y(division.geometry) as lat,
    {{ jis_mesh1('st_x(division.geometry)', 'st_y(division.geometry)') }} as mesh1,
    {{ jis_mesh2('st_x(division.geometry)', 'st_y(division.geometry)') }} as mesh2,
    division.geometry,
    division.release
from division
left join lg_code as prefecture
    on prefecture.code_type = 'prefecture' and prefecture.prefecture = division.prefecture
left join nearest using (division_id)
left join municipality using (division_id)
order by mesh2, division.division_id
