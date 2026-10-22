{# Overture の access_restrictions から、ある移動手段に効く規則があるかを返す。
   区間の一部だけに効く規則（between）と、時間帯・用途・車両の条件付きの規則
   （during / using / recognized / vehicle）は見ない。
   modes が空のときは手段を問わない規則（mode が NULL）だけを拾う。 #}

{% macro has_access_rule(rules, access_types, modes, heading=none) -%}
    coalesce(len(list_filter({{ rules }}, r ->
        r.between is null
        and list_contains({{ access_types }}, r.access_type)
        and (r.when is null or (
            r.when.during is null and r.when.using is null
            and r.when.recognized is null and r.when.vehicle is null
            {% if heading %}and r.when.heading = '{{ heading }}'{% else %}and r.when.heading is null{% endif %}
            and (r.when.mode is null or list_has_any(r.when.mode, {{ modes }}))
        ))
        {% if heading %}and r.when is not null{% endif %}
    )), 0) > 0
{%- endmacro %}
