{# raw_place の入れ子の列を平坦化した日本の POI。列の選び方は place.table.yml。 #}

select
    id,
    names.primary as name,
    names.common['ja'] as name_ja,
    names.common['en'] as name_en,
    basic_category,
    taxonomy.primary as taxonomy_primary,
    array_to_string(taxonomy.hierarchy, ' > ') as taxonomy_hierarchy,
    confidence,
    operating_status,
    brand.names.primary as brand_name,
    brand.wikidata as brand_wikidata,
    addresses[1].freeform as address,
    addresses[1].locality as locality,
    addresses[1].region as region,
    addresses[1].postcode as postcode,
    array_to_string(phones, ' ') as phones,
    array_to_string(websites, ' ') as websites,
    array_to_string(list_sort(list_distinct(list_transform(sources, s -> s.dataset))), ', ')
        as source_datasets,
    array_to_string(list_sort(list_distinct(list_transform(sources, s -> s.license))), ', ')
        as source_licenses,
    st_y(geometry) as lat,
    st_x(geometry) as lon,
    geometry,
    release
from {{ ref('raw_place') }}
