library(shiny)
library(dplyr)
library(ggplot2)
library(plotly)
library(scales)
library(ggthemes)

states <- read.csv("https://raw.githubusercontent.com/crarnouts/Data_608/master/states.csv", colClasses=c("state_fips"="character"))
df <- read.csv('https://raw.githubusercontent.com/charleyferrari/CUNY_DATA_608/master/module3/data/cleaned-cdc-mortality-1999-2010-2.csv') %>% merge(states)
state_options <- sort(df$state_name)


# 2010 Ranking options
options <- filter(df, Year == 2010) %>%
    mutate(ICD.Chapter = as.character(ICD.Chapter))
options <- unique(sort(options$ICD.Chapter))

ui <- navbarPage("Cause of Death Dashboard",
                 tabPanel("Map",
                          selectInput("cause_of_death_3", "Cause of Death:", options, width = "100%"),
                          mainPanel(plotlyOutput("map"), width = 12)
                 ),
                 
                 tabPanel("States by Rank in 2010",
                          selectInput("cause_of_death", "Cause of Death:", options, width = "100%"),
                          mainPanel(plotlyOutput("rank_plot", height = "700px"), width = 12)
                 ),
                 
                 tabPanel("Improvement vs National Average",
                          selectInput("cause_of_death_2", "Cause of Death:", options, width = "100%"),
                          selectInput("highlight", "Highlight:", state_options, width = "100%"),
                          mainPanel(plotlyOutput("improvement_plot"), width = 12)
                 )
)

server <- function(input, output) {
    
    output$rank_plot <- renderPlotly({
        # Wrangle the data
        plot_df <- df %>%
            filter(Year == 2010 & ICD.Chapter == input$cause_of_death) %>%
            arrange(Crude.Rate) %>%
            mutate(Rank = row_number())
        
        text_y <- max(plot_df$Crude.Rate) / - 100
        max_rank <- max(plot_df$Rank) - 2
        
        # Create the ggplot
        p <- ggplot(plot_df, aes(x = Rank, y = Crude.Rate, text = paste("<b>", state_name, "</b><br>Rank:", Rank, "out of", max(Rank),"<br>Rate:", round(Crude.Rate,1)))) +
            geom_bar(stat = "identity")+
            scale_fill_gradient2(low = "blue", 
                                 high = "red", 
                                 midpoint = median(plot_df$Crude.Rate)) + 
            labs(y = "Deaths per 100,000", x = "") +
            geom_text(data = plot_df, aes(x = Rank, y = text_y, label = State), color = "black", size = 3) + 
            coord_flip()
        
        # Load it into plotly
        ggplotly(p, tooltip = c("text")) %>% 
            config(displayModeBar = F) %>%
            layout(margin = list(t = 0))
    })
    
    output$improvement_plot <- renderPlotly({
        plot_df <- df %>%
            merge(states) %>%
            filter(ICD.Chapter == input$cause_of_death_2)
        
        n_years <- plot_df %>%
            select(Year) %>%
            unique() %>%
            nrow()
        
        us <- plot_df %>%
            group_by(ICD.Chapter, Year) %>%
            summarise(Deaths = sum(Deaths), 
                      Population = sum(Population)) %>%
            mutate(State = "US",
                   state_fips = "00",
                   state_name = "United States",
                   Crude.Rate = round(Deaths / Population * 100000, 1)) %>%
            select(State, state_fips, state_name, ICD.Chapter, Year, Deaths, Population, Crude.Rate)
        
        plot_df <- plot_df %>%
            bind_rows(us)
        
        plot_df <- plot_df %>%
            filter(Year == 1999) %>%
            rename(base_rate = Crude.Rate) %>%
            select(State, base_rate) %>%
            merge(plot_df) %>%
            mutate(Index = round(Crude.Rate / base_rate * 100, 0))
        
        plot_df <- plot_df %>%
            filter(State == "US") %>%
            rename(US_Index = Index) %>%
            select(US_Index, Year) %>%
            merge(plot_df) %>%
            mutate(interpretation = ifelse(Index > US_Index, "Worse than National Average", "Better or equal to National Average"))
        
        plot_df <- plot_df %>%
            mutate(color = ifelse(State == "US", "2", "1")) %>%
            mutate(color = ifelse(state_name == input$highlight, "3", color))
        
        
        plot_df$color <- as.factor(plot_df$color)
        
        p <- ggplot(plot_df) +
            geom_line(aes(x = Year, y = Index, group = state_name, text = paste0("<b>", state_name, "</b><br>", interpretation, "<br>Year: ", Year, "<br>Mortality Rate: ", Crude.Rate, "<br>Index: ", Index, " (US: ", US_Index,")"), color = color)) +
            scale_x_continuous(breaks = 1999:2010) +
            theme_minimal() +
            scale_color_manual(values=c("#bbbbbb", "#e41a1c", "#377eb8")) +
            theme(panel.grid.major.x = element_blank(),
                  legend.position = "none") +
            labs(x = "", y = "Mortality Rate")
        
        p
    })
    
    output$map <- renderPlotly({
        library(usmap)
        library(ggplot2)
        
        statepop <- statepop
        
        statepop$State <- statepop$abbr
        
        test <- merge(statepop,df) %>% filter(Year == 2010)
        
        test2 <- test  %>%
            filter(ICD.Chapter == input$cause_of_death_3)
        
        test2$hover <- with(test2, paste('Deaths per 100,000','<br>',full, '<br>', " Total Deaths", Deaths))
        # give state boundaries a white border
        l <- list(color = toRGB("white"), width = 2)
        # specify some map projection/options
        g <- list(
            scope = 'usa',
            projection = list(type = 'albers usa'),
            showlakes = TRUE,
            lakecolor = toRGB('white')
        )
        
        p <- plot_geo(test2, locationmode = 'USA-states') %>%
            add_trace(
                z = ~Crude.Rate, text = ~hover, locations = ~State,
                color = ~Crude.Rate, colors = 'Reds'
            ) %>%
            colorbar(title = "Deaths per 100,000") %>%
            layout(
                title = '2010 Death Rate Per 100,000 by Disease and State <br>(Hover for breakdown)',
                geo = g
            )
        
        p
        
        
        
    })
}

# Run the application 
shinyApp(ui = ui, server = server)