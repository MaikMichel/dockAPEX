# If you want to use AOP API PACKAGES

> not included in this repo cause licence awareness

## place the following files into that directory:
- aop/db/aop_db_native_compile_pkg.sql
- aop/db/aop_db_pkg.sql
- aop/db/aop_modal_pkg.sql
- aop/db/install.sql

> when install.sql is present a schema name AOP is created and you are able to use `aop.aop_api_pkg.plsql_call_to_aop(...)`
