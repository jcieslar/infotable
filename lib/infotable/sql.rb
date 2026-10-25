module Infotable
  # The few SQL fragments that differ between databases (PostgreSQL, SQLite).
  module Sql
    module_function

    def postgresql?(connection)
      connection.adapter_name.match?(/postg/i)
    end

    def sqlite?(connection)
      connection.adapter_name.match?(/sqlite/i)
    end

    # Case-insensitive LIKE with one bind placeholder. SQLite's LIKE ignores case for ASCII only;
    # PostgreSQL gets a real ILIKE.
    def like(connection, ref, negate: false)
      operator = postgresql?(connection) ? "ILIKE ?" : "LIKE ?"
      operator += " ESCAPE '\\'" if sqlite?(connection) # SQLite has no default escape character
      "#{'NOT ' if negate}#{ref} #{operator}"
    end
  end
end
