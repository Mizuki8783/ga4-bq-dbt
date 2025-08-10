{# Build list of partitions to (re)process #}
{% set days = (var('static_incremental_days', 3) | int) %}
{% set partitions_to_replace = ['current_date'] %}
{% for i in range(days) %}
  {% set n = i + 1 %}
  {% do partitions_to_replace.append('date_sub(current_date, interval ' ~ n ~ ' day)') %}
{% endfor %}

{{
    config(
        pre_hook="{{ ga4.combine_property_data() }}" if var('combined_dataset', false) else "",
        materialized = 'incremental',
        incremental_strategy = 'insert_overwrite',
        partition_by={
            "field": "event_date_dt",
            "data_type": "date",
        },
        partitions = partitions_to_replace,
        cluster_by=['event_name']
    )
}}

with source as (
    select
        {{ ga4.base_select_source() }}
    from {{ source('ga4', 'events') }}
    where cast(left(replace(_table_suffix, 'intraday_', ''), 8) as int64) >= {{ var('start_date') | int }}
    {% if is_incremental() %}
        and parse_date('%Y%m%d', left(replace(_table_suffix, 'intraday_', ''), 8)) in ({{ partitions_to_replace | join(',') }})
    {% endif %}
),
renamed as (
    select

    event_date_dt
    , event_timestamp
    , lower(replace(trim(event_name), " ", "_")) as event_name -- Clean up all event names to be snake cased
    , event_params
    , event_previous_timestamp
    , event_value_in_usd
    , event_bundle_sequence_id
    , event_server_timestamp_offset
    , user_id
    , user_pseudo_id
    , privacy_info.analytics_storage as privacy_info_analytics_storage
    , privacy_info.ads_storage as privacy_info_ads_storage
    , privacy_info.uses_transient_token as privacy_info_uses_transient_token
    , user_properties
    , user_first_touch_timestamp
    , user_ltv.revenue as user_ltv_revenue
    , user_ltv.currency as user_ltv_currency
    , device.category as device_category
    , device.mobile_brand_name as device_mobile_brand_name
    , device.mobile_model_name as device_mobile_model_name
    , device.mobile_marketing_name as device_mobile_marketing_name
    , device.mobile_os_hardware_model as device_mobile_os_hardware_model
    , device.operating_system as device_operating_system
    , device.operating_system_version as device_operating_system_version
    , device.vendor_id as device_vendor_id
    , device.advertising_id as device_advertising_id
    , device.language as device_language
    , device.is_limited_ad_tracking as device_is_limited_ad_tracking
    , device.time_zone_offset_seconds as device_time_zone_offset_seconds
    -- Removed device.browser and device.browser_version as they may not exist for web streams
    , device.web_info.browser as device_web_info_browser
    , device.web_info.browser_version as device_web_info_browser_version
    , device.web_info.browser as device_browser
    , device.web_info.browser_version as device_browser_version
    , REGEXP_EXTRACT((select value.string_value from unnest(event_params) where key = 'page_location'), r'(?:\\w+:)?//([^/]+)') as device_web_info_hostname
    , geo.continent as geo_continent
    , geo.country as geo_country
    , geo.region as geo_region
    , geo.city as geo_city
    , geo.sub_continent as geo_sub_continent
    , geo.metro as geo_metro
    , app_info.id as app_info_id
    , app_info.version as app_info_version
    , app_info.install_store as app_info_install_store
    , app_info.firebase_app_id as app_info_firebase_app_id
    , app_info.install_source as app_info_install_source
    , traffic_source.name as user_campaign
    , traffic_source.medium as user_medium
    , traffic_source.source as user_source
    , stream_id
    , platform
    , struct(
        total_item_quantity
        , purchase_revenue_in_usd
        , purchase_revenue
        , refund_value_in_usd
        , refund_value
        , shipping_value_in_usd
        , shipping_value
        , tax_value_in_usd
        , tax_value
        , unique_items
        , transaction_id
    ) as ecommerce
    , (select
        array_agg(struct(
            unnested_items.item_id
            , unnested_items.item_name
            , unnested_items.item_brand
            , unnested_items.item_variant
            , unnested_items.item_category
            , unnested_items.item_category2
            , unnested_items.item_category3
            , unnested_items.item_category4
            , unnested_items.item_category5
            , unnested_items.price_in_usd
            , unnested_items.price
            , unnested_items.quantity
            , unnested_items.item_revenue_in_usd
            , unnested_items.item_revenue
            , unnested_items.item_refund_in_usd
            , unnested_items.item_refund
            , unnested_items.coupon
            , unnested_items.affiliation
            , unnested_items.location_id
            , unnested_items.item_list_id
            , unnested_items.item_list_name
            , unnested_items.item_list_index
            , unnested_items.promotion_id
            , unnested_items.promotion_name
            , unnested_items.creative_name
            , unnested_items.creative_slot
        )) from unnest(items) as unnested_items
    ) items
    , property_id
    , (select

            value.int_value

    from unnest(event_params) where key = 'ga_session_id') as

    session_id

    , (select

            value.string_value

    from unnest(event_params) where key = 'page_location') as

    page_location

    , (select

            value.int_value

    from unnest(event_params) where key = 'ga_session_number') as

    session_number

    , COALESCE(
        (SELECT value.int_value FROM unnest(event_params) WHERE key = "session_engaged"),
        (CASE WHEN (SELECT value.string_value FROM unnest(event_params) WHERE key = "session_engaged") = "1" THEN 1 END)
    ) as session_engaged
    , (select

            value.int_value

    from unnest(event_params) where key = 'engagement_time_msec') as

    engagement_time_msec

    , (select

            value.string_value

    from unnest(event_params) where key = 'page_title') as

    page_title

    , (select

            value.string_value

    from unnest(event_params) where key = 'page_referrer') as

    page_referrer

    , (select

            lower(value.string_value)

    from unnest(event_params) where key = 'source') as

    event_source

    , (select

            lower(value.string_value)

    from unnest(event_params) where key = 'medium') as

    event_medium

    , (select

            lower(value.string_value)

    from unnest(event_params) where key = 'campaign') as

    event_campaign

    , (select

            lower(value.string_value)

    from unnest(event_params) where key = 'content') as

    event_content

    , (select

            lower(value.string_value)

    from unnest(event_params) where key = 'term') as

    event_term

    , CASE
        WHEN event_name = 'page_view' THEN 1
        ELSE 0
    END AS is_page_view
    , CASE
        WHEN event_name = 'purchase' THEN 1
        ELSE 0
    END AS is_purchase
    from source
)

select * from renamed
qualify row_number() over(
  partition by event_date_dt, stream_id, user_pseudo_id, session_id, event_name, event_timestamp,
               to_json_string(ARRAY(SELECT params FROM UNNEST(event_params) AS params ORDER BY key))
) = 1
