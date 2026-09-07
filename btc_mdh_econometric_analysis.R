# 1. 加载所有必需的扩展包
if(!require(readr)) install.packages("readr")
if(!require(ggplot2)) install.packages("ggplot2")
if(!require(gridExtra)) install.packages("gridExtra")
if(!require(tseries)) install.packages("tseries")
if(!require(lmtest)) install.packages("lmtest")
if(!require(sandwich)) install.packages("sandwich")

library(readr)
library(ggplot2)
library(gridExtra)
library(tseries)
library(lmtest)
library(sandwich)

# 2. 读取并清洗全量数据 (2017-Present)
file_path <- "D:/新建文件夹/crypto 作品集/Bitcoin Historical Data (1).csv"
df <- read_csv(file_path, show_col_types = FALSE)

df_clean <- df
colnames(df_clean)[1] <- "Date"
df_clean$Date <- as.Date(df_clean$Date)

# 数值清洗函数
clean_num <- function(x) {
  as.numeric(gsub("%", "", gsub(",", "", as.character(x))))
}

df_clean$`Price`             <- clean_num(df_clean$`Price`)
df_clean$`Daily Return`      <- clean_num(df_clean$`Daily Return`)
df_clean$`30-Day Volatility` <- clean_num(df_clean$`30-Day Volatility`)
df_clean$`Volume`            <- clean_num(df_clean$`Volume`)

# 确保百分比转换为小数
if(max(df_clean$`Daily Return`, na.rm=TRUE) > 1) {
  df_clean$`Daily Return` <- df_clean$`Daily Return` / 100
}
if(max(df_clean$`30-Day Volatility`, na.rm=TRUE) > 1) {
  df_clean$`30-Day Volatility` <- df_clean$`30-Day Volatility` / 100
}

df_clean$`Log Volume` <- log(df_clean$`Volume`)

# 保留 2017 年开始的所有有效数据
df_full <- subset(df_clean, !is.na(Date) & !is.na(`Daily Return`))

# 3. 打印 2017–2026 全量描述性统计结果
cat("\n================ 2017-2026 比特币全量描述性统计结果 ================\n")
cat("1. 样本总天数 (N):                   ", nrow(df_full), "\n")
cat("2. 每日平均涨跌 (Mean Daily Return): ", round(mean(df_full$`Daily Return`, na.rm=TRUE) * 100, 4), "%\n")
cat("3. 最大单日涨幅 (Max Return):        ", round(max(df_full$`Daily Return`, na.rm=TRUE) * 100, 2), "%\n")
cat("4. 最大单日跌幅 (Min Return):        ", round(min(df_full$`Daily Return`, na.rm=TRUE) * 100, 2), "%\n")
cat("5. 平均 30 日波动率 (Mean Vol):      ", round(mean(df_full$`30-Day Volatility`, na.rm=TRUE) * 100, 2), "%\n")
cat("6. 每日交易量均值 (Mean Volume):     ", format(round(mean(df_full$`Volume`, na.rm=TRUE), 0), big.mark=","), "\n")

peak_row <- df_full[which.max(df_full$`30-Day Volatility`), ]
cat("7. 历史波动率最高时期:               ", format(peak_row$Date, "%Y-%m-%d"), 
    "(峰值:", round(peak_row$`30-Day Volatility` * 100, 2), "%)\n")
cat("====================================================================\n")

# 4. 生成 2017-2026 高清 4 宫格图表并保存本地
p1 <- ggplot(df_full, aes(x = Date, y = Price)) + 
  geom_line(color = "#1f77b4", size = 0.7) + theme_minimal() + 
  labs(title = "① BTC Price over Time (2017-2026)", x = "Date", y = "Price (USD)")

p2 <- ggplot(df_full, aes(x = Date, y = `Daily Return`)) + 
  geom_line(color = "#2ca02c", size = 0.4, alpha = 0.8) + theme_minimal() + 
  labs(title = "② Daily Return over Time", x = "Date", y = "Daily Return")

p3 <- ggplot(df_full, aes(x = Date, y = `30-Day Volatility`)) + 
  geom_line(color = "#d62728", size = 0.7) + theme_minimal() + 
  labs(title = "③ 30-Day Volatility over Time", x = "Date", y = "30-Day Volatility")

p4 <- ggplot(df_full, aes(x = `Log Volume`, y = `30-Day Volatility`)) + 
  geom_point(alpha = 0.4, color = "#4b0082", size = 1.1) + 
  geom_smooth(method = "lm", se = FALSE, color = "black", size = 1) + theme_minimal() + 
  labs(title = "④ Trading Volume (Log) vs Volatility", x = "Log Volume", y = "30-Day Volatility")

final_plot <- grid.arrange(p1, p2, p3, p4, ncol = 2)

# 保存高清大图
ggsave("D:/新建文件夹/crypto 作品集/btc_diagnostic_charts_2017_2026.png", 
       plot = final_plot, width = 12, height = 8, dpi = 300)

# 5. 回归模型与诊断
model_ols_full <- lm(`30-Day Volatility` ~ `Log Volume`, data = df_full)

cat("\n================ 2017-2026 OLS Regression & Robustness =================\n")
print(summary(model_ols_full))

# Newey-West HAC 修正
robust_cov <- NeweyWest(model_ols_full, lag = 7, prewhite = FALSE)
robust_results <- coeftest(model_ols_full, vcov = robust_cov)

cat("\n--- Newey-West HAC Robust Results ---\n")
print(robust_results)