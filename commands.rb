# commands.rb
require 'active_support/time'
require_relative 'config'
require_relative 'helpers'

def format_deadline(deadline_str)
  deadline = Time.parse(deadline_str).in_time_zone('Eastern Time (US & Canada)')
  deadline.strftime('%A at %I:%M %p')
end

# Main method for registering all commands
def register_commands(bot, store)
  initialize_week_advances(bot, store)
  advance_week(bot, store)
  set_week(bot, store)
  set_deadline(bot, store)
  status_week_advances(bot, store)
  reset_week_advances(bot, store)
end

# Command: !initialize
def initialize_week_advances(bot, store)
  bot.command(:initialize) do |event|
    # Ensure the user has permissions
    user = event.server.member(event.user.id)
    unless user.permission?(:administrator) || user.id == event.server.owner.id
      event.respond("❌ You don’t have the required permissions.")
      next
    end

    # Step 1: Find or create the channel
    channel_name = 'week-advances'
    channel = event.server.channels.find { |ch| ch.name == channel_name }
    unless channel
      begin
        channel = event.server.create_channel(channel_name, 0) # 0 = text channel
        event.respond("✅ Created channel `#{channel_name}`.")
      rescue StandardError => e
        event.respond("❌ Failed to create channel: #{e.message}")
        next
      end
    end

    # Step 2: Create a new message and store its ID
    embed = Discordrb::Webhooks::Embed.new(
      title: "Welcome to the New Week!",
      description: "🏈 This is your updated week setup! Go get it! 🏈",
      color: 0x00FF00 # Green color for success
    )
    new_message = channel.send_message('', false, embed)
    store.transaction do |data|
      data[:message_id] = new_message.id
    end
    event.respond("✅ Created a new message and saved its ID.")
  end
end

# Command: !advance_week
def advance_week(bot, store)
  bot.command :advance_week do |event, duration_in_hours = '48'|
    begin
      # Load data from S3 bucket
      puts "[DEBUG] advance_week: Attempting to load data from S3"
      current_week_index, current_deadline, message_id = load_data_from_s3(store)
      puts "[DEBUG] advance_week: Loaded data - current_week_index=#{current_week_index.inspect}, current_deadline=#{current_deadline.inspect}, message_id=#{message_id.inspect}"

      # Ensure message ID is not nil
      if message_id.nil?
        event.respond "Error: No existing message found. Please run `!initialize` first."
        puts "[ERROR] No existing message found: message_id=#{message_id.inspect}"
        next
      end

      # Find the 'week-advances' channel and load the message
      channel = event.server.channels.find { |ch| ch.name == 'week-advances' }
      unless channel
        event.respond "The 'week-advances' channel was not found."
        next
      end

      message = channel.load_message(message_id)
      unless message
        event.respond "The message with ID #{message_id} was not found. Please run `!initialize` first."
        next
      end

      current_time = Time.now.in_time_zone('Eastern Time (US & Canada)')
      advance_time = calculate_advance_time(current_time, duration_in_hours)
      advance_time_str = format_deadline(advance_time.to_s)
      current_week_index = (current_week_index + 1) % WEEKS.length

      # Update data in S3 bucket
      puts "[DEBUG] advance_week: Attempting to store data to S3"
      store_data_to_s3(store, current_week_index, advance_time_str, message.id)
      puts "[DEBUG] advance_week: Stored data - current_week_index=#{current_week_index.inspect}, advance_time_str=#{advance_time_str.inspect}, message_id=#{message.id.inspect}"

      next_week_name = WEEKS[current_week_index]
      description = "🏈 The deadline to complete your recruiting and games is #{advance_time_str}. 🏈"

      begin
        update_embed_message(message, "#{next_week_name} has started!", description, message.embeds.first)
        event.respond "Week advanced to #{next_week_name}, and the deadline is set to #{advance_time_str}."
        link = message_link(event.server.id, message.channel.id, message.id)
        notify_lobby(event.server, "week has advanced to **#{next_week_name}**", advance_time_str, link)
      rescue Discordrb::Errors::NoPermission
        event.respond "I don't have permission to edit messages in the 'week-advances' channel. Please check my permissions."
      end
    rescue => e
      event.respond "An error occurred: #{e.message}"
      puts "[ERROR] An error occurred in advance_week: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end

# Command: !set_week
def set_week(bot, store)
  bot.command :set_week do |event, *week_parts|
    message = get_or_create_week_message(event, store)
    unless message
      event.respond "The 'week-advances' channel was not found or unable to create the message."
      next
    end

    week = week_parts.join(" ").strip

    begin
      current_week_index = find_week_index(week) # Helper method to find the week index
      store.transaction do
        store[:current_week_index] = current_week_index
      end

      # Update embed with unchanged deadline and new week
      current_week_name = WEEKS[current_week_index]
      existing_deadline = store.transaction { store[:current_deadline] || "No deadline set" }
      new_title = "#{current_week_name} has started!"
      new_description = "🏈 The deadline to complete your recruiting and games is #{existing_deadline}. 🏈"

      update_embed_message(message, new_title, new_description, message.embeds.first)
      event.respond "Current week set to **#{current_week_name}**, and the deadline remains unchanged."
      link = message_link(event.server.id, message.channel.id, message.id)
      notify_lobby(event.server, "current week has been manually set to **#{current_week_name}**", existing_deadline, link)
    rescue => e
      event.respond "An error occurred while setting the current week: #{e.message}"
    end
  end
end

# Command: !set_deadline
def set_deadline(bot, store)
  bot.command :set_deadline do |event, *args|
    deadline_input = args.join(" ").strip
    update_deadline(event, deadline_input, store) # Use a helper for deadline logic
  end
end

# Command: !status
def status_week_advances(bot, store)
  bot.command(:status) do |event|
    saved_message_id = store.transaction { store[:message_id] }
    channel = event.server.channels.find { |ch| ch.name == 'week-advances' }
    status = "📊 **Bot Status**:\n"
    status += "- Channel: `#{channel.nil? ? 'Not Found' : channel.name}`\n"
    status += "- Stored Message ID: `#{saved_message_id || 'None'}`\n"

    if saved_message_id && channel
      begin
        channel.load_message(saved_message_id.to_s)
        status += "- Message Status: ✅ Found\n"
      rescue Discordrb::Errors::UnknownMessage
        status += "- Message Status: ❌ Not Found\n"
      rescue StandardError => e
        status += "- Message Status: ❌ Error: #{e.message}\n"
      end
    end

    event.respond(status)
  end
end

# Command: !reset
def reset_week_advances(bot, store)
  bot.command(:reset) do |event|
    unless event.user.has_permission?(:administrator) || event.user.id == event.server.owner.id
      event.respond("❌ You don't have permissions to reset the bot.")
      next
    end

    store.transaction { store.clear }
    event.respond("✅ Bot state has been reset. Please run `!initialize` to set it up again.")
  end
end