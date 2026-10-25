# Create sample users for testing InfoTable
puts "Creating sample users..."

# Clear existing users
User.destroy_all

companies = [ "Acme Inc", "TechCorp", "DataSoft", "CloudBase", "DevOps Ltd", "InnovateLab", "StartupX", "Enterprise Co", "Digital Solutions", "CodeFactory" ]
statuses = [ "active", "inactive", "pending" ]
first_names = [ "John", "Jane", "Mike", "Sarah", "David", "Emily", "Alex", "Lisa", "Chris", "Anna", "Tom", "Mary", "Bob", "Sue", "Dan", "Kate", "Sam", "Emma", "Joe", "Amy" ]
last_names = [ "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Taylor", "Anderson", "Wilson", "Moore", "Thomas", "Jackson", "White", "Harris", "Martin", "Lee" ]

# Create 75 users to test pagination
75.times do |i|
  first_name = first_names[i % first_names.length]
  last_name = last_names[(i / first_names.length) % last_names.length]
  full_name = "#{first_name} #{last_name}"

  User.create!(
    name: full_name,
    email: "#{first_name.downcase}.#{last_name.downcase}#{i > 19 ? i : ''}@example.com",
    company: companies[i % companies.length],
    status: statuses[i % statuses.length],
    age: rand(22..65),
    score: rand(0.0..100.0).round(2),
    salary: rand(30000.0..150000.0).round(2)
  )
end

puts "Created #{User.count} users successfully!"

# Create sample authors, posts, and comments
puts "\nCreating sample authors..."

# Clear existing data
Comment.destroy_all
Post.destroy_all
Author.destroy_all

countries = [ "USA", "UK", "Canada", "Australia", "Germany", "France", "Spain", "Italy", "Japan", "Brazil", "India", "China", "Mexico", "Netherlands", "Sweden" ]
author_first_names = [ "John", "Jane", "Michael", "Sarah", "David", "Emma", "James", "Olivia", "Robert", "Sophia", "William", "Isabella", "Thomas", "Mia", "Charles", "Charlotte", "Daniel", "Amelia", "Matthew", "Harper", "Christopher", "Evelyn", "Andrew", "Abigail", "Joshua", "Emily", "Anthony", "Elizabeth", "Ryan", "Sofia" ]
author_last_names = [ "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White", "Harris", "Clark", "Lewis", "Robinson", "Walker", "Young", "King" ]

# Create 50 authors
authors = []
50.times do |i|
  first = author_first_names[i % author_first_names.length]
  last = author_last_names[(i / author_first_names.length) % author_last_names.length]
  name = "#{first} #{last}"

  authors << Author.create!(
    name: name,
    email: "#{first.downcase}.#{last.downcase}#{i > 29 ? i : ''}@authormail.com",
    bio: "Passionate writer and blogger with #{rand(1..15)} years of experience. Specializing in #{[ 'Technology', 'Design', 'Business', 'Lifestyle', 'Travel', 'Food', 'Health', 'Education' ].sample} content.",
    website: rand > 0.3 ? "https://#{first.downcase}#{last.downcase}.com" : nil,
    avatar_url: "https://i.pravatar.cc/150?img=#{i}",
    country: countries[i % countries.length],
    verified: [ true, true, true, false ].sample, # 75% verified
    followers_count: rand(100..500000),
    created_at: rand(5.years.ago..1.year.ago)
  )
end

puts "Created #{Author.count} authors successfully!"

# Create ~400 posts
puts "Creating sample posts..."

categories = [ "Technology", "Design", "Business", "Lifestyle", "Travel", "Food", "Health", "Education" ]
post_statuses = [ "published", "draft", "archived" ]

