library(tidyverse)
library(ggmap)
library(plotly)
library(shiny)
library(mapproj)
library(maps)



# 데이터 불러오기
df <- read.csv("data.csv", header = TRUE)

# 구글 맵
# register_google(key = "AIzaSyC3KY9GU0zR2ALsbNgnTb7jMUm9vwpXxRI")
# map <- get_map(location = "south korea", zoom = 7, maptype = "roadmap", color = "bw")

# CRS 좌표계 변경
# map <- readOGR("ctp_rvn.shp")
# ls_crs <- list(wgs84 = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs")
# map <- spTransform(map, CRSobj = CRS(ls_crs$wgs84))
# df_map <- fortify(map)

df_map <- map_data("world") |> filter(region == "South Korea")


# 지역 구분 항목
reg_hangmok <- c("서울", "광역시", "중소도시", "읍면지역")
# 과목 구분 항목
subject_hangmok <- c("시점", "항목", "국어", "영어", "수학", "사회.과학", "논술", "음악", "미술", "체육")

# 지도에 그릴 데이터 정리
make_map <- subset(df, 항목 %in% reg_hangmok)

# barplot 그릴 데이터 정리
make_bar <- subset(df, 항목 %in% reg_hangmok)
make_bar$항목 <- factor(make_bar$항목)


ui <- fluidPage(
    fluidRow(
        column(
            12,
            h1("지역별 사교육비의 차이"),
            offset = 4
        )
    ),
    fluidRow(
        column(
            2,
            selectInput(
                "year", "연도",
                c(2007:2020)
            )
        ),
        column(5, plotlyOutput("mapPlotly")),
        column(5, plotlyOutput("barPlotly"))
    ),
    fluidRow(
        column(
            2,
            selectInput(
                "gwamok", "과목",
                subject_hangmok[c(-1, -2)]
            )
        ),
        column(5, plotOutput("circularPlot")),
        column(5, plotlyOutput("areaPlotly"))
    )
)


server <- function(input, output) {
    output$mapPlotly <- renderPlotly({
        p1 <- ggplot() +
            geom_polygon(
                data = df_map, aes(x = long, y = lat, group = group),
                fill = "grey", alpha = 0.6
            ) +
            geom_point(
                data = make_map[make_map$시점 == input$year, ],
                aes(x = long, y = lat, size = 사교육비, fill = 항목, alpha = 0.2)
            ) +
            scale_size_continuous(range = c(10, 50)) +
            theme_minimal() +
            theme(
                legend.position = "none",
                axis.title.x = element_blank(),
                axis.title.y = element_blank()
            ) +
            scale_fill_hue(c = 40) +
            coord_map()
        ggplotly(p1)
    })


    output$barPlotly <- renderPlotly({
        p2 <- ggplot(data = make_bar[make_bar$시점 == input$year, ], aes(x = reorder(항목, -사교육비), y = 사교육비, fill = 항목)) +
            geom_bar(stat = "identity") +
            scale_fill_hue(c = 40) +
            theme_minimal() +
            theme(
                legend.position = "none",
                axis.title.x = element_blank()
            )
        ggplotly(p2)
    })


    output$circularPlot <- renderPlot({
        # circular 데이터 정제
        make_circular <- df
        make_circular <- subset(make_circular, select = subject_hangmok)
        make_circular <- make_circular[make_circular$항목 %in% reg_hangmok, ]
        make_circular$항목 <- factor(make_circular$항목)
        data <- make_circular
        data <- subset(make_circular, select = c("항목", "시점", input$gwamok))

        # Set a number of 'empty bar' to add at the end of each group
        empty_bar <- 3
        to_add <- data.frame(matrix(NA, empty_bar * nlevels(data$항목), ncol(data)))
        colnames(to_add) <- colnames(data)
        to_add$항목 <- rep(levels(data$항목), each = empty_bar)
        data <- rbind(data, to_add)
        data <- data %>% arrange(항목)
        data$id <- seq(1, nrow(data))

        # Get the name and the y position of each label
        label_data <- data
        number_of_bar <- nrow(label_data)
        angle <- 90 - 360 * (label_data$id - 0.3) / number_of_bar
        label_data$hjust <- ifelse(angle < -90, 1, 0)
        label_data$angle <- ifelse(angle < -90, angle + 180, angle)

        # prepare a data frame for base lines
        base_data <- data %>%
            group_by(항목) %>%
            summarize(start = min(id), end = max(id) - empty_bar) %>%
            rowwise() %>%
            mutate(title = mean(c(start, end)))

        # prepare a data frame for grid (scales)
        grid_data <- base_data
        grid_data$end <- grid_data$end[c(nrow(grid_data), 1:nrow(grid_data) - 1)] + 1
        grid_data$start <- grid_data$start - 1
        grid_data <- grid_data[-1, ]

        # Make the plot
        p <- ggplot(data, aes(x = as.factor(id), y = get(names(data)[3]) * 6, fill = 항목)) +
            geom_bar(aes(x = as.factor(id), y = get(names(data)[3]) * 6, fill = 항목), stat = "identity", alpha = 0.5) +
            ylim(-70, 100) +
            theme_minimal() +
            theme(
                legend.position = "none",
                legend.key.size = unit(0.8, "cm"),
                legend.text = element_text(size = 12),
                axis.text = element_blank(),
                axis.title = element_blank(),
                panel.grid = element_blank(),
                plot.margin = unit(rep(-5, 15), "cm")
            ) +
            coord_polar() +
            geom_text(data = label_data, aes(x = id, y = get(names(data)[3]) + 10, label = 시점, hjust = hjust), color = "black", fontface = "bold", alpha = 0.6, size = 2.5, angle = label_data$angle, inherit.aes = FALSE) +
            geom_segment(data = base_data, aes(x = start, y = -5, xend = end, yend = -5), colour = "black", alpha = 0.8, size = 0.6, inherit.aes = FALSE)
        p
    })

    output$areaPlotly <- renderPlotly({
        make_circular <- df
        make_circular <- subset(make_circular, select = subject_hangmok)
        make_circular <- make_circular[make_circular$항목 %in% reg_hangmok, ]
        make_circular$항목 <- factor(make_circular$항목)
        data <- make_circular
        data <- subset(make_circular, select = c("항목", "시점", input$gwamok))
        # plot
        p3 <- ggplot(data, aes(x = 시점, y = get(names(data)[3]), fill = 항목)) +
            geom_area(alpha = 0.7) +
            scale_fill_hue(c = 40) +
            theme_minimal() +
            labs(y = names(data)[3])
        ggplotly(p3)
    })
}


shinyApp(ui, server)
