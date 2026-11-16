{# raw_place の入れ子の列を平坦化したもの。列の選び方は place.md。 #}

select
    id,
    names.primary as name,
    -- 言語別の名前は names.rules の variant = 'language' に入る。names.common は
    -- 2026-09 のリリースでは日本の全行で NULL だが、スキーマ上は残っているので後ろで拾う
    coalesce(
        list_filter(names.rules, r -> r.variant = 'language' and r.language = 'ja')[1].value,
        names.common['ja']
    ) as name_ja,
    coalesce(
        list_filter(names.rules, r -> r.variant = 'language' and r.language = 'en')[1].value,
        names.common['en']
    ) as name_en,
    basic_category,
    taxonomy.primary as taxonomy_primary,
    array_to_string(taxonomy.hierarchy, ' > ') as taxonomy_hierarchy,
    confidence,
    operating_status,
    brand.names.primary as brand_name,
    brand.wikidata as brand_wikidata,
    addresses[1].freeform as address,
    addresses[1].locality as address_locality,
    addresses[1].region as address_region,
    addresses[1].postcode as postal_code,
    array_to_string(phones, ' ') as phones,
    -- 重複の判定にだけ使う。1 つの番号の中にも空白がある（+81 3-…）ので、つないだ phones からは切り出せない
    phones[1] as first_phone,
    array_to_string(websites, ' ') as websites,
    array_to_string(list_sort(list_distinct(list_transform(sources, s -> s.dataset))), ', ')
        as source_datasets,
    array_to_string(list_sort(list_distinct(list_transform(sources, s -> s.license))), ', ')
        as source_licenses,
    st_y(geometry) as latitude,
    st_x(geometry) as longitude,
    geometry,
    release
from {{ ref('raw_place') }}
