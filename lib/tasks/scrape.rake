namespace :scrape do
  desc "Scrape all town halls from annuaire-des-mairies.com and save to DB. Use START_FROM=Tarn to resume."
  task town_halls: :environment do
    start_from = ENV['START_FROM']
    puts "Starting scrape:town_halls task#{start_from ? " (reprise à partir de #{start_from})" : ''}..."
    TownHallScraper.call(start_from: start_from)
    puts "Task finished."
  end
end
