# cfb25-weekly-advance
The Weekly Advance Bot is your ultimate assistant for managing your online dynasty in a college football league. This bot is designed to streamline the process of advancing weeks and keeping your league members informed and on schedule.

# Weekly Advance Bot

The **Weekly Advance Bot** is a Discord bot designed to manage and automate the weekly advancement process in a college football online dynasty. It notifies all league members of the current week and the deadline for game completion, ensuring a smooth and organized schedule.

## Features

- **Automated Week Advancement:**
  - The bot maintains a list of all possible weeks, from Week 1 to Bowl Week 4, including Conference Championships.
  - Each time the `!advance_week` command is used, the bot advances to the next week and notifies all members.

- **Deadline Calculation:**
  - The bot calculates the deadline for game completion by adding 48 hours to the current time.
  - Provides a clear and precise deadline in the notification message.

- **User-Friendly Commands:**
  - Simple command structure with `!advance_week` to initiate the week advancement process.

- **Real-Time Notifications:**
  - Instant notifications in your Discord server channel, keeping everyone up to date with the current week and deadlines.

## Setup

### Prerequisites
- Ruby installed on your system.
- A Discord bot token. You can create a bot and get a token from the [Discord Developer Portal](https://discord.com/developers/applications).

### Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/yourusername/weekly-advance-bot.git
   cd weekly-advance-bot