post_titles = [
  "Getting Started with Ruby on Rails",
  "10 Tips for Better UI Design",
  "The Future of Remote Work",
  "Healthy Eating on a Budget",
  "Exploring the Mountains of Colorado",
  "Essential Web Development Tools",
  "Mindfulness for Busy Professionals",
  "Building Scalable Applications",
  "The Art of Public Speaking",
  "Traveling Solo: A Beginner's Guide",
  "Understanding Modern JavaScript",
  "Creating Engaging Content",
  "Productivity Hacks That Work",
  "The Rise of AI in Business",
  "Photography Tips for Beginners",
  "Cooking Italian Cuisine at Home",
  "Yoga for Stress Relief",
  "Building Your Personal Brand",
  "The Science of Sleep",
  "Mastering CSS Grid Layout",
  "Entrepreneurship in 2024",
  "Best Hiking Trails in Europe",
  "Healthy Breakfast Ideas",
  "Introduction to Machine Learning",
  "Writing Better Code Comments",
  "Social Media Marketing Strategies",
  "Meditation for Inner Peace",
  "Database Design Best Practices",
  "Public Relations in the Digital Age",
  "Budget Travel Tips",
  "Understanding TypeScript",
  "Color Theory for Designers",
  "Leadership Skills Development",
  "Plant-Based Diet Benefits",
  "Backpacking Through Asia",
  "Modern CSS Techniques",
  "Mental Health Awareness",
  "API Development Guide",
  "Effective Team Communication",
  "Weekend Getaway Ideas"
]

posts = []
400.times do |i|
  author = authors.sample
  category = categories.sample
  status = i < 350 ? "published" : post_statuses.sample # Most posts are published

  title_base = post_titles[i % post_titles.length]
  title = i < post_titles.length ? title_base : "#{title_base} - Part #{(i / post_titles.length) + 1}"

  published = status == "published"

  posts << Post.create!(
    title: title,
    body: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. #{[ 'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.', 'Ut enim ad minim veniam, quis nostrud exercitation ullamco.', 'Duis aute irure dolor in reprehenderit in voluptate velit.' ].join(' ')} " * rand(2..5),
    author: author,
    status: status,
    category: category,
    views_count: published ? rand(10..50000) : 0,
    likes_count: published ? rand(0..5000) : 0,
    featured: [ true, false, false, false, false ].sample, # 20% featured
    reading_time: rand(2..15),
    published_at: published ? rand(2.years.ago..Time.now) : nil,
    created_at: rand(2.years.ago..1.week.ago)
  )
end

puts "Created #{Post.count} posts successfully!"

# Create comments
puts "Creating sample comments..."

comment_statuses = [ "approved", "pending", "spam" ]
comment_texts = [
  "Great article! This really helped me understand the topic better.",
  "Thanks for sharing this. Very informative!",
  "I disagree with some points, but overall a good read.",
  "Could you elaborate more on this topic?",
  "This is exactly what I was looking for!",
  "Interesting perspective. I never thought about it that way.",
  "Very well written and easy to follow.",
  "I have a question about the third point...",
  "Awesome content! Keep it up!",
  "This doesn't make sense to me. Can you clarify?",
  "I've been following your work for a while now. Love it!",
  "Not sure I agree with this conclusion.",
  "Brilliant! Sharing this with my team.",
  "This helped solve my problem. Thank you!",
  "More posts like this please!",
  "I tried this approach and it worked perfectly.",
  "Great insights! Very practical advice.",
  "This is outdated. Any updates?",
  "Exactly what I needed today. Thanks!",
  "Bookmarking this for later reference."
]

# Add 2-8 comments per published post (around 1200-2000 comments total)
published_posts = posts.select { |p| p.status == "published" }
published_posts.each do |post|
  rand(2..8).times do
    author = authors.sample
    status = [ comment_statuses[0] ] * 8 + [ comment_statuses[1] ] * 1 + [ comment_statuses[2] ] * 1 # 80% approved, 10% pending, 10% spam

    Comment.create!(
      body: comment_texts.sample + (rand > 0.7 ? " #{comment_texts.sample}" : ""),
      post: post,
      author: author,
      status: status.sample,
      likes_count: rand(0..100),
      flagged: [ false, false, false, false, false, false, false, false, false, true ].sample, # 10% flagged
      created_at: rand(post.created_at..Time.now)
    )
  end
end

puts "Created #{Comment.count} comments successfully!"

puts "\n✅ Seed data created successfully!"
puts "📊 Summary:"
puts "  - #{User.count} users"
puts "  - #{Author.count} authors"
puts "  - #{Post.count} posts"
puts "  - #{Comment.count} comments"
