###############################################
# Congifure Sequel for DB connections
###############################################
Sequel.extension :core_extensions
Sequel.extension :pg_array
Sequel.extension :pg_json

DB = Sequel.connect(
  adapter: :postgres,
  database: Config.database.name,
  host: Config.database.host,
  port: Config.database.port,
  user: Config.database.user,
  password: Config.database.password,
  loggers: DB_LOGGER
)

DB.extension :pg_streaming
DB.stream_all_queries = true

DB.extension :pagination
DB.extension :pg_array
DB.extension :pg_json

Sequel::Model.plugin :csv_serializer

def table_exist?(table_name)
  DB.fetch(
    <<~SQL
      SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '#{table_name}')
    SQL
  ).first[:exists]
end

def column_missing?(table_name, column_name)
  return if DB[table_name.to_sym].columns.include?(column_name.to_sym)

  yield
end

# def index_exist?(table_name, index_name)
#   DB.indexes(table_name.to_sym).any? { |name, _info| name.to_s == index_name.to_s }
# end

# unless table_exist?('queries')
#   DB.create_table(:queries) do
#     primary_key :id
#     String :query
#     String :next_page_token
#     Integer :page_number, default: 1
#     String :status, default: 'pending', null: false
#     String :process_id
#     String :finder_id
#     DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
#     DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
#   end
# end

# unless table_exist?('places')
#   DB.create_table(:places) do
#     primary_key :id
#     String :place_id, unique: true
#     String :status, default: 'pending', null: false
#     String :process_id
#     String :processor_id
#     String :name
#     Jsonb :raw_data

#     String :address
#     String :phone_number
#     String :international_phone_number
#     String :website

#     DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
#     DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
#   end
# end

# unless table_exist?('place_in_queries')
#   DB.create_table(:place_in_queries) do
#     primary_key :id
#     foreign_key :place_id, :places
#     foreign_key :query_id, :queries
#     DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
#     DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
#   end
# end

# [
#   { table: "places", column: "region", type: String },
#   { table: "places", column: "province", type: String },
#   { table: "places", column: "province_sign", type: String },
#   { table: "places", column: "zip_code", type: String },
#   { table: "places", column: "municipality", type: String },
#   { table: "places", column: "locality", type: String },
#   { table: "places", column: "business_type", type: String },

#   { table: "queries", column: "key", type: String, null: false, default: "default" },
# ].each do |column|
#   column_missing?(column[:table], column[:column]) do
#     DB.alter_table(column[:table]) do
#       add_column(
#         column[:column],
#         column[:type],
#         null: column[:null],
#         default: column[:default]
#       )
#     end
#   end
# end
