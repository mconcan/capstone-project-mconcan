#
# UI for xG app
# Updated 5/18/21
# Megan Concannon
#

library(shiny)
library(shinythemes)
library(shinyWidgets)
library(tidyverse)
library(shinycssloaders)
library(ggiraph)

#Setup#####
teams = data.frame(
    team_names = c("Anaheim Ducks", "Arizona Coyotes", "Boston Bruins", "Buffalo Sabres", "Calgary Flames", "Carolina Hurricanes", "Chicago Blackhawks", 
               "Colorado Avalanche", "Columbus Blue Jackets", "Dallas Stars", "Detroit Red Wings", "Edmonton Oilers", "Florida Panthers", "Los Angeles Kings",
               "Minnesota Wild", "Montreal Canadiens", "Nashville Predators", "New Jersey Devils", "New York Islanders", "New York Rangers", "Ottawa Senators",
               "Philadephia Flyers", "Pittsburgh Penguins", "San Jose Sharks", "St. Louis Blues", "Tampa Bay Lightning", "Toronto Maple Leafs", "Vancouver Canucks",
               "Vegas Golden Knights", "Washington Capitals", "Winnipeg Jets"),
    teams_abbrv = c("ANA", "ARI", "BOS", "BUF", "CGY", "CAR", "CHI","COL", "CBJ", "DAL", "DET", "EDM",
          "FLA", "L.A.", "MIN", "MTL", "NSH", "N.J.", "NYI", "NYR", "OTT", "PHI", "PIT", "S.J.",
          "STL", "T.B.", "TOR", "VAN", "VGK", "WSH", "WPG"))

#get team logos
team_imgs = vector()
for(i in 1:length(teams$teams_abbrv)) {
    team_imgs = c(team_imgs, sprintf(paste0("<img src='", teams$teams_abbrv[i], ".png' width=30px><div class='jhr'>%s</div></img>"), teams$team_names[i]))
}
teams$team_imgs = team_imgs

seasons = read_csv("season_data.csv") #start/end dates for each season
states = c("5x5", "5x4") #not dealing (yet) with more complicated scenarios (5v3, 3v3 etc)
shot_types = c("Tip-in", "Wrist Shot", "Slap Shot", "Snap Shot", "Backhand", "Wrap-Around")

######

