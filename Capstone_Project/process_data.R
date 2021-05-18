#
# Functions to process NHL play by play data for xG calculations and plotting
# Updated 5/18/21
# Megan Concannon
#

#
# Calculate distance of an event from target net
#
calculate_distance <- function(frame_row) {
  event_dist = -1
  xC = as.numeric(frame_row[18])
  yC = as.numeric(frame_row[19])
  #block zones are recorded based on blocking team, not shooting team, so need to flip
  if(frame_row[8] == "Off" || (frame_row[8] == 'Def' && frame_row[3] == 'BLOCK')) {
    event_dist = sqrt((abs(xC) - 89)^2+(yC)^2)
  } else { #shot from behind center line
    event_dist = sqrt((abs(xC) + 89)^2+(yC)^2)
  }
  event_dist = round(event_dist, 3)
  return(event_dist)
}

#
# Calculate angle of an event from target net
#
calculate_angle <- function(frame_row) {
  event_angle = 0
  xC = as.numeric(frame_row[18])
  yC = as.numeric(frame_row[19])
  if(frame_row[8] == "Off" || (frame_row[8] == 'Def' && frame_row[3] == 'BLOCK')) {
    event_angle = abs(atan(yC / (89 - abs(xC))) * (180 / pi))
  } else {
    event_angle = abs(atan(yC / (abs(xC + 89))) * (180 / pi))
  }
  event_angle = round(event_angle, 3)
  return(event_angle)
}


#
# Complete data processing for shot data
#
process_data <- function(input_data, state) {
  
  #Remove unnecessary rows/columns
  filtered_data = input_data
  c_drop <- c("X1", "p1_ID", "p2_ID", "p3_name", "p3_ID", "awayPlayer1", "awayPlayer1_id", 
              "awayPlayer2", "awayPlayer2_id", "awayPlayer3", "awayPlayer3_id", "awayPlayer4", "awayPlayer4_id", 
              "awayPlayer5", "awayPlayer5_id", "awayPlayer6", "awayPlayer6_id", "homePlayer1", "homePlayer1_id", 
              "homePlayer2", "homePlayer2_id", "homePlayer3", "homePlayer3_id", "homePlayer4", "homePlayer4_id", 
              "homePlayer5", "homePlayer5_id", "homePlayer6", "homePlayer6_id", "Away_Goalie", "Away_Goalie_Id", 
              "Home_Goalie", "Home_Goalie_Id", "Home_Coach", "Away_Coach", "Away_Players", "Home_Players", "Game_Id")
  
  event_drop <- c("PSTR", "PGSTR", "ON", "OFF", "STOP", "PENL", "PEND", "GEND")
  strength_keep <- c(state)
  
  filtered_data = filtered_data[,!(names(filtered_data) %in% c_drop)]
  filtered_data= filtered_data[!filtered_data$Event %in% event_drop, ]
  filtered_data = filtered_data[filtered_data$Strength %in% strength_keep, ]
  
  #Remove any rows with incomplete data
  filtered_data = filtered_data[!is.na(filtered_data$xC), ]
  filtered_data = filtered_data[!is.na(filtered_data$yC), ]
  filtered_data = filtered_data[!is.na(filtered_data$Ev_Zone), ]

  #Calculate distance/angle for each event and covert shot type to a factor
  filtered_data$distance =  apply(filtered_data, 1, function(x) calculate_distance(x))
  filtered_data$angle = apply(filtered_data, 1, function(x) calculate_angle(x))
  filtered_data$shot_type = as.factor(filtered_data$Type)
  
  #Add columns for additional metrics involved in xG calculation
  num_rows = nrow(filtered_data)
  metrics = data.frame(
    xC_last = rep(NA, num_rows),
    yC_last = rep(NA, num_rows),
    distance_from_last = rep(NA, num_rows),
    seconds_since_last = rep(NA, num_rows),
    prior_team_shot = rep(NA, num_rows),
    prior_face_win = rep(NA, num_rows),
    is_home = rep(NA, num_rows),
    goal = rep(NA, num_rows),
    goal_dif = rep(NA, num_rows),
    game_time = rep(NA, num_rows),
    graph_xC = rep(NA, num_rows),
    graph_yC = rep(NA, num_rows))
  
  
  for(j in 2:nrow(filtered_data)) {
    #Only looking at shots, blocks, goals, and misses
    if(filtered_data[j,]$Event != 'FAC' && filtered_data[j,]$Event != 'HIT' && filtered_data[j,]$Event != 'GIVE' && filtered_data[j,]$Event != 'TAKE') {
      if(filtered_data[j,]$Period == filtered_data[j-1,]$Period) { #can only compare data from same  period
        metrics$xC_last[j] = filtered_data$xC[j-1]
        metrics$yC_last[j] = filtered_data$yC[j-1]
        metrics$distance_from_last[j] = sqrt((as.numeric(filtered_data[j,]$xC) - as.numeric(metrics$xC_last[j]))^2 + (as.numeric(filtered_data[j,]$yC) - as.numeric(metrics$yC_last[j]))^2)
        metrics$seconds_since_last[j] = as.numeric(filtered_data[j,]$Seconds_Elapsed) - as.numeric(filtered_data[j-1,]$Seconds_Elapsed)
        metrics$prior_team_shot[j] = (filtered_data[j-1, ]$Event == 'SHOT') && (filtered_data[j-1, ]$Ev_Team == filtered_data[j, ]$Ev_Team)
        metrics$prior_face_win[j] = ((filtered_data[j-1, ]$Event == 'FAC') && (filtered_data[j-1, ]$Ev_Team == filtered_data[j, ]$Ev_Team))
      }
      
      metrics$is_home[j] = (filtered_data[j,]$Ev_Team == filtered_data[j,]$Home_Team)
      metrics$goal[j] = as.numeric((filtered_data[j,]$Event == 'GOAL'))
      metrics$goal_dif[j] = filtered_data[j, ]$Home_Score - filtered_data[j,]$Away_Score
      metrics$game_time[j] = (filtered_data[j, ]$Period - 1)*20*60 + filtered_data[j,]$Seconds_Elapsed
      
      #To prepare for plotting: flip x coordinates for even numbered periods for consistency in which goal is being shot at
      if(as.numeric(filtered_data[j,]$Period) %% 2 == 0) {
        metrics$graph_xC[j] = -filtered_data[j,]$xC
      } else {
        metrics$graph_xC[j] = filtered_data[j,]$xC
      }
      metrics$graph_yC[j] = filtered_data[j,]$yC
    }
    if(is.na(filtered_data[j,]$Type)) {
      filtered_data[j,]$Type = filtered_data[j,]$Event
    }
    
  }
  
  filtered_data = cbind(filtered_data, metrics)
  #remove non-shot rows
  r_drop = c("HIT", "FAC", "GIVE", "TAKE")
  filtered_data = filtered_data[!filtered_data$Event %in% r_drop, ]
  
  #predict xG based on calculated metrics
  load("xG_even_strength_model.rda")
  prediction = predict(xG_even_strength, filtered_data, type="response")
  prediction = round(prediction, 3)
  filtered_data = cbind(filtered_data, prediction)
  filtered_data = filtered_data[!is.na(filtered_data$prediction), ]
  
  #create summary text to display with shot
  summary_text = rep(NA, nrow(filtered_data))
  for(i in 1:nrow(filtered_data)) {
    summary_text[i] = paste0("xG: ", filtered_data[i,]$prediction, "\n",
                  "X: ", filtered_data[i, ]$graph_xC, ",      Y: ", filtered_data[i, ]$graph_yC, "\n",
                  "Distance: ", filtered_data[i, ]$distance, "\n",
                  "Angle: ", filtered_data[i, ]$angle, "\n",
                  "Type: ", filtered_data[i,]$shot_type, "\n",
                  "Result: ", filtered_data[i,]$Event, "\n",
                  "Time (Period): ", filtered_data[i,]$Time_Elapsed, " (", filtered_data[i,]$Period, ")\n",
                  "Score: ", filtered_data[i,]$Home_Score, " (", filtered_data[i,]$Home_Team, ") : ", filtered_data[i,]$Away_Score, " (", filtered_data[i,]$Away_Team, ")")
  }
  filtered_data = cbind(filtered_data, summary_text)
  
  return(filtered_data)
}

