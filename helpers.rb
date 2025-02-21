# helpers.rb
require 'discordrb'
require 'date'
require 'time'


# Helper function to calculate advance time while skipping Saturdays
def calculate_advance_time(start_time, duration_in_hours)
  advance_time = start_time + (duration_in_hours.to_i * 60 * 60)
  while advance_time.saturday?
    advance_time += 1.day
  end
  advance_time
end

# Helper function to create embed messages
def create_embed(title, description, color, image_url, footer_text, footer_icon_url)
  embed = Discordrb::Webhooks::Embed.new(
    title: title,
    description: description,
    color: color,
    image: Discordrb::Webhooks::EmbedImage.new(url: image_url)
  )
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(
    text: footer_text,
    icon_url: footer_icon_url
  )
  embed
end

# Helper function to get or reuse the week message
def get_or_create_week_message(event, store)
  # Find or create the 'week-advances' channel
  channel_name = 'week-advances'
  channel = event.server.channels.find { |ch| ch.name == channel_name }
  unless channel
    channel = event.server.create_channel(channel_name, 0)
  end

  # Try loading the existing message by ID
  message_id = store.transaction { store[:message_id] }
  if message_id
    begin
      return channel.load_message(message_id) # Load the message successfully
    rescue Discordrb::Errors::UnknownMessage
      # Message was deleted; we will need to recreate it
    end
  end

  # If no message exists, create a new one and save its ID
  embed = Discordrb::Webhooks::Embed.new(
    title: "Initialization Message",
    description: "🏈 Current week and deadline will be shown here. 🏈",
    color: 0x00FF00 # Green for success
  )
  new_message = channel.send_message('', false, embed)
  store.transaction { |data| data[:message_id] = new_message.id } # Save the new message ID

  new_message
end

def send_lobby_notification(server, content)
  # Replace 'lobby' with the actual lobby channel name
  lobby_channel = server.channels.find { |channel| channel.name == 'lobby' }
  return unless lobby_channel

  # Send the ping message to the lobby channel
  safe_send_message(lobby_channel, content, nil)
end

def message_link(guild_id, channel_id, message_id)
  "https://discord.com/channels/#{guild_id}/#{channel_id}/#{message_id}"
end

# Helper to resolve next occurrence of a specific day (e.g., "Tuesday")
def next_weekday(day_name)
  current_time = Time.now
  target_day = Date::DAYNAMES.find_index(day_name.capitalize)
  return nil unless target_day

  days_ahead = (target_day - current_time.wday) % 7
  days_ahead = 7 if days_ahead == 0 # If today is the target day, move it to the next week
  current_time + (days_ahead * 24 * 60 * 60) # Add days in seconds
end

# Helper function to create the default embed for the week message
def create_default_week_embed
  title = "Welcome to the New Week!"
  description = "🏈 A new week has begun! Complete your recruiting and games before the deadline. 🏈"
  color = 0x00FF00 # Green color
  image_url = "https://example.com/placeholder-image.png" # Replace with your embed image URL
  footer_text = "League Updates"
  footer_icon_url = "https://example.com/placeholder-footer-icon.png" # Replace with your footer icon URL

  embed = create_embed(title, description, color, image_url, footer_text, footer_icon_url)

  # Debug: Inspect the embed object
  puts "[DEBUG] Created default embed: #{embed.inspect}"

  embed
end

# Shared helper function to update embed messages
def update_embed_message(message, title, description, original_embed)
  embed = create_embed(title, description, original_embed.color || 0x00FF00, EMBED_IMAGE_URL,
                       FOOTER_TEXT, TROPHY_IMAGE_URL)
  safe_edit_message(message, '', embed)
end

# Shared helper function to notify the lobby channel
def notify_lobby(server, title, deadline, link)
  content = "📢 everyone, the **#{title}**! 🏈\nDeadline: **#{deadline}**.\nView the full announcement here: [Click to view](#{link})"
  send_lobby_notification(server, content)
end

def safe_send_message(channel, content, embed = nil)
  begin
    channel.send_message(content, false, embed)
  rescue Discordrb::Errors::RateLimited => e
    # Handle rate limits by sleeping for the specified amount of time
    puts "[WARN] Rate-limited! Sleeping for #{e.retry_after} seconds..."
    sleep(e.retry_after)
    retry
  rescue => e
    # Log unexpected errors (e.g., network or API issues)
    puts "[ERROR] Failed to send message: #{e.message}"
  end
end

def safe_edit_message(message, content, embed)
  begin
    message.edit(content, embed)
  rescue Discordrb::Errors::RateLimited => e
    puts "[WARN] Rate-limited! Sleeping for #{e.retry_after} seconds..."
    sleep(e.retry_after)
    retry
  rescue => e
    puts "[ERROR] Failed to edit message: #{e.message}"
  end
end

def load_data_from_s3(store)
  puts "[DEBUG] load_data_from_s3: Starting data load from S3"

  # First, explicitly load the YAML from S3
  raw_data = store.load_store('store.yml')
  puts "[DEBUG] Raw YAML data from S3: #{raw_data.inspect}"

  # If raw_data is nil or empty, return early
  if raw_data.nil? || raw_data.empty?
    puts "[ERROR] No data found in S3 store"
    return [nil, nil, nil]
  end

  store.transaction do |data|
    message_id = data[:message_id]
    if message_id.nil?
      puts "[ERROR] No message_id found in store data"
      return [nil, nil, nil]
    end

    current_week_index = data[:current_week_index] || 0
    current_deadline = data[:current_deadline] || "No deadline set"

    puts "[DEBUG] Loaded data from S3:"
    puts "- message_id: #{message_id}"
    puts "- current_week_index: #{current_week_index}"
    puts "- current_deadline: #{current_deadline}"

    [current_week_index, current_deadline, message_id]
  end
rescue => e
  puts "[ERROR] Failed to load data from S3: #{e.message}"
  puts "[ERROR] Backtrace: #{e.backtrace[0..5].join("\n")}"
  [nil, nil, nil]
end

def store_data_to_s3(store, current_week_index, current_deadline, message_id)
  puts "[DEBUG] store_data_to_s3: Storing data - current_week_index=#{current_week_index.inspect}, current_deadline=#{current_deadline.inspect}, message_id=#{message_id.inspect}"
  store.transaction do |data|
    data[:current_week_index] = current_week_index
    data[:current_deadline] = current_deadline
    data[:message_id] = message_id
  end
  # Verify the stored data
  stored_data = store.transaction { store.roots }
  puts "[DEBUG] store_data_to_s3: Verified stored data - #{stored_data.inspect}"
rescue => e
  puts "[ERROR] Failed to store data to S3: #{e.message}\n#{e.backtrace.join("\n")}"
end