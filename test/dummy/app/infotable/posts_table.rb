class PostsTable < Infotable::Base
  # Data source with joins to show author information
  query do
    Post.joins(:author).preload(:author, :comments)
  end

  # Bulk actions: checkboxes + action bar; the app receives ids[] (see PostsController#batch)
  batch_actions do
    action :export, label: "Export selected", url: "/posts/batch", method: :get
    action :feature, label: "Feature", url: "/posts/batch", method: :patch, color: :primary
    action :delete, label: "Delete", url: "/posts/batch", method: :delete, color: :danger,
      confirm: "Delete %{count} posts?"
  end

  # Showcase: Feature-rich table with many column types and custom formatters
  column :id,
    label: "ID",
    type: :integer,
    width: "60px",
    sortable: true,
    visible: true,
    pinned: :left  # Pinned to left by default

  column :title,
    label: "Post Title",
    type: :string,
    width: "350px",  # Wide column for titles
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :text,
    visible: true,
    formatter: ->(value, record) {
      truncated = value.length > 50 ? "#{value[0..50]}..." : value
      "<strong class='text-gray-900'>#{h(truncated)}</strong>".html_safe
    }

  column :author,
    label: "Author",
    type: :string,
    width: "180px",
    sql: "posts.author_id",      # filter by id (select options are [name, id])
    sort_sql: "authors.name",    # sort by the joined name
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Author.order(:name).pluck(:name, :id).map { |name, id| [ name, id ] } },
    visible: true,
    formatter: ->(value, record) {
      author_name = record.author.name
      if record.author.verified
        "#{h(author_name)} <span class='text-green-600'>✓</span>".html_safe
      else
        author_name
      end
    }

  column :category,
    label: "Category",
    type: :badge,  # Uses default 120px width
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Post.distinct.pluck(:category).compact.sort },
    visible: true,
    formatter: {
      type: :badge,
      options: {
        colors: {
          "Technology" => "blue",
          "Design" => "purple",
          "Business" => "green",
          "Lifestyle" => "yellow",
          "Travel" => "indigo",
          "Food" => "pink",
          "Health" => "red",
          "Education" => "cyan"
        }
      }
    }

  column :status,
    label: "Status",
    type: :badge,
    width: "110px",
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: [ "published", "draft", "archived" ],
    visible: true,
    formatter: {
      type: :badge,
      options: {
        colors: {
          "published" => "green",
          "draft" => "yellow",
          "archived" => "gray"
        }
      }
    }

  column :featured,
    label: "Featured",
    type: :boolean,
    width: "90px",
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: [ [ "Yes", true ], [ "No", false ] ],
    visible: true,
    formatter: ->(value, record) {
      if value
        '<span class="text-yellow-500 text-lg">⭐</span>'.html_safe
      else
        '<span class="text-gray-300">☆</span>'.html_safe
      end
    }

  column :views_count,
    label: "Views",
    type: :integer,
    width: "100px",
    sortable: true,
    visible: true,
    formatter: :number,
    formatter_options: { compact: true, zero: "0" }

  column :likes_count,
    label: "Likes",
    type: :integer,
    width: "80px",
    sortable: true,
    visible: true,
    formatter: ->(value, record) {
      count = value || 0
      "❤️ #{count}".html_safe
    }

  column :comments_count,
    label: "Comments",
    type: :integer,
    width: "100px",
    sql: "(SELECT COUNT(*) FROM comments WHERE comments.post_id = posts.id)",
    virtual: true,
    value: ->(post) { post.comments.size },
    sortable: true,
    visible: true,
    formatter: ->(value, record) { "💬 #{value}" }

  column :reading_time,
    label: "Read Time",
    type: :integer,
    width: "100px",
    sortable: true,
    visible: true,
    formatter: :number,
    formatter_options: { unit: "min", zero: "-" }

  # Several values in one cell: :tags takes an Array (here from a `value:` Proc)
  column :labels,
    label: "Labels",
    type: :string,
    width: "230px",
    visible: true,
    value: ->(post) { [ post.status, (post.featured ? "featured" : nil) ].compact },
    formatter: :tags,
    formatter_options: { limit: 2, colors: { "featured" => "yellow", "published" => "green", "draft" => "gray" } }

  column :published_at,
    label: "Published",
    type: :datetime,  # Uses default 180px width
    sortable: true,
    filterable: true,
    filter_type: :date,
    visible: true,
    formatter: ->(value, record) {
      if value
        time_ago = ((Time.now - value) / 86400).round
        if time_ago == 0
          "Today"
        elsif time_ago == 1
          "Yesterday"
        elsif time_ago < 7
          "#{time_ago}d ago"
        elsif time_ago < 30
          "#{(time_ago / 7).round}w ago"
        else
          value.strftime("%b %d, %Y")
        end
      else
        "Not published"
      end
    }

  column :created_at,
    label: "Created",
    type: :datetime,
    sortable: true,
    visible: false,  # Hidden by default
    formatter: :date,
    formatter_options: { format: :short }

  column :actions,
    label: "Actions",
    type: :action,
    width: "150px",  # Wider for multiple actions
    visible: true,
    pinned: :right,  # Pinned to right by default
    formatter: :action,
    formatter_options: {
      actions: [
        {
          label: "View",
          url: ->(record) { "#post-#{record.id}" },
          color: "primary"
        },
        {
          label: "Edit",
          url: ->(record) { "#edit-post-#{record.id}" }
        },
        {
          label: "Delete",
          url: ->(record) { "#delete-post-#{record.id}" },
          method: :delete,
          color: "danger",
          confirm: "Are you sure?"
        }
      ]
    }

  # Table settings - Enable infinite scroll for large dataset
  per_page 50
  per_page_options [ 25, 50, 100, 200 ]
  default_sort :published_at, :desc
  infinite_scroll true
  table_min_height "500px"
  table_max_height "700px"

  # Example: Hide filters button (uncomment to test)
  # show_filters_button false
end
