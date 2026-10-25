# Virtual Columns Example

## Problem

When you have aggregated columns (like `COUNT`, `SUM`, etc.) in your query, you need special handling for filtering and sorting because:
- **Sorting** works normally with aggregated column names
- **Filtering** requires `HAVING` clause instead of `WHERE` clause

## Solution

Mark aggregated/computed columns as `virtual: true` in your column definition.

## Example: Shops with Product Counts

```ruby
class ShopsTable < Infotable::Base
  # Query with aggregated columns
  query do
    Shop.select(
      "shops.id",
      "shops.name",
      "shops.last_integrated_at",
      "shops.integration_url",
      "shops.integration_type",
      "shops.active",
      "shops.hide",
      "shops.new_sync",
      "shops.skip_split_url",
      "shops.login",
      "shops.passcode",
      "shops.last_sync_at",
      "shops.last_sync_error",
      "COUNT(products.id) AS products_count",          # Aggregated column
      "COUNT(accessories.id) AS accessories_count"     # Aggregated column
    )
      .left_joins(:products, :accessories)
      .group("shops.id")
  end

  # Regular columns
  column :id,
    label: "ID",
    type: :integer,
    sortable: true,
    visible: true

  column :name,
    label: "Shop Name",
    type: :string,
    sortable: true,
    filterable: true,
    filter_type: :text,
    visible: true

  column :integration_type,
    label: "Integration",
    type: :string,
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Shop.distinct.pluck(:integration_type).compact.sort },
    visible: true

  column :active,
    label: "Active",
    type: :boolean,
    sortable: true,
    filterable: true,
    visible: true,
    formatter: :boolean

  # Virtual/computed columns (aggregates)
  # Mark them with virtual: true to enable proper filtering with HAVING clause
  # Add virtual_sql with the SQL expression for filtering
  column :products_count,
    label: "Products",
    type: :integer,
    sortable: true,        # Sorting works normally
    filterable: true,      # Filtering uses HAVING instead of WHERE
    filter_type: :number,
    virtual: true,         # ⭐ This is the key!
    virtual_sql: "COUNT(products.id)", # ⭐ SQL expression for HAVING clause
    visible: true

  column :accessories_count,
    label: "Accessories",
    type: :integer,
    sortable: true,        # Sorting works normally
    filterable: true,      # Filtering uses HAVING instead of WHERE
    filter_type: :number,
    virtual: true,         # ⭐ This is the key!
    virtual_sql: "COUNT(accessories.id)", # ⭐ SQL expression for HAVING clause
    visible: true

  column :last_sync_at,
    label: "Last Sync",
    type: :datetime,
    sortable: true,
    filterable: true,
    filter_type: :date,
    visible: true,
    formatter: :date,
    formatter_options: { format: :short }

  # Pagination
  per_page 25
  default_sort :name, :asc
end
```

## How It Works

### Regular Columns (virtual: false - default)
- **Filtering**: Uses `WHERE` clause
- **Sorting**: Uses column name
- Example: `WHERE shops.name LIKE '%foo%'`

### Virtual Columns (virtual: true)
- **Filtering**: Uses `HAVING` clause (required for aggregates)
- **Sorting**: Uses `virtual_sql` expression if provided, otherwise uses column name
- **SQL Expression**: Uses `virtual_sql` option (the SQL expression without the alias)
- Example: `HAVING COUNT(products.id) >= 10`, `ORDER BY COUNT(products.id) DESC`

**Important**: For virtual columns, you must provide the `virtual_sql` option with the SQL expression (without the `AS alias` part). This is required for both filtering and sorting to work correctly with aggregated data.

## Usage

```erb
<%= infotable :shops_table,
    title: "Shops",
    subtitle: "All shops with product counts" %>
```

Now users can:
- ✅ Sort by `products_count` or `accessories_count`
- ✅ Filter by `products_count >= 10` (uses HAVING)
- ✅ Filter by `name` contains "foo" (uses WHERE)
- ✅ Combine virtual and regular column filters

## Other Virtual Column Examples

### Subquery Columns
```ruby
query do
  User.select(
    "users.*",
    "(SELECT COUNT(*) FROM orders WHERE orders.user_id = users.id) AS orders_count"
  )
end

column :orders_count,
  type: :integer,
  sortable: true,
  filterable: true,
  filter_type: :number,
  virtual: true,  # Subquery result
  virtual_sql: "(SELECT COUNT(*) FROM orders WHERE orders.user_id = users.id)" # SQL expression for filtering
```

### Calculated Columns
```ruby
query do
  Order.select(
    "orders.*",
    "(price * quantity) AS total",
    "(price * quantity * tax_rate) AS total_with_tax"
  )
end

column :total,
  type: :decimal,
  sortable: true,
  filterable: true,
  filter_type: :number,
  virtual: true,  # Calculated in SELECT
  virtual_sql: "(price * quantity)", # SQL expression for filtering
  formatter: :currency

column :total_with_tax,
  type: :decimal,
  sortable: true,
  filterable: true,
  filter_type: :number,
  virtual: true,  # Calculated in SELECT
  virtual_sql: "(price * quantity * tax_rate)", # SQL expression for filtering
  formatter: :currency
```

### Aggregates with Functions
```ruby
query do
  Product.select(
    "products.*",
    "AVG(reviews.rating) AS avg_rating",
    "SUM(order_items.quantity) AS total_sold",
    "MAX(order_items.created_at) AS last_sold_at"
  )
    .left_joins(:reviews, :order_items)
    .group("products.id")
end

column :avg_rating,
  label: "Avg Rating",
  type: :decimal,
  sortable: true,
  filterable: true,
  filter_type: :number,
  virtual: true,
  virtual_sql: "AVG(reviews.rating)", # SQL expression for filtering
  formatter: ->(value, record) {
    return "-" if value.nil?
    "⭐ #{number_with_precision(value, precision: 1)}"
  }

column :total_sold,
  label: "Total Sold",
  type: :integer,
  sortable: true,
  filterable: true,
  filter_type: :number,
  virtual: true,
  virtual_sql: "SUM(order_items.quantity)" # SQL expression for filtering
```

## Important Notes

1. **Always mark aggregated columns as `virtual: true`**
2. **Provide `virtual_sql` option** with the SQL expression (without the `AS alias` part)
3. **Virtual columns use HAVING for filtering** (not WHERE)
4. **Virtual columns use virtual_sql for sorting** (if provided, otherwise uses column name)
5. **Column names must match** the SELECT alias exactly
6. **GROUP BY is required** for aggregates
7. **Can mix virtual and regular columns** in filters and sorting

## Technical Details

When `virtual: true` is set:
- `FilterProcessor` uses `.having()` instead of `.where()` for filtering
- `TablesController` uses `virtual_sql` expression for sorting (if provided)
- Works with all filter types: number, text, select, boolean, date
- Proper SQL generation for aggregated data in both HAVING and ORDER BY clauses
- Maintains query performance with proper indexing
