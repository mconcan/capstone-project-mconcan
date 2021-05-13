#
# Comment Here
#

library(shiny)
library(shinythemes)


shinyUI(fluidPage(theme = shinytheme("superhero"),

    # Application title
    headerPanel("NHL xG Predictor"),
    
    navbarPage("NHL xG Predictor",
               tabPanel("Component 1"),
               tabPanel("Component 2"),
               tabPanel("Component 3")
    ),

    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            sliderInput("bins",
                        "Number of bins:",
                        min = 1,
                        max = 50,
                        value = 30)
        ),

        # Show a plot of the generated distribution
        mainPanel(
            plotOutput("distPlot")
        )
    )
))
