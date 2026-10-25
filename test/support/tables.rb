# Fixtures for table-name resolution tests
class OrderItemsTable < Infotable::Base
  query { Post.all }
  column :title
end

class NotATable
end

class ForbiddenTable < Infotable::Base
  query { User.all }
  authorize { |controller| controller.params[:let_me_in] == "1" }
  column :name
end

class OddPerPageTable < Infotable::Base
  query { User.all }
  per_page 15
  per_page_options [ 10, 25 ]
  column :name
end

class LinkedRowsTable < Infotable::Base
  query { User.all }
  row_link ->(user) { "/users/#{user.id}?a=1&b='2'" }
  column :name
end

class PinnedTable < Infotable::Base
  query { User.all }
  column :id, pinned: :left, sortable: true
  column :name
  column :email, pinned: :right
end

class AssocPostsTable < Infotable::Base
  query { Post.joins(:author) }
  column :title
  column :author, sql: "authors.name", sortable: true, filterable: true, value: ->(post) { post.author.name }
end

class ShoutFormatter < Infotable::Formatters::BaseFormatter
  def format(value, record, options = {})
    "#{value.to_s.upcase}!"
  end
end

# Aggregate table: GROUP BY + virtual (HAVING) column
class AuthorStatsTable < Infotable::Base
  query { Author.left_joins(:posts).group("authors.id").select("authors.*, COUNT(posts.id) AS posts_n") }
  per_page 2
  column :name, sortable: true
  column :posts_n, type: :integer, sortable: true, filterable: true, virtual: true, virtual_sql: "COUNT(posts.id)"
end

class CountlessTable < Infotable::Base
  query { User.all }
  countless
  per_page 5
  column :name, sortable: true
end

class PreloadedPostsTable < Infotable::Base
  query { Post.all }
  column :title
  column :author, includes: :author, value: ->(post) { post.author.name }
  column :commenters, includes: { comments: :author }, value: ->(post) { post.comments.map { _1.author.name }.join(",") }
end

class NPlusOnePostsTable < Infotable::Base
  query { Post.all }
  column :title
  column :author, value: ->(post) { post.author.name }
end

class SqlSourceTable < Infotable::Base
  query_sql "SELECT u.*, u.age * 2 AS double_age FROM users u WHERE u.status <> 'pending'", model: User
  per_page 2
  column :name, sortable: true, filterable: true, searchable: true
  column :double_age, type: :integer, sortable: true, filterable: true, sql: "users.double_age"
end
