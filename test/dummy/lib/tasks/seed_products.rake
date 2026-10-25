namespace :db do
  desc "Seed products table with 100k+ records"
  task seed_products: :environment do
    puts "Starting product seeding..."
    start_time = Time.now

    # Clear existing products
    Product.delete_all
    puts "Cleared existing products"

    # Product data arrays for random selection
    categories = [ "Electronics", "Clothing", "Home & Garden", "Sports & Outdoors", "Books", "Toys & Games", "Health & Beauty", "Automotive", "Food & Beverage", "Office Supplies" ]
    manufacturers = [ "TechCorp", "GlobalMfg", "PrimeGoods", "QualityPro", "InnovateLtd", "EliteProducts", "TopBrand", "MegaCorp", "SuperManufacture", "BestFactory" ]
    adjectives = [ "Premium", "Deluxe", "Professional", "Standard", "Economy", "Ultra", "Pro", "Elite", "Essential", "Advanced" ]
    nouns = [ "Widget", "Device", "Tool", "System", "Kit", "Set", "Pack", "Bundle", "Unit", "Module" ]

    # Batch size for insert
    batch_size = 1000
    total_records = 100_000

    puts "Creating #{total_records} products in batches of #{batch_size}..."

    (total_records / batch_size).times do |batch|
      products = []

      batch_size.times do |i|
        record_num = (batch * batch_size) + i + 1

        category = categories.sample
        manufacturer = manufacturers.sample
        adjective = adjectives.sample
        noun = nouns.sample

        # Generate product data
        name = "#{adjective} #{noun} #{record_num}"
        sku = "SKU-#{category[0..2].upcase}-#{rand(10000..99999)}"
        description = "This is a #{adjective.downcase} #{noun.downcase} from #{manufacturer}. Perfect for professional and personal use. Category: #{category}."
        price = rand(9.99..999.99).round(2)
        cost = (price * rand(0.3..0.7)).round(2)
        stock_quantity = rand(0..1000)
        rating = rand(1.0..5.0).round(1)
        active = [ true, true, true, false ].sample  # 75% active
        featured = [ true, false, false, false ].sample  # 25% featured
        manufactured_date = Date.today - rand(1..1825).days  # Random date in last 5 years
        discontinued_at = active ? nil : (rand < 0.3 ? DateTime.now - rand(1..365).days : nil)

        products << {
          name: name,
          sku: sku,
          description: description,
          category: category,
          price: price,
          cost: cost,
          stock_quantity: stock_quantity,
          rating: rating,
          active: active,
          featured: featured,
          manufacturer: manufacturer,
          manufactured_date: manufactured_date,
          discontinued_at: discontinued_at,
          created_at: Time.now,
          updated_at: Time.now
        }
      end

      # Bulk insert
      Product.insert_all(products)

      print "\rProgress: #{((batch + 1) * batch_size * 100.0 / total_records).round(1)}%"
    end

    puts "\n✓ Created #{Product.count} products"
    puts "Time taken: #{(Time.now - start_time).round(2)} seconds"
  end
end
