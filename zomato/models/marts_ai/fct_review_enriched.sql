-- AI layer: every review (300,000 rows) with the LLM's sentiment and topic.
-- The LLM only scored the ~294 DISTINCT comment texts (ai/enrich_reviews.py);
-- this join copies those answers onto every review that uses the same text.
-- A left join keeps reviews even if a comment was never scored, so the
-- not_null test on sentiment can flag any gap instead of silently dropping rows.
select
    r.review_id,
    r.order_id,
    r.customer_id,
    r.restaurant_id,
    r.restaurant_city,
    r.rating,
    r.review_date,
    r.comment,
    e.sentiment,
    e.topic,
    (e.sentiment = 'negative') as is_negative
from {{ ref('stg_reviews') }} r
left join {{ source('ai', 'comment_enrichment') }} e
    on r.comment = e.comment
