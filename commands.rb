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
    unless event.user.has_permission?(:administrator) || event.user.id == event.server.owner.id
      event.respond("❌ You don't have permissions to initialize the bot.")
      next
    end

    # Create or find the 'week-advances' channel
    channel_name = 'week-advances'
    channel = event.server.channels.find { |ch| ch.name == channel_name }
    if channel.nil?
      begin
        channel = event.server.create_channel(channel_name, 0) # 0 = text channel
        event.respond("✅ Created new channel: `#{channel_name}`.")
      rescue StandardError => e
        event.respond("❌ Failed to create `#{channel_name}` channel: #{e.message}")
        next
      end
    else
      event.respond("✅ Found existing channel: `#{channel_name}`.")
    end

    # Create or retrieve stored message
    saved_message_id = store.transaction { store[:message_id] }
    if saved_message_id
      begin
        existing_message = channel.load_message(saved_message_id.to_s)
        if existing_message
          event.respond("✅ Found existing week message with ID #{saved_message_id}.")
          next
        end
      rescue Discordrb::Errors::UnknownMessage
        event.respond("⚠️ Message ID #{saved_message_id} not found in `#{channel_name}`.")
      rescue StandardError => e
        event.respond("❌ Error loading message ID #{saved_message_id}: #{e.message}")
      end
    end

    # Create a new message if no valid message exists
    begin
      embed = create_default_week_embed
      new_message = channel.send_message('', false, embed)
      store.transaction do |data|
        data[:message_id] = new_message.id
        data[:current_week_index] = 0
      end
      event.respond("✅ Created new week message and saved it with ID #{new_message.id}.")
    rescue StandardError => e
      event.respond("❌ Failed to create a new message in `#{channel_name}`: #{e.message}")
    end
  end
end

# Command: !advance_week
def advance_week(bot, store)
  bot.command :advance_week do |event, duration_in_hours = '48'|
    message = get_or_create_week_message(event, store)
    unless message
      event.respond "The 'week-advances' channel was not found or unable to create the message."
      next
    end

    current_week_index = store.transaction { store[:current_week_index] } || 0
    current_week_name = WEEKS[current_week_index]
    current_time = Time.now.in_time_zone('Eastern Time (US & Canada)')
    advance_time = calculate_advance_time(current_time, duration_in_hours)
    advance_time_str = format_deadline(advance_time.to_s)
    current_week_index = (current_week_index + 1) % WEEKS.length

    store.transaction do
      store[:current_week_index] = current_week_index
      store[:current_deadline] = advance_time_str
    end

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