#
# Create summary for game-level stats
#
summarize_data <- function(team1, team2) {
  summary = data.frame("Metric" = c("Opponent", "Home Team", "Goals For", "Goals Against", "xG For", "xG Against", 
                                    "Shots For", "Average xG/Shot"), "Result" = rep(NA,8))
  summary$Result[1] = team2$Ev_Team[1]
  summary$Result[2] = team1$Home_Team[1]
  if(team1$Ev_Team[1] == team1$Home_Team[1]) {
    #OT goals are not reflected in end-of-game scores, so add if a team's last event was a goal
    summary$Result[3] = team1$Home_Score[nrow(team1)] + as.numeric(team1$Event[nrow(team1)] == "GOAL")
    summary$Result[4] = team2$Away_Score[nrow(team2)] + as.numeric(team2$Event[nrow(team2)] == "GOAL")
  } else {
    summary$Result[3] = team1$Away_Score[nrow(team1)] + as.numeric(team1$Event[nrow(team1)] == "GOAL")
    summary$Result[4] = team2$Home_Score[nrow(team2)] + as.numeric(team2$Event[nrow(team2)] == "GOAL")
  }
  summary$Result[5] = sum(team1$prediction) 
  summary$Result[6] = sum(team2$prediction) 
  summary$Result[7] = sum(nrow(team1)) 
  summary$Result[8] = round(mean(team1$prediction), 3)
  return(summary)
}

#
# Calculate distance of an event from target net based on individual location and target net
#
dist <- function(xloc, yloc, net) {
  dist = -1
  if(net == "Left" && xloc > 0 || net == "Right" && xloc < 0) {
    dist = sqrt((abs(xloc) + 89)^2+(xloc)^2)
  } else { 
    dist = sqrt((abs(xloc) - 89)^2+(yloc)^2)
  }
  dist = round(dist, 3)
  return(dist)
}

#
# Calculate angle of an event from target net based on individual location and target net
#
angle <- function(xloc, yloc, net) {
  angle = 0
  if(net == "Left" && xloc > 0 || net == "Right" && xloc < 0) {
    angle = abs(atan(yloc / (abs(xloc + 89))) * (180 / pi))
  } else {
    angle = abs(atan(yloc / (89 - abs(xloc))) * (180 / pi))
  }
  angle = round(angle, 3)
  return(angle)
}
