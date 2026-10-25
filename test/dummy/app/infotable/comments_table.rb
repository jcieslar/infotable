# ============================================================================
# COMMENTS TABLE - Demonstrates VIRTUAL COLUMNS with filtering
# ============================================================================
#
# This table showcases how to use VIRTUAL (computed) columns for filtering
# and sorting on aggregated data.
#
# VIRTUAL COLUMN EXAMPLE:
# - Column: author_total_comments
# - Type: Subquery (SELECT COUNT(*) ...)
# - Features: Sortable ✅ and Filterable ✅
# - Implementation: Mark as `virtual: true` to enable HAVING clause filtering
#
# HOW TO USE VIRTUAL COLUMNS:
# 1. Add computed column to SELECT (aggregate, subquery, or calculation)
# 2. Give it an alias (AS column_name)
# 3. Define column with `virtual: true` option
# 4. Add `virtual_sql` option with the SQL expression (without the AS alias part)
# 5. Enable filtering with `filterable: true` and appropriate `filter_type`
#
# RESULT:
# - Users can filter: "Show authors with > 20 total comments"
# - Users can sort by the aggregate value
# - SQL uses HAVING clause for filtering (not WHERE)
# - SQL uses the virtual_sql expression for both filtering and sorting
# - Ensures correct SQL generation with aggregated data
#
# See VIRTUAL_COLUMNS_EXAMPLE.md for more examples
# ============================================================================

class CommentsTable < Infotable::Base
  # Data source with joins to show post and author information
  # INCLUDES VIRTUAL COLUMN: author_total_comments (aggregate count via subquery)
  query do
    Comment.select(
      "comments.*",
      # ⭐ Virtual column - Total comments by this author across all posts
      "(SELECT COUNT(*) FROM comments AS c WHERE c.author_id = comments.author_id) AS author_total_comments"
    ).joins(:post, :author).preload(:post, :author)
  end

  # Showcase: Relational data table with mixed column types
  column :id,
    label: "ID",
    type: :integer,
    width: "60px",
    sortable: true,
    visible: false

  column :post,
    label: "Post",
    type: :string,
    width: "300px",
    sql: "comments.post_id",     # filter by id (select options are [title, id])
    sort_sql: "posts.title",     # sort by the joined title
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Post.order(:title).limit(100).pluck(:title, :id).map { |title, id| [ title.truncate(50), id ] } },
    visible: true,
    formatter: ->(value, record) {
      post_title = record.post.title.truncate(45)
      "<span class='text-sm text-gray-700'>#{h(post_title)}</span>".html_safe
    }

  column :author,
    label: "Commenter",
    type: :string,
    width: "180px",
    sql: "comments.author_id",
    sort_sql: "authors.name",
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Author.order(:name).pluck(:name, :id).map { |name, id| [ name, id ] } },
    visible: true,
    formatter: ->(value, record) {
      author_name = record.author.name
      if record.author.verified
        "#{h(author_name)} <span class='text-xs text-green-600'>✓</span>".html_safe
      else
        author_name
      end
    }

  column :body,
    label: "Comment",
    type: :text,  # Uses default 300px width
    searchable: true,
    visible: true,
    formatter: ->(value, record) {
      truncated = value.truncate(80)
      "<span class='text-sm'>#{h(truncated)}</span>".html_safe
    }

  column :status,
    label: "Status",
    type: :badge,  # Uses default 120px width
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: [ "approved", "pending", "spam" ],
    visible: true,
    formatter: {
      type: :badge,
      options: {
        colors: {
          "approved" => "green",
          "pending" => "yellow",
          "spam" => "red"
        }
      }
    }

  column :flagged,
    label: "Flagged",
    type: :boolean,  # Uses default 80px width
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: [ [ "Yes", true ], [ "No", false ] ],
    visible: true,
    formatter: ->(value, record) {
      if value
        '<span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800">🚩 Flagged</span>'.html_safe
      else
        '<span class="text-gray-400 text-xs">-</span>'.html_safe
      end
    }

  column :likes_count,
    label: "Likes",
    type: :integer,  # Uses default 100px width
    sortable: true,
    visible: true,
    formatter: ->(value, record) {
      count = value || 0
      if count > 0
        "👍 #{count}"
      else
        "-"
      end
    }

  # ⭐ VIRTUAL COLUMN EXAMPLE - Computed via subquery
  # This demonstrates filtering and sorting on aggregated data
  column :author_total_comments,
    label: "Author's Total",
    type: :integer,
    width: "140px",
    sortable: true,        # ✅ Can sort by this aggregate
    filterable: true,      # ✅ Can filter - uses HAVING clause
    filter_type: :number,  # Number range filter (from/to)
    virtual: true,         # Computed column (value comes from the SELECT alias)
    sql: "(SELECT COUNT(*) FROM comments AS c WHERE c.author_id = comments.author_id)", # row-level expression => WHERE (a subquery is not an aggregate, so no HAVING)
    visible: true,
    formatter: ->(value, record) {
      count = value || 0
      color_class = if count > 50
        "bg-purple-100 text-purple-800 border-purple-200"
      elsif count > 20
        "bg-blue-100 text-blue-800 border-blue-200"
      elsif count > 5
        "bg-green-100 text-green-800 border-green-200"
      else
        "bg-gray-100 text-gray-600 border-gray-200"
      end
      "<span class='inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border #{color_class}'>#{count} comments</span>".html_safe
    }

  column :created_at,
    label: "Posted",
    type: :datetime,  # Uses default 180px width
    sortable: true,
    filterable: true,
    filter_type: :date,
    visible: true,
    formatter: ->(value, record) {
      time_ago = ((Time.now - value) / 3600).round
      if time_ago < 1
        "Just now"
      elsif time_ago < 24
        "#{time_ago}h ago"
      elsif time_ago < 168
        "#{(time_ago / 24).round}d ago"
      else
        value.strftime("%b %d, %Y")
      end
    }

  column :actions,
    label: "Actions",
    type: :action,  # Uses default 100px width
    visible: true,
    formatter: :action,
    formatter_options: {
      actions: [
        {
          label: "View",
          url: ->(record) { "#comment-#{record.id}" },
          color: "primary"
        },
        {
          label: "Edit",
          url: ->(record) { "#edit-comment-#{record.id}" }
        },
        {
          label: "Delete",
          url: ->(record) { "#delete-comment-#{record.id}" },
          method: :delete,
          color: "danger",
          confirm: "Are you sure?"
        }
      ]
    }

  # Table settings
  per_page 30
  per_page_options [ 10, 30, 50, 100 ]
  default_sort :created_at, :desc
  table_min_height "450px"
  table_max_height "650px"

  # Row link - make entire row clickable
  # Click on row to view comment (Cmd/Ctrl+Click to open in new tab)
  row_link ->(record) { "#comment-#{record.id}" }

  # The click first fires `infotable:row-click` on the row (preventDefault() keeps the link
  # from being followed); row_class / row_data decorate the row; the <tr> gets id="comment_<id>"
  row_click
  row_class ->(record) { "bg-amber-50/60 dark:bg-amber-950/20" if record.flagged }
  row_data ->(record) { { comment_id: record.id, author_id: record.author_id } }
end
