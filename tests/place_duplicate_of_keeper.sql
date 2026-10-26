{# duplicate_of は残す側の行を直接指す。指した先がさらに duplicate なら落とす。
   place.sql は重複の連鎖を 3 段までたどるので、これより長い連鎖が出たらたどる段を増やす。 #}

select place.id, place.duplicate_of, keeper.duplicate_of as keeper_duplicate_of
from {{ ref('place') }} as place
join {{ ref('place') }} as keeper on keeper.id = place.duplicate_of
where keeper.exclude_reason = 'duplicate'
