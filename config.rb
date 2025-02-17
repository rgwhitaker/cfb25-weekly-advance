# config.rb
require 'yaml/store'

# Define the list of possible weeks
# Define the real list of possible weeks
WEEKS = [
  "Preseason",
  "Week 0",
  "Week 1",
  "Week 2",
  "Week 3",
  "Week 4",
  "Week 5",
  "Week 6",
  "Week 7",
  "Week 8",
  "Week 9",
  "Week 10",
  "Week 11",
  "Week 12",
  "Week 13",
  "Week 14",
  "Conference Championship Week",
  "Week 16",
  "Bowl Week 1",
  "Bowl Week 2",
  "Bowl Week 3",
  "National Championship",
  "End of Season Recap",
  "Players Leaving",
  "Off-Season Recruiting Week 1",
  "Off-Season Recruiting Week 2",
  "Off-Season Recruiting Week 3",
  "National Signing Day",
  "Training Results",
  "Off-Season"
]

# Initialize data store for persistence
STORE = YAML::Store.new("week_data.yml")

# URLs for the images
TROPHY_IMAGE_URL = 'https://th.bing.com/th/id/OIP.nAcdTDznBgncq5df6MocPwAAAA?rs=1&pid=ImgDetMain'
EMBED_IMAGE_URL = 'https://www.operationsports.com/wp-content/uploads/2024/02/IMG_4609.jpeg'

# Footer text and icon URL
FOOTER_TEXT = "2024 Florida Gators | 2025 Florida Gators | 2027 Arizona State Sun Devils"
