{# raw_division の列を平坦化したもの。名前・英語名・階層・都道府県名を取り出す。 #}

select
    id as division_id,
    subtype,
    class,
    names.primary as name,
    -- rules の variant は official / alternate / short で、言語は language に入る
    coalesce(
        names.common['en'],
        list_filter(names.rules, lambda r: r.language = 'en')[1].value
    ) as name_en,
    parent_division_id,
    -- 日本の区画は階層が 1 本だけ。先頭が国、末尾が自分自身
    hierarchies[1] as hierarchy,
    list_filter(hierarchies[1], lambda h: h.subtype = 'region')[1].name as prefecture,
    population,
    wikidata,
    geometry,
    release
from {{ ref('raw_division') }}
