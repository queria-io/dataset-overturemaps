{# raw_lg_code の照合に使う列。「保土ケ谷区」と「保土ヶ谷区」のような小書きの揺れを畳む。 #}

select
    lg_code,
    pref_code,
    prefecture,
    replace(replace(city, 'ヶ', 'ケ'), 'ヵ', 'カ') as city,
    code_type
from {{ ref('raw_lg_code') }}
