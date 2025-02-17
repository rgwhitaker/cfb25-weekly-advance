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
  # Log method entry
  puts "[DEBUG] Entering get_or_create_week_message"

  channel = event.server.channels.find { |ch| ch.name == 'week-advances' }
  if channel.nil?
    puts "[DEBUG] Could not find the 'week-advances' channel"
    return nil
  end

  # Log the channel
  puts "[DEBUG] Identified channel: #{channel.name}"

  # Attempt to retrieve the stored message ID
  saved_message_id = STORE.transaction do
    puts "[DEBUG] Attempting to fetch stored message_id"
    STORE[:message_id]
  end

  # Log the retrieved message ID (or lack of it)
  puts "[DEBUG] Retrieved saved_message_id: #{saved_message_id.inspect}"

  # Check if a valid saved_message_id exists
  if saved_message_id
    begin
      # Attempt to fetch the message from Discord
      message = channel.message(saved_message_id)
      puts "[DEBUG] Successfully fetched message with ID: #{saved_message_id}"
      return message
    rescue Discordrb::Errors::NoPermission
      puts "[DEBUG] Unable to fetch message with ID #{saved_message_id} due to missing permissions."
    rescue Discordrb::Errors::UnknownMessage
      puts "[DEBUG] Unable to fetch message with ID #{saved_message_id}, it might have been deleted."
    end
  else
    puts "[DEBUG] No saved message ID found (it is nil)"
  end

  # If we reach here, we need to create a new message
  embed = create_default_week_embed
  puts "[DEBUG] Sending a new embed message: #{embed.inspect}"

  # Send the new embed message
  message = channel.send_message('', false, embed)
  puts "[DEBUG] New embed message created with ID: #{message.id}"

  # Save the message ID to the persistent store
  STORE.transaction do
    puts "[DEBUG] Saving new message ID: #{message.id}"
    STORE[:message_id] = message.id
  end

  return message
end

def send_lobby_notification(server, content)
  # Replace 'lobby' with the actual lobby channel name
  lobby_channel = server.channels.find { |channel| channel.name == 'lobby' }
  return unless lobby_channel

  # Send the ping message to the lobby channel
  lobby_channel.send_message(content, false) # Set tts explicitly to false
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
