# pg_client.rb
require 'pg'

class PGClient
  def initialize(host, dbname, user, password)
    @connection = PG::Connection.open(:host => host, :dbname => dbname, :user => user, :password => password)
  end

  def save_message(message)
    res = @connection.exec_params(
      'INSERT INTO embedding_texts (content) VALUES ($1) RETURNING id',
      [message]
    )

    res[0]['id']
  end

   def table_exists?(table_name)
    res = @connection.exec_params(
      "SELECT EXISTS (
         SELECT FROM pg_tables
         WHERE  schemaname = 'public'
         AND    tablename  = $1
       )",
      [table_name]
    )
    res[0]['exists'] == 't'
  end

  def create_table(table_name, options_hash)
    fields = options_hash.map do |field, type|
      type = case type.to_sym
             when :string then 'text'
             when :integer then 'integer'
             when :float then 'float'
             when :datetime then 'timestamp'
             when :boolean then 'boolean'
             else
               type
             end
      "#{field} #{type}"
    end.join(', ')

    query = "CREATE TABLE IF NOT EXISTS #{table_name} (#{fields});"
    @connection.exec(query)
  end
end

