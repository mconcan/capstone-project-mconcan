#
# Server for xG app
# Updated 5/18/21
# Megan Concannon
#

library(shiny)
library(tidyverse)
library(ggplot2)
library(ggforce)
library(plotly)
library(ggiraph)
source("nhl_rink_plot.R")
source("process_data.R")

#Setup#######
teams = data.frame(
  team_names = c("Anaheim Ducks", "Arizona Coyotes", "Boston Bruins", "Buffalo Sabres", "Calgary Flames", "Carolina Hurricanes", "Chicago Blackhawks", 
                 "Colorado Avalanche", "Columbus Blue Jackets", "Dallas Stars", "Detroit Red Wings", "Edmonton Oilers", "Florida Panthers", "Los Angeles Kings",
                 "Minnesota Wild", "Montreal Canadiens", "Nashville Predators", "New Jersey Devils", "New York Islanders", "New York Rangers", "Ottawa Senators",
                 "Philadephia Flyers", "Pittsburgh Penguins", "San Jose Sharks", "St. Louis Blues", "Tampa Bay Lightning", "Toronto Maple Leafs", "Vancouver Canucks",
                 "Vegas Golden Knights", "Washington Capitals", "Winnipeg Jets"),
  teams_abbrv = c("ANA", "ARI", "BOS", "BUF", "CGY", "CAR", "CHI","COL", "CBJ", "DAL", "DET", "EDM",
                  "FLA", "L.A.", "MIN", "MTL", "NSH", "N.J.", "NYI", "NYR", "OTT", "PHI", "PIT", "S.J.",
                  "STL", "T.B.", "TOR", "VAN", "VGK", "WSH", "WPG"))

seasons = read_csv("season_data.csv")
#reformat dates to be in yyyy-mm-dd format
seasons$start_date = format(as.Date(seasons$start_date, format = "%m-%d-%Y"), "%Y-%m-%d")
seasons$end_date = format(as.Date(seasons$end_date, format = "%m-%d-%Y"), "%Y-%m-%d")

#Virtual environment setup
PYTHON_DEPENDENCIES = c("pandas", "hockey_scraper")
virtualenv_dir = Sys.getenv('VIRTUALENV_NAME')
python_path = Sys.getenv('PYTHON_PATH')

# Create virtual env and install dependencies
reticulate::virtualenv_create(envname = virtualenv_dir, python = python_path)
reticulate::virtualenv_install(virtualenv_dir, packages = PYTHON_DEPENDENCIES, ignore_installed=TRUE)
reticulate::use_virtualenv(virtualenv_dir, required = T)

#####

shinyServer(function(input, output, session) {
  
  #initialize virtual environment + source python functions
  reticulate::use_virtualenv(virtualenv_dir, required = T)
  reticulate::source_python("scrape_game.py")
  
  #Update range of date inputs based on the season selected
  observeEvent(input$season, {
    updateDateInput(inputId = "date", min = seasons[seasons$year == input$season, ]$start_date, max = seasons[seasons$year == input$season, ]$end_date,
                    value = seasons[seasons$year == input$season, ]$start_date)
  })  
  
  #Warning - only 5v5 xG model exists right now
  observeEvent(input$game_state, {
    if(input$game_state == '5v4') {
      showModal(modalDialog(
        title = "5x4",
        "5x4 xG calculations are not currently supported, but shot maps are still generated",
        easyClose = TRUE,
        footer = NULL
      ))
    }
  })
  
  #Sample games to study
  observeEvent(input$prompt, {
    showModal(modalDialog(title = "Suggested Games",
                              HTML('Some sample games to study:<br>
                                          2020-2021 05/15/21 WSH vs BOS<br>
                                          2017-2018 06/07/18 WSH vs VGK<br>
                                          2017-2018 10/04/17 TOR vs WPG<br>'), easyClose = FALSE))
  })
  
  #Blank rinks to be displayed before output generated
  output$blank_rink <- renderPlot({
    nhl_rink_plot()
  })
  output$blank_rink2 <- renderPlot({
    nhl_rink_plot()
  })
  
  #
  # Generate rink diagram with xG information
  #
  rink_reactive <- eventReactive(input$submit, {
    t = teams[teams$team_names == input$team, ]$teams_abbrv
    scrape_game(as.character(input$date), t)
    scraped_data = read_csv("game_data.csv") #read from csv because pd df --> r df was not friendly
    
    if(nrow(scraped_data) == 0) { #no game played on that date
      girafe(ggobj = (nhl_rink_plot() + geom_label(aes(x = 0, y= 0, label="No game data available for the selected date"), fill = 'white',  color = "Red", size = 5)))
    } else {
      processed_data = process_data(scraped_data, input$game_state)
      team1_data = processed_data[processed_data$Ev_Team == t, ] #filter out desired team
      
      #create interactive plot
      girafe(ggobj = (nhl_rink_plot() + geom_point_interactive(data = team1_data, mapping = aes(x = graph_xC, y = graph_yC, 
                                                                                                color = as.factor(Event), 
                                                                                                tooltip = summary_text, data_id = Type)) + 
                        theme(legend.title = element_blank())),
             options = list(opts_zoom(max = 5)))
    }
  })
  
  #
  # Generate rink diagram with xG information for simulated shot
  #
  sim_rink_reactive <- eventReactive(input$submit2, {
    points = data.frame("x" = c(input$xloc, input$xL), "y" = c(input$yloc, input$yL), text = c("Shot Location", "Last Event"))
    #calculate parameters from inputs
    dat = data.frame("xC" = input$xloc,
                     "yC" = input$yloc,
                     "xC_last" = input$xL,
                     "yC_last" = input$yL,
                     "distance" = dist(input$xloc, input$yloc, input$net),
                     "angle" = angle(input$xloc, input$yloc, input$net),
                     "seconds_since_last" = input$sec,
                     "distance_from_last" = sqrt((as.numeric(input$xloc) - as.numeric(input$xL))^2 + (as.numeric(input$yloc) - as.numeric(input$yL))^2),
                     "prior_team_shot" = as.logical(input$ps),
                     "shot_type" = as.factor(toupper(input$shot_type)),
                     "goal_dif" = (input$gF - input$gA))
    load("xG_even_strength_model.rda")
    prediction = predict(xG_even_strength, dat, type="response")
    prediction = round(prediction, 3) 
    girafe(ggobj = (nhl_rink_plot() + geom_point_interactive(data = points, mapping = aes(x = x, y = y,
                                                                                          color = c("red", "blue"), size = 3, tooltip = text, data_id = x)) + 
                      theme(legend.position = "none") +
                      geom_label(aes(x = 0, y= 50, label=paste0("xG: ", prediction)), fill = 'white',  color = "Red", size = 5)),
           options = list(opts_zoom(max = 5)))
  })
  
  #
  # Generate game-level summary data
  #
  summary_reactive <- eventReactive(input$submit, {
    t = teams[teams$team_names == input$team, ]$teams_abbrv
    scrape_game(as.character(input$date), t)
    scraped_data = read_csv("game_data.csv")
    if(nrow(scraped_data) != 0) {
      processed_data = process_data(scraped_data, input$game_state)
      team1_data = processed_data[processed_data$Ev_Team == t, ]
      team2_data = processed_data[!(processed_data$Ev_Team == t), ]
      summarize_data(team1_data, team2_data)
    }
  })
  
  #Generate outputs
  output$rink <- renderGirafe({ 
    rink_reactive()
  })
  
  output$simulation_rink <- renderGirafe({
    sim_rink_reactive()
  })
  
  output$summary <- renderTable({
    summary_reactive()
  }, colnames = FALSE)
  
})
