#!/bin/bash

cd /Users/nakanomizuki/Code/Mizuki8783/Mizuki8783/personal/ga4-bq-dbt

# Load environment variables
set -a
source .env
set +a

cd dbt_project

uv run dbt run
