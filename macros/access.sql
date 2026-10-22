{# Overture の access_restrictions から、ある移動手段に最後に当てはまる規則の access_type
   （allowed / designated / denied）を返す。当てはまる規則が無ければ NULL。
   Overture の規則は「当てはまるもののうちリストの最後の 1 つが効く」ので、一般的な禁止の後に
   特定の手段の許可が続く（access=no + foot=yes など）場合は許可が勝つ。
   区間の一部だけに効く規則（between）と、時間帯・用途・車両の条件付きの規則
   （during / using / recognized / vehicle）は当てはまらないものとして扱う。
   heading を渡すと、向きを問わない規則に加えてその向きの規則も拾う。渡さなければ向きを問わない規則だけ。 #}

{% macro access_rule(rules, modes, heading=none) -%}
    list_filter({{ rules }}, r ->
        r.between is null
        and (r.when is null or (
            r.when.during is null and r.when.using is null
            and r.when.recognized is null and r.when.vehicle is null
            {% if heading %}and (r.when.heading is null or r.when.heading = '{{ heading }}'){% else %}and r.when.heading is null{% endif %}
            and (r.when.mode is null or list_has_any(r.when.mode, {{ modes }}))
        ))
    )[-1].access_type
{%- endmacro %}
