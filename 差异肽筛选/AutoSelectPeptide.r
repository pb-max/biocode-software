library(configr)

# 读取参数
config_file <- trimws(Sys.getenv("Auto_Select_Peptide_CONFIG_FILE", unset = ""))
if(config_file == "") {
  stop("please set the config file in the environment variable Auto_Select_Peptide_CONFIG_FILE")
}
config <- read.config(config_file)
project_folder <- as.character(config$main$project_folder)
fc_cutoff <- as.numeric(config$main$fc_cutoff)
pos_rate_diff_cutoff <- as.numeric(config$main$pos_rate_diff_cutoff)
regulation <- as.character(config$main$regulation)
max_overlap_gene <- as.numeric(config$main$max_overlap_gene)
max_total_gene <- as.numeric(config$main$max_total_gene)
# 数据路径和文件名
path <- paste0(project_folder, "/交付/comparison_analysis/Grade")
data_path_list <- list.files(path, pattern = ".csv$", full.names = TRUE)
data_filename <- basename(data_path_list)
data_filename <- gsub(".csv$", "", data_filename)
# 逐个处理每个文件
for(m in 1:length(data_path_list)){
    data <- read.csv(data_path_list[m], check.names = FALSE)
    # 粗筛Up的肽段
    if(regulation == "Up"){
        filter_data <- data[data$fc_cal >= fc_cutoff | (data$regulation == "Up" & data$Grade != "GradeIII") | (data$Grade == "GradeIII" & as.numeric(gsub("%", "",data$case_ctl_diff))/100 >= pos_rate_diff_cutoff),]
        data_up <- data[data$regulation == "Up",]
        ordered_by_p <- unique(data_up$GeneName)
        ordered_by_fc <- unique(data$GeneName[order(data$fc_cal, decreasing = TRUE)])
    # 粗筛Down的肽段
    }else if(regulation == "Down"){
        filter_data <- data[data$fc_cal <= 1/fc_cutoff | (data$regulation == "Down" & data$Grade != "GradeIII") | (data$Grade == "GradeIII" & as.numeric(gsub("%", "",data$case_ctl_diff))/100 <= -pos_rate_diff_cutoff),]
        data_down <- data[data$regulation == "Down",]
        ordered_by_p <- unique(data_down$GeneName)
        ordered_by_fc <- unique(data$GeneName[order(data$fc_cal, decreasing = FALSE)])
    # 粗筛Up和Down的肽段
    }else{
        filter_data <- data[data$fc_cal >= fc_cutoff | data$fc_cal <= 1/fc_cutoff | data$Grade != "GradeIII" | (data$Grade == "GradeIII" & abs(as.numeric(gsub("%", "",data$case_ctl_diff))/100) >= pos_rate_diff_cutoff),]
        ordered_by_p <- unique(data$GeneName)
        fc_cal_max <- sapply(data$fc_cal, function(x) max(x,1/x))[1:10]
        ordered_by_fc <- unique(data$GeneName[order(fc_cal_max, decreasing = TRUE)])
    }
    # 比较前3个和后3个氨基酸，挑选出有重叠的肽段的基因
    uni_gene <- unique(filter_data$GeneName)
    select_gene <- c()
    for(i in 1:length(uni_gene)){
        gene <- uni_gene[i]
        gene_data <- data[data$GeneName == gene,]
        if(nrow(gene_data) == 1){
            next
        }else{
            pep_list <- gene_data$Peptide
            is_coverage <- FALSE
            for(j in 1:length(pep_list)){
                pep <- pep_list[j]
                for(k in j+1:length(pep_list)){
                    if(grepl(substr(pep, 1, 3), pep_list[k]) | grepl(substr(pep, nchar(pep)-2, nchar(pep)), pep_list[k])){
                        is_coverage <- TRUE
                        break
                    }
                }
                if(is_coverage){
                    break
                }
            }
        }
        if(is_coverage){
            select_gene <- c(select_gene, gene)
        }
        if(length(select_gene) >= max_overlap_gene){
            break
        }
    }
    # 从剩余基因中挑选秩和检验差异最大的5个
    ready_select_gene_by_p <- !(ordered_by_p %in% select_gene)
    ready_select_gene_num_by_p <- min(floor(((max_total_gene - max_overlap_gene)/2)), sum(ready_select_gene_by_p))
    ready_select_gene_by_fc <- !(ordered_by_fc %in% select_gene)
    ready_select_gene_num_by_fc <- min(max_total_gene - max_overlap_gene - ready_select_gene_num_by_p, sum(ready_select_gene_by_fc))
    select_gene <- c(select_gene, ordered_by_p[!ordered_by_p %in% select_gene][1:ready_select_gene_num_by_p])
    select_gene <- c(select_gene, ordered_by_fc[!ordered_by_fc %in% select_gene][1:ready_select_gene_num_by_fc])
    for(i in 1:length(select_gene)){
        if(i == 1){
            select_data <- data[data$GeneName == select_gene[i],]
        }else{
            select_data <- rbind(select_data, data[data$GeneName == select_gene[i],])
        }
    }
    write.csv(select_data, paste0(path, "/", data_filename[m], "_select.csv"), row.names = FALSE)
}
