#
# Functions to scrape game/schedule information
# Updated 5/18/21
# Megan Concannon
#

import pandas as pd
import numpy
import hockey_scraper

#
# Scrape game data for the given data and team
#
def scrape_game(date, team):
  scraped_data = hockey_scraper.scrape_date_range(date, date, False, data_format='Pandas')
  scraped_data = scraped_data['pbp']
  scraped_data = scraped_data[(scraped_data['Away_Team']==team) | (scraped_data['Home_Team']==team)]
  scraped_data.to_csv("game_data.csv", index=False)
  return(scraped_data)

#
# Scrape schedule for the given team between start and end date
#
def scrape_schedule(team, start_date, end_date):
  sched =  hockey_scraper.scrape_schedule(start_date, end_date)
  sched = sched[(sched['home_team']==team) | (sched['away_team']==team)]
  return(sched['date'])
  