shinyUI(fluidPage(theme = shinytheme("sandstone"),
                  navbarPage("NHL xG Predictor",
                             tabPanel("About",
                                      mainPanel(
                                          h1("Welcome to the NHL xG Predictor!"),
                                          h3("How It Works"),
                                          p("This tool is based off of the work of numerous others, including: "),
                                          tags$a(href="https://hockeyviz.com/txt/xg4", 
                                                 "Micah Blake McCurdy"),
                                          br(),
                                          tags$a(href="http://moneypuck.com/about.htm", 
                                                "MoneyPuck.com"),
                                          br(),
                                          tags$a(href="https://evolving-hockey.com/blog/a-new-expected-goals-model-for-predicting-goals-in-the-nhl/", 
                                                 "EvolvingWild"),
                                          p("and many more, who have done some really interesting work in hockey statistics and predicting game features."),
                                          br(),
                                          p("Expected goals models are a way of determining how likely a shot is to become a goal. Theoretically, summing the xG throughout
                                          a game offers a picture of how many goals a team should have scored based on the quality of their shots. xG models are still quite
                                          limited by the data available (often, there is no information on shot speed, for example) and randomness, but they can offer a good
                                          picture of play quality througout a game.
                                          The basis of an xG model is a logistic
                                            regression, based on a variety of in-game parameters. In my model, I used the NHL's play by play data for the 2018-2019 season.
                                            The data was limited to a single season based on the time of scraping and processing, and it was scraped by "),
                                            tags$a(href = "https://hockey-scraper.readthedocs.io/en/latest/index.html", "Harry Shomer's 
                                            scraping package."),
                                          p("I then filtered out the important events - shots, 
                                            misses, goals, and blocked shots, and processed those events to create the metrics for my model, as shown below. For simplicity, and because
                                            it is a contested subject, the effects of individual player talent (i.e. in shooting skill) were omitted."),
                                          code("X Location, Y Location, Distance From Net, Angle From Net, X Coordinate of Last Event, Y Coordinate of Last Event, Distance from Last Event, 
                                          Time Since Last Event, Last Event was a Shot by the Same Team (T/F), Shot Type, Goal Differential"),
                                          br(),
                                          br(),
                                          p("From these metrics, I obtained an xG model. In the app, this model is used in two ways: "),
                                          br(),
                                          p("1. Game Maps"),
                                          p("In the Game Maps tab, you can create a shot map for a selected game. There are options to select the team, season, game date, and strength to study,
                                            though currently only 5v5 play is modeled. From these parameters, a plot is generated showing the xG value of each shot, as well as information about
                                            the parameters used to calculate that value. Additionally, game level data on xG and game result is displayed."),
                                          br(),
                                          p("2. Shot Simulator"),
                                          p("In the Shot Simulator tab, you can determine the xG value of an arbitrary shot. Using inputs such as location, game state, and prior events, an xG
                                            value is calculated and plotted along with the shot location. This allows for visualization of how the model handles different parameters.")
                                          
                                      )),
                             tabPanel("Game Maps", 
                                     h4("Instructions: "),
                                     p("This tool calculates the xG values for all of the shot attempts (including blocks, misses, shots on goal, and goals), taken by a team in a given game
                                       You can select the team, season, date, and strength (5v5 or 5v4) to examine. Available dates automatically update when the season is selected. Once the 
                                       plot is generated, you can mouse over each of the points for more information about its parameters and xG value. Zoom in on specific points by 
                                       clicking the magnifying glass and then double clicking the plot."),
                                    tags$head(
                                         tags$style(HTML('#prompt{background-color:orange}'))
                                     ),
                                     actionButton("prompt", "Need Ideas?"),
                                     br(),
                                    br(),
                                      sidebarPanel(width = 2,
                                                   tags$head(tags$style("
                                    .jhr{
                                 display: inline;
                                vertical-align: middle;
                                 padding-left: 10px;
                                }")),
                                                   pickerInput(inputId = "team",
                                                               label = "Team",
                                                               choices = teams$team_names,
                                                               choicesOpt = list(content = teams$team_imgs)),
                                                   selectInput("season", "Season", seasons$year, selected="2020-2021"),
                                                   dateInput("date", label = "Game Date", format = "mm-dd-yyyy",
                                                             min = "2021-01-13", max = Sys.Date(), value = "2021-01-13"),
                                                   selectInput("game_state", "Game State", states),
                                                   tags$head(
                                                       tags$style(HTML('#submit{background-color:orange}'))
                                                   ),
                                                   actionButton("submit", "Render Shot Map")
                                                   #maybe display schedule
                                      ),
                                      
                                      mainPanel(
                                          column(10,
                                                 conditionalPanel(condition = "input.submit == 0",
                                                                  plotOutput('blank_rink')  %>% withSpinner(color="#3e3f3a")),
                                                 conditionalPanel(condition = "input.submit > 0",
                                                                  {
                                                                      girafeOutput('rink') %>% withSpinner(color="#3e3f3a")
                                                                  })
                                          ),
                                          column(2, style="background-color:#f8f5f0",
                                                 conditionalPanel(condition = "input.submit > 0", 
                                                                  tableOutput('summary'))
                                          )
                                      )),
                             tabPanel("Shot Simulator",
                                      h4("Instructions: "),
                                      p("This tool calculates the xG value of an arbitrary shot. Alter the parameters in the input bar, and the corresponding xG value will be calulated.
                                        X coordinates range from -100 to 100, with the goal lines being at -89 and 89. Y coordinates range from -43 to 43. The 'Prior Event Shot by Team'
                                        box sets whether the previous event in the game was a shot by the same team taking the current shot."),
                                      br(),
                                      sidebarPanel(width = 2,
                                                   selectInput("net", "Target Net", c("Left", "Right")),
                                                   splitLayout(
                                                       numericInput("xloc", "X Loc", value = 0, min = -100, max = 100,step = 0.1),
                                                       numericInput("yloc", "Y Loc", value = 0, min = -43, max = 43, step = 0.1)
                                                   ),
                                                   splitLayout(
                                                       numericInput("gF", "Goals For", value = 0, min = 0, max = 10, step = 1),
                                                       numericInput("gA", "Goals Against", value = 0, min = 0, max = 10, step = 1)
                                                   ),
                                                   selectInput("shot_type", "Shot Type", shot_types),
                                                   splitLayout(
                                                       numericInput("xL", "Last Event X", value = 0, min = -100, max = 100,step = 0.1),
                                                       numericInput("yL", "Last Event Y", value = 0, min = -100, max = 100,step = 0.1)
                                                   ),
                                                   numericInput("sec", "Seconds Since Last Event", value = 10, min = 0, max = 100,step = 1),
                                                   selectInput("ps", "Prior Event Shot by Team", c("True", "False")),
                                                   tags$head(
                                                       tags$style(HTML('#submit2{background-color:orange}'))
                                                   ),
                                                   actionButton("submit2", "Render Shot Map")
                                      ),
                                      mainPanel(
                                          column(10,
                                                 conditionalPanel(condition = "input.submit2 == 0",
                                                                  plotOutput('blank_rink2') %>% withSpinner(color="#3e3f3a")) ,
                                                 conditionalPanel(condition = "input.submit2 > 0",
                                                                  {
                                                                      girafeOutput('simulation_rink') %>% withSpinner(color="#3e3f3a")
                                                                  }))
                                      ))
                  ),
)
)
