require 'chroma-db'
require "logger"
require 'pry'

# Configure Chroma's host. Here you can specify your own host.
Chroma.connect_host = "http://172.27.0.2:8000"
Chroma.logger = Logger.new($stdout)
Chroma.log_level = Chroma::LEVEL_ERROR

# Check current Chrome server version
version = Chroma::Resources::Database.version
puts version
collection_name = 'test-collection'

binding.pry
puts "#{Chroma::Resources::Collection.get(collection_name)}"

# Create a new collection
unless Chroma::Resources::Collection.get(collection_name)
  collection = Chroma::Resources::Collection.create(collection_name, {lang: "ruby", gem: "chroma-db"})
else
  collection = Chroma::Resources::Collection.get(collection_name)
end

binding.pry
# Add embeddings
embeddings = [
  Chroma::Resources::Embedding.new(id: "1", embedding: [1.3, 2.6, 3.1], metadata: {client: "chroma-rb"}, document: "ruby"),
  Chroma::Resources::Embedding.new(id: "2", embedding: [3.7, 2.8, 0.9], metadata: {client: "chroma-rb"}, document: "rails")
]

binding.pry
collection.add(embeddings)

binding.pry
vs = ChromaVectorStore.new(collection_name)
binding.pry
embedding = vs.get_embedding("1")
binding.pry
puts embedding
