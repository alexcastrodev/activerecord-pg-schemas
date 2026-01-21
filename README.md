# Problem 

I want to use multi schemas and multi database using Active Record automatically.

But if you are using Rails, you don't "schema:create", you only have db:create, so, it will create a database, and use the public schema. In that case, you need to "enhance" (extends) the rails db:create. 

Also you need to set the `schema_search_path` in the `database.yml` file.

## Steps

1. Create schema if not exist
2. Migrate
3. Run


## Test

```bash
docker compose up -d
ruby test_ar_8.1.rb
```