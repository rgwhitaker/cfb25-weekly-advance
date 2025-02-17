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

    # Step 2: Get current message ID from the store
    message_id = nil
    store.transaction do |data|
      message_id = data[:message_id]
    end

    # Step 3: Try to load the message using the stored ID
    message = nil
    if message_id
      begin
        message = channel.load_message(message_id)
        event.respond("ℹ️ Located existing message with ID #{message_id}.")
      rescue Discordrb::Errors::UnknownMessage
        event.respond("⚠️ Message ID #{message_id} not found. Creating a new one.")
        message = nil
      end
    else
      event.respond("ℹ️ No message ID stored. Creating a new message.")
    end

    # Step 4: Create or edit the message
    embed = Discordrb::Webhooks::Embed.new(
      title: "Welcome to the New Week!",
      description: "🏈 This is your updated week setup! Go get it! 🏈",
      color: 0x00FF00 # Green color for success
    )

    if message
      # Update the existing message
      message.edit('', embed)
      event.respond("✅ Successfully updated the existing message.")
    else
      # Create a new message and store its ID
      new_message = channel.send_message('', false, embed)
      store.transaction do |data|
        data[:message_id] = new_message.id
      end
      event.respond("✅ Created a new message and saved its ID.")
